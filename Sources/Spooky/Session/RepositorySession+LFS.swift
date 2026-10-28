import Foundation
import SpookyKit

// MARK: - LFSTransfer

/// LFS 对象的三种传输：Repository › LFS 菜单与传输对话框共用。
enum LFSTransfer {
    /// 只下载当前检出需要的对象。
    case fetch

    /// 下载对象并把工作区里的指针换成内容。
    case pull

    /// 上传本地分支与标签用到的对象。
    case push

    /// 对话框与 Activity 的标题。
    var title: String {
        switch self {
        case .fetch: AppLocalization.text("lfs.fetch")
        case .pull: AppLocalization.text("lfs.pull")
        case .push: AppLocalization.text("lfs.push")
        }
    }
}

// MARK: - Availability

extension RepositorySession {
    /// 能否把这些文件交给 LFS 逐个跟踪：至少一个文件，且不含目录。
    func canTrackLFS(_ entries: [StatusEntry]) -> Bool {
        canWrite && !entries.isEmpty && !entries.contains { $0.path.hasSuffix("/") }
    }

    /// 按所选文件的扩展名跟踪时写入的规则，如 `*.psd`；目录与没有扩展名的文件不产生规则。
    func lfsTypePatterns(for entries: [StatusEntry]) -> [String] {
        var patterns: [String] = []

        for entry in entries where !entry.path.hasSuffix("/") {
            let suffix = WorkingCopyOperations.pathExtension(of: WorkingCopyFileList.fileName(of: entry.path))

            if !suffix.isEmpty, !patterns.contains("*." + suffix) {
                patterns.append("*." + suffix)
            }
        }

        return patterns
    }
}

// MARK: - Actions

extension RepositorySession {
    /// 在仓库本地启用 Git LFS：登记过滤器并装上钩子。
    func enableLFS() {
        performGit(
            { runner, _ in try await RepositoryLFS(runner: runner).install() },
            title: AppLocalization.text("lfs.enable")
        )
    }

    /// 按当前版本的 Git LFS 更新仓库里的钩子。
    func updateLFS() {
        performGit(
            { runner, _ in try await RepositoryLFS(runner: runner).update() },
            title: AppLocalization.text("lfs.update")
        )
    }

    /// 把路径模式交给 Git LFS 跟踪；`.gitattributes` 的改动留在工作区，与其它改动一起提交。
    ///
    /// - Returns: 是否已开始执行。
    @discardableResult
    func trackLFS(_ patterns: [String]) -> Bool {
        performGit(
            { runner, _ in try await RepositoryLFS(runner: runner).track(patterns) },
            title: AppLocalization.text("lfs.track"),
            undo: .reversible
        )
    }

    /// 只跟踪这几个文件，路径里的通配符按字面值写入。
    func trackLFS(_ entries: [StatusEntry]) {
        let paths = entries.map(\.path)

        performGit(
            { runner, _ in try await RepositoryLFS(runner: runner).track(files: paths) },
            title: AppLocalization.text("lfs.track"),
            undo: .reversible
        )
    }

    /// 确认后从 `.gitattributes` 去掉一条规则，已经存进 LFS 的文件保持原样。
    func untrackLFS(_ pattern: String) {
        onConfirm?(
            AppLocalization.text("lfs.remove.title"),
            AppLocalization.text("lfs.remove.message", pattern),
            { [weak self] in
                self?.performGit(
                    { runner, _ in try await RepositoryLFS(runner: runner).untrack([pattern]) },
                    title: AppLocalization.text("lfs.remove.title"),
                    undo: .reversible
                )
            },
            nil
        )
    }

    /// 与远端之间传输 LFS 对象，进度写进 Activity。
    ///
    /// - Returns: 是否已开始执行。
    @discardableResult
    func transferLFS(_ transfer: LFSTransfer, remote: String) -> Bool {
        performGit(
            { runner, output in
                let lfs = RepositoryLFS(runner: runner)

                switch transfer {
                case .fetch: try await lfs.fetch(from: remote, onOutput: output)
                case .pull: try await lfs.pull(from: remote, onOutput: output)
                case .push: try await lfs.push(to: remote, onOutput: output)
                }
            },
            title: transfer.title,
            activityKind: .remote
        )
    }
}
