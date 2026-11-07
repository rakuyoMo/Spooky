import Foundation
import SpookyKit

// MARK: - FileHistoryTarget

/// 历史目标在所选提交与第一父提交中的对象身份，内容能力不由 HEAD 推断。
struct FileHistoryTarget: Sendable {
    /// 所选提交中的目标，删除后为空。
    let current: TreeEntry?

    /// 第一父提交中的目标，根提交为空。
    let parent: TreeEntry?

    /// 任一侧为目录时，Diff 必须展示目录内全部变更。
    var needsDirectoryDiff: Bool { (current?.isDirectory ?? false) || (parent?.isDirectory ?? false) }

    /// 缺失文件保留缺失说明；目录对象不能读取为文件内容。
    var allowsContent: Bool { (current ?? parent)?.isDirectory != true }

    /// 解析两侧对象，不把查询失败当成对象缺失。
    static func load(
        path: String,
        originalPath: String? = nil,
        commit: HistoryCommit,
        runner: GitRunner
    ) async throws -> Self {
        let views = RepositoryFileViews(runner: runner)
        let current = try await views.storedEntry(for: path, in: commit.id)
        let parent: TreeEntry? =
            if let revision = commit.parents.first {
                try await views.storedEntry(for: originalPath ?? path, in: revision)
            } else {
                nil
            }

        return Self(current: current, parent: parent)
    }

    /// 完整变更集先保留重命名配对，再按目标目录的组件边界筛选。
    static func changes(path: String, commit: HistoryCommit, runner: GitRunner) async throws -> [CommitFileChange] {
        try await RepositoryHistory(runner: runner).changes(in: commit.id).filter { file in
            RepositoryFileViews.contains(file.path, in: path)
                || (file.originalPath.map { RepositoryFileViews.contains($0, in: path) } ?? false)
        }
    }

    /// HEAD 变化时重新解析类型与真实路径，筛选不改变目标身份。
    static func resolvePath(
        _ path: String,
        head: String,
        views: RepositoryFileViews,
        resolve: Bool
    ) async throws -> (String, TreeEntry?) {
        guard resolve else { return (path, nil) }
        let entry = try await views.storedEntry(for: path, in: head)

        if let entry { return (entry.path, entry) }
        return (try await historicalPath(path, head: head, views: views), nil)
    }

    /// HEAD 已删除目标时，从最近相关提交及其第一父提交找回实际 Unicode 路径。
    static func historicalPath(_ path: String, head: String, views: RepositoryFileViews) async throws -> String {
        let candidates = [path, path.precomposedStringWithCanonicalMapping, path.decomposedStringWithCanonicalMapping]
        var seen: Set<Data> = []

        for candidate in candidates where seen.insert(Data(candidate.utf8)).inserted {
            guard let commit = try await views.page(of: candidate, from: head, limit: 1).commits.first else {
                continue
            }

            let target = try await load(path: candidate, commit: commit, runner: views.runner)
            return target.current?.path ?? target.parent?.path ?? candidate
        }

        return path
    }
}
