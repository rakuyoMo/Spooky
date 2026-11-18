import Foundation
import SpookyKit

// MARK: - RepositoryFolderTrash

/// 删除书签时把仓库文件夹移进废纸篓：本机仓库进这台 Mac 的废纸篓，服务器仓库在服务器上进它的废纸篓，都不永久删除。
///
/// 实际移动的两步可以替换：测试换成记录调用的闭包，不往真实的废纸篓里放东西，也不碰真实的家目录。
@MainActor
struct RepositoryFolderTrash {
    /// 受保护的仓库没有移走时的原因。
    static var protectedReason: String {
        AppLocalization.text("bookmarks.trashFailed.protected")
    }

    /// 实际使用的入口：本机经 `FileManager.trashItem`，可以在 Finder 里放回；
    /// 服务器仓库照仓库管理的打开检查建立连接，再在服务器上移动。
    static var system: Self {
        Self(
            homeDirectory: NSHomeDirectory(),
            moveLocal: { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) },
            moveRemote: { location in
                let remote = try await RepositoryManagerController.openedRunner(for: location).remote
                return try await remote?.moveRepositoryToTrash(location.path) ?? .missing
            }
        )
    }

    /// 本机的家目录：它与它的上级目录不移走。
    let homeDirectory: String

    /// 把本机目录移进这台 Mac 的废纸篓。
    let moveLocal: @MainActor (URL) throws -> Void

    /// 在服务器上把仓库目录移进那台服务器的废纸篓；家目录、它的上级与卷的顶层由服务器上的核对挡下。
    let moveRemote: @MainActor (RepositoryLocation) async throws -> RepositoryTrashResult

    /// 本机目录是否是家目录、它的上级目录，或是卷、挂载点的顶层；符号链接先解析成实际位置再比较。
    ///
    /// - Parameters:
    ///   - url: 仓库目录。
    ///   - home: 家目录。
    static func isProtected(_ url: URL, home: String) -> Bool {
        let target = url.resolvingSymlinksInPath().path
        let home = URL(fileURLWithPath: home).resolvingSymlinksInPath().path

        if home == target || home.hasPrefix(target == "/" ? target : target + "/") {
            return true
        }

        return (try? url.resourceValues(forKeys: [.isVolumeKey]).isVolume) ?? false
    }

    /// 移走一个仓库的文件夹。
    ///
    /// - Parameter location: 书签指向的仓库。
    /// - Returns: 没有移走的原因；移走了，或目录已不存在而跳过时为 nil。
    func move(_ location: RepositoryLocation) async -> String? {
        guard location.host != nil else {
            return moveLocalFolder(URL(fileURLWithPath: location.path))
        }

        do {
            return try await moveRemote(location) == .protected ? Self.protectedReason : nil
        } catch {
            // 服务器上的目录已不存在、或已不是工作区时跳过，与仓库管理认出仓库不在原处的规则相同
            if RepositoryManagerController.isMissing(location, error: error) {
                return nil
            }

            return AppFailure(error: error, opening: false, location: location).title
        }
    }

    /// 移走本机目录：已不存在时跳过，受保护时不动；移动失败的原因取系统的说明。
    private func moveLocalFolder(_ url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        guard !Self.isProtected(url, home: homeDirectory) else {
            return Self.protectedReason
        }

        do {
            try moveLocal(url)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
