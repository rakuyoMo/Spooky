import CryptoKit
import Foundation

// MARK: - WorkingCopyDiffScope

/// 一次状态取样的真实文件记录与两侧路径范围，不跨快照缓存。
struct WorkingCopyDiffScope {
    /// 保留顺序与重复路径的完整原始记录。
    let status: Data

    /// 暂存侧包含重命名的新旧路径。
    let staged: [String]

    /// 未暂存侧只比较当前新路径。
    let unstaged: [String]

    /// 路径计划按 UTF-8 字节比较，不折叠规范等价的不同 Git 路径。
    func hasSamePaths(as other: Self) -> Bool {
        staged.map { Data($0.utf8) } == other.staged.map { Data($0.utf8) }
            && unstaged.map { Data($0.utf8) } == other.unstaged.map { Data($0.utf8) }
    }
}

// MARK: - Snapshot

extension WorkingCopyOperations {
    /// 两侧补丁与精确状态计入指纹；动态排除项改变时丢弃整轮补丁，最多完整重读一次。
    func snapshot(_ entry: StatusEntry, options: DiffOptions = DiffOptions()) async throws -> DiffContents {
        var exactOptions = options
        exactOptions.ignoresWhitespace = false

        for _ in 0 ..< 2 {
            try Task.checkCancellation()
            let before = try await scope(for: entry)
            let staged = try await scopedPatch(for: entry, side: .staged, options: exactOptions, paths: before.staged)
            let unstaged = try await scopedPatch(for: entry, side: .unstaged, options: exactOptions, paths: before.unstaged)
            var shown = (staged: staged, unstaged: unstaged)

            if options.ignoresWhitespace {
                shown = (
                    try await scopedPatch(for: entry, side: .staged, options: options, paths: before.staged),
                    try await scopedPatch(for: entry, side: .unstaged, options: options, paths: before.unstaged)
                )
            }

            let after = try await scope(for: entry)
            guard before.status == after.status else { throw WorkingCopyError.staleSnapshot }
            guard before.hasSamePaths(as: after) else { continue }

            var hash = SHA256()

            // 选项不同的快照即使补丁恰好相同也不互相冒充。
            hash.update(data: Data(options.arguments.joined(separator: " ").utf8))

            for data in [before.status, staged, unstaged] + (options.ignoresWhitespace ? [shown.staged, shown.unstaged] : []) {
                hash.update(data: Data("\(data.count):".utf8))
                hash.update(data: data)
            }

            return DiffContents(
                staged: shown.staged,
                unstaged: shown.unstaged,
                exactStaged: staged,
                exactUnstaged: unstaged,
                fingerprint: Data(hash.finalize())
            )
        }

        throw WorkingCopyError.staleSnapshot
    }

    /// 按显示时的选项重新取样，每次都重新确定动态范围。
    func isCurrent(_ snapshot: DiffSnapshot) async throws -> Bool {
        try await self.snapshot(snapshot.entry, options: snapshot.options).fingerprint == snapshot.fingerprint
    }

    /// 祖先重命名读取完整状态以计算排除子树，其余目标直接使用精确路径规格。
    func scope(for entry: StatusEntry) async throws -> WorkingCopyDiffScope {
        let paths = entry.operationPaths
        let needsScope = RepositoryFileViews.needsFileChangeScope(paths)
        let arguments = ["--no-literal-pathspecs", "status", "--porcelain=v2", "-z", "--untracked-files=all"]
            + (needsScope ? [] : ["--"] + RepositoryFileViews.filePathspecs(paths))
        let output = try await runner.run(arguments)
        let records = try WorkingCopyStatus.records(in: output).records
        try validateRename(entry, in: records.compactMap(\.entry))
        let wanted = Set(paths.map { Data($0.utf8) })
        let selected = records.filter { record in
            guard let entry = record.entry else { return false }

            return wanted.contains(Data(entry.path.utf8))
                || (entry.originalPath.map { wanted.contains(Data($0.utf8)) } ?? false)
        }
        let changedPaths = records.compactMap(\.entry).flatMap { [$0.path] + [$0.originalPath].compactMap(\.self) }
        return WorkingCopyDiffScope(
            status: selected.reduce(into: Data()) { $0.append($1.raw) },
            staged: RepositoryFileViews.filePathspecs(paths, changedPaths: needsScope ? changedPaths : []),
            unstaged: RepositoryFileViews.filePathspecs([entry.path])
        )
    }

    /// 旧的重命名条目不能重新绑定到另一新旧路径配对或另一暂存侧。
    private func validateRename(_ requested: StatusEntry, in entries: [StatusEntry]) throws {
        guard requested.staged == .renamed || requested.unstaged == .renamed else { return }

        guard
            let original = requested.originalPath, entries.contains(where: { candidate in
                guard let old = candidate.originalPath else { return false }

                return candidate.path.utf8.elementsEqual(requested.path.utf8)
                    && old.utf8.elementsEqual(original.utf8)
                    && (candidate.staged == .renamed) == (requested.staged == .renamed)
                    && (candidate.unstaged == .renamed) == (requested.unstaged == .renamed)
            })
        else { throw WorkingCopyError.staleSnapshot }
    }
}
