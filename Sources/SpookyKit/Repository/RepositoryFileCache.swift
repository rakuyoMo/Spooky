import Foundation
import Synchronization

// MARK: - RepositoryFileCache

/// 交给本机程序打开的文件副本，Quick Look、默认程序与外部工具只拿到本机路径。
///
/// 本机工作区文件直接使用原路径；服务器文件经 SFTP 取到本缓存，历史版本等内容写成缓存文件。
/// 缓存目录权限为 0700，副本保留原文件名，系统据此选择预览与打开方式。
public final class RepositoryFileCache: Sendable {
    /// 文件访问与 Git 使用相同的仓库和 SSH 会话。
    private let runner: GitRunner

    /// 首次写入时创建的缓存根目录。
    private let root = Mutex<URL?>(nil)

    /// 建立缓存，不立即访问磁盘或网络。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 工作区文件的本机路径：本机仓库返回原文件，服务器仓库下载到缓存后返回副本。
    ///
    /// - Parameter path: 仓库内的相对路径。
    public func workingTreeFile(_ path: String) async throws -> URL {
        guard runner.remote != nil else {
            return URL(fileURLWithPath: runner.location.path).appending(path: path)
        }

        let destination = try slot(named: path)

        do {
            try await RepositoryFiles(runner: runner).download(runner.location.path + "/" + path, to: destination)
        } catch {
            // 下载失败不留下空的副本目录
            try? FileManager.default.removeItem(at: destination.deletingLastPathComponent())
            throw error
        }

        return destination
    }

    /// 把内容写成缓存中的同名文件，如某个版本的原文。
    ///
    /// - Parameters:
    ///   - data: 文件内容。
    ///   - name: 仓库内的路径或文件名，只取最后一段作为副本名。
    public func store(_ data: Data, named name: String) throws -> URL {
        let destination = try slot(named: name)
        try data.write(to: destination)
        return destination
    }

    /// 删除本缓存创建的全部副本；之后仍可继续使用，目录按需重建。
    public func removeAll() {
        let directory = root.withLock { root in
            defer { root = nil }
            return root
        }

        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    /// 为一个副本分配独占的子目录，副本沿用原文件名，同名文件互不覆盖。
    private func slot(named name: String) throws -> URL {
        let directory = try rootDirectory().appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        // 只取最后一段，远端的目录结构与绝对路径不进入本机文件名；“.” 与 “..” 不能作为文件名
        let last = name.split(separator: "/").last.map(String.init) ?? ""
        let file = ["", ".", ".."].contains(last) ? "file" : last

        return directory.appending(path: file)
    }

    /// 缓存根目录，首次使用时以 0700 权限创建。
    private func rootDirectory() throws -> URL {
        try root.withLock { root in
            if let root {
                return root
            }

            let directory = FileManager.default.temporaryDirectory
                .appending(path: "spooky-files-" + UUID().uuidString)

            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )

            root = directory
            return directory
        }
    }
}
