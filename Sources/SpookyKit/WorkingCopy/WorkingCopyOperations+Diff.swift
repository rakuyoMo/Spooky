import Foundation

// MARK: - DiffContents

/// 一次快照读到的补丁：显示用的两侧、逐字节的两侧与联合摘要。
struct DiffContents {
    /// 显示用的暂存区补丁，忽略空白时不含空白差异。
    let staged: Data

    /// 显示用的工作区补丁。
    let unstaged: Data

    /// 逐字节的暂存区补丁。
    let exactStaged: Data

    /// 逐字节的工作区补丁。
    let exactUnstaged: Data

    /// 状态与全部补丁的联合摘要。
    let fingerprint: Data
}

// MARK: - Diff

extension WorkingCopyOperations {
    /// 单文件 Diff 的固定参数：完整哈希、固定前缀、不调用外部程序与文本转换，输出可直接写回。
    static let diffArguments = [
        "--no-color", "--word-diff=none", "--no-ext-diff", "--no-textconv", "--full-index",
        "--src-prefix=a/", "--dst-prefix=b/", "--no-relative", "--diff-algorithm=myers", "-C", "-M",
    ]

    /// 按显示选项读取一侧的单文件补丁；未跟踪文件与 `/dev/null` 比较，在仓库所在机器上生成。
    ///
    /// - Parameters:
    ///   - entry: 状态条目，重命名时一并比较原路径。
    ///   - side: 暂存区相对 HEAD，或工作区相对暂存区。
    ///   - options: 上下文行数、显示整个文件与忽略空白。
    public func patch(for entry: StatusEntry, side: DiffSide, options: DiffOptions) async throws -> Data {
        let arguments = Self.diffArguments + options.arguments

        switch side {
        case .staged:
            return try await runner.run(
                ["--literal-pathspecs", "diff", "--cached"] + arguments + ["--"] + entry.operationPaths
            )

        case .unstaged where entry.kind == .untracked:
            guard !entry.path.hasSuffix("/") else { throw WorkingCopyError.unsupportedFile }

            // no-index 有差异时退出码为 1
            return try await runner.execute(
                ["diff", "--no-index"] + arguments + ["--", "/dev/null", entry.path],
                acceptedExitCodes: [0, 1]
            ).standardOutput

        case .unstaged:
            return try await runner.run(
                ["--literal-pathspecs", "diff"] + arguments + ["--", entry.path]
            )
        }
    }

    /// 写入用的补丁：普通选项直接取显示的块；忽略空白时在逐字节的整文件 Diff 中找到同一批改动再生成。
    func writablePatch(
        _ snapshot: DiffSnapshot,
        file: Int,
        hunk: Int,
        lines: Set<Int>,
        reverse: Bool
    ) async throws -> Data {
        guard let diff = snapshot.diff else { throw WorkingCopyError.invalidSelection }

        guard snapshot.options.ignoresWhitespace else {
            return try diff.patch(
                path: snapshot.entry.path,
                file: file,
                hunk: hunk,
                selectedLines: lines,
                reverse: reverse
            )
        }

        guard
            diff.files.indices.contains(file),
            diff.files[file].hunks.indices.contains(hunk)
        else { throw WorkingCopyError.invalidSelection }

        // 没有选行时处理整块显示出的改动，空白差异保持原样
        let shown = diff.files[file].hunks[hunk].lines.filter {
            $0.isChange && (lines.isEmpty || lines.contains($0.id))
        }

        // 整文件上下文让全部改动落在同一块里，选中的行无论相隔多远都能一次写回
        let exactPatch = try await patch(
            for: snapshot.entry,
            side: snapshot.side,
            options: DiffOptions(showsEntireFile: true)
        )
        let exact = try RepositoryDiff(patch: exactPatch)

        guard let matched = exact.matchingChanges(of: shown) else {
            throw WorkingCopyError.whitespaceMismatch
        }

        return try exact.patch(
            path: snapshot.entry.path,
            file: 0,
            hunk: matched.hunk,
            selectedLines: matched.lines,
            reverse: reverse
        )
    }
}
