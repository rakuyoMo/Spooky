import AppKit
import CryptoKit
import SpookyKit

// MARK: - RecentRepositoryDocuments

/// 把打开的仓库登记进系统的最近文稿，Dock 图标的右键菜单据此列出最近打开的仓库，App 没运行时也有。
///
/// 本机仓库登记仓库文件夹。服务器仓库没有本机路径，登记一个位置文件夹：带 `spookyrepo` 扩展名、遵从 `public.folder`，
/// Dock 里显示系统的文件夹图标；里面的位置文件（`spookylocation`）只记主机别名与远端路径，在访达里打开它同样交给 Spooky。
/// 两种类型都在 `Info.plist` 里导出，App 是它们的所有者。
@MainActor
struct RecentRepositoryDocuments {
    /// 位置文件夹的扩展名。
    static let folderExtension = "spookyrepo"

    /// 位置文件的扩展名。
    static let fileExtension = "spookylocation"

    /// App 用的登记：位置文件夹放在 `~/Library/Application Support/Spooky/Locations` 下，登记与清空交给系统的最近文稿。
    static let system = Self(
        directory: URL.applicationSupportDirectory.appending(path: "Spooky/Locations", directoryHint: .isDirectory),
        note: { NSDocumentController.shared.noteNewRecentDocumentURL($0) },
        clear: { NSDocumentController.shared.clearRecentDocuments(nil) }
    )

    /// 存放位置文件夹的目录：每个服务器仓库一个子目录，以带主机前缀的仓库身份的 SHA-256 命名。
    let directory: URL

    /// 把一个本机 URL 登记进最近文稿。
    let note: @MainActor (URL) -> Void

    /// 清空 App 在系统里的最近文稿。
    let clear: @MainActor () -> Void

    /// 读出位置文件夹或位置文件记的仓库位置。
    ///
    /// - Parameter url: 交给 App 的本机文件。
    /// - Returns: 记下的服务器仓库；不是这两种类型、读不了或内容不对时为 nil。
    static func location(at url: URL) -> RepositoryLocation? {
        let file: URL? =
            switch url.pathExtension.lowercased() {
            case fileExtension:
                url

            case folderExtension:
                try? FileManager.default
                    .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                    .first { $0.pathExtension.lowercased() == fileExtension }

            default:
                nil
            }

        guard
            let file,
            let data = try? Data(contentsOf: file),
            let saved = try? JSONDecoder().decode(SavedLocation.self, from: data)
        else {
            return nil
        }

        return .remote(host: saved.host, path: saved.path)
    }

    /// 登记打开的仓库；服务器仓库的位置文件夹写不出来时不登记。
    ///
    /// - Parameter location: 已确认的仓库位置。
    func record(_ location: RepositoryLocation) {
        switch location {
        case .local(let path):
            note(URL(fileURLWithPath: path, isDirectory: true))

        case .remote:
            guard let folder = try? writeFolder(for: location) else {
                return
            }

            note(folder)
        }
    }

    /// 写出服务器仓库的位置文件夹；同一个仓库沿用同一份，位置文件每次重写。
    ///
    /// 文件夹名取远端路径的最后一段，扩展名在登记前隐藏：Dock 记的是登记那一刻的显示名，写成仓库名。
    ///
    /// - Parameter location: 服务器仓库。
    /// - Returns: 位置文件夹。
    private func writeFolder(for location: RepositoryLocation) throws -> URL {
        let key = SHA256.hash(data: Data(location.displayPath.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        let name = URL(fileURLWithPath: location.path).lastPathComponent

        var folder = directory
            .appending(path: key, directoryHint: .isDirectory)
            .appending(path: name + "." + Self.folderExtension, directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // 只记主机别名与远端路径；整个文件一次换上
        let saved = SavedLocation(host: location.host ?? "", path: location.path)
        let file = folder.appending(path: name + "." + Self.fileExtension)

        try JSONEncoder().encode(saved).write(to: file, options: .atomic)

        var values = URLResourceValues()
        values.hasHiddenExtension = true
        try folder.setResourceValues(values)

        return folder
    }
}

// MARK: - SavedLocation

/// 位置文件的内容。
private struct SavedLocation: Codable {
    /// `~/.ssh/config` 里的主机别名。
    let host: String

    /// 远端工作区的路径。
    let path: String
}
