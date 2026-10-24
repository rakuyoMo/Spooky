import AppKit
import CryptoKit

// MARK: - AvatarStore

/// 按邮箱取作者头像：经 Gravatar 按邮箱的 SHA-256 读取，图片在内存里缓存。
///
/// 同一邮箱只读取一次；没有头像、读取失败或不是图片时记下，本次运行里一直用首字母占位。
@MainActor
final class AvatarStore {
    /// 所有窗口共用的头像缓存。
    static let shared = AvatarStore()

    /// 请求的像素尺寸，所有位置共用一份图片，足够 Retina 屏上最大的 56 pt 头像。
    nonisolated static let pixelSize = 128

    /// 读取头像数据；返回 nil 表示没有头像。测试注入不联网的实现。
    var fetch: @Sendable (URL) async throws -> Data? = { url in
        let (data, response) = try await URLSession.shared.data(from: url)
        return (response as? HTTPURLResponse)?.statusCode == 200 ? data : nil
    }

    /// 已取得的图片，键是规范化后的邮箱。
    private var images: [String: NSImage] = [:]

    /// 没有头像或读取失败的邮箱。
    private var missing = Set<String>()

    /// 正在读取的邮箱，同时出现的多行共用一次读取。
    private var loading: [String: Task<NSImage?, Never>] = [:]

    /// 邮箱对应的头像；没有邮箱或没有头像时为 nil。
    func image(for email: String?) async -> NSImage? {
        guard
            let key = email.map(Self.normalized),
            !key.isEmpty,
            !missing.contains(key),
            let url = Self.url(for: key)
        else { return nil }

        if let image = images[key] {
            return image
        }

        if let task = loading[key] {
            return await task.value
        }

        // 网络错误与没有头像一样回退到首字母
        let fetch = fetch
        let task = Task<NSImage?, Never> {
            try? await fetch(url).flatMap(NSImage.init(data:))
        }

        loading[key] = task

        let image = await task.value
        loading[key] = nil

        if let image {
            images[key] = image
        } else {
            missing.insert(key)
        }

        return image
    }
}

// MARK: - Private

extension AvatarStore {
    /// Gravatar 要求去掉首尾空白并转成小写后再取哈希。
    private nonisolated static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 头像地址；`d=404` 让没有头像的邮箱返回 404，而不是默认图片。
    private nonisolated static func url(for email: String) -> URL? {
        let hash = SHA256.hash(data: Data(email.utf8)).map { String(format: "%02x", $0) }.joined()
        return URL(string: "https://gravatar.com/avatar/\(hash)?s=\(pixelSize)&d=404")
    }
}
