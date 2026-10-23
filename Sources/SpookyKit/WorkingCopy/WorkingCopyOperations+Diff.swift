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

    /// 选中文件相对 HEAD 的全部改动，含暂存区、工作区与未跟踪文件，可交给 `git apply` 使用。
    ///
    /// - Parameters:
    ///   - entries: 要写进补丁的状态条目；未跟踪的目录不计入。
    ///   - omittingPrefixes: 路径不带 `a/`、`b/` 前缀，应用时需要 `-p0`。
    public func patchFile(for entries: [StatusEntry], omittingPrefixes: Bool) async throws -> Data {
        let prefixes = omittingPrefixes ? ["--no-prefix"] : ["--src-prefix=a/", "--dst-prefix=b/"]
        let arguments = [
            "--binary", "--no-color", "--no-ext-diff", "--no-textconv",
            "--full-index", "--no-relative", "-C", "-M",
        ] + prefixes

        let tracked = entries.filter { $0.kind != .untracked }.flatMap(\.operationPaths)
        let untracked = entries.filter { $0.kind == .untracked && !$0.path.hasSuffix("/") }.map(\.path)
        var patch = Data()

        // 还没有提交时与空树比较，暂存区与工作区的改动同样计入
        let paths = Array(Set(tracked)).sorted()
        let base = paths.isEmpty ? "" : try await comparisonBase()

        // git diff 不能从标准输入读路径，分批传参，避免超出本机与 SSH 的命令长度上限
        for start in stride(from: 0, to: paths.count, by: 1000) {
            let batch = paths[start ..< min(start + 1000, paths.count)]

            patch += try await runner.run(
                ["--literal-pathspecs", "diff"] + arguments + [base, "--"] + batch
            )
        }

        for path in untracked {
            patch += try await runner.execute(
                ["diff", "--no-index"] + arguments + ["--", "/dev/null", path],
                acceptedExitCodes: [0, 1]
            ).standardOutput
        }

        return patch
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

    /// 补丁文件的比较起点：HEAD，没有提交时为当前对象格式的空树。
    private func comparisonBase() async throws -> String {
        let head = try await runner.execute(
            ["rev-parse", "--verify", "--quiet", "HEAD"],
            acceptedExitCodes: [0, 1]
        )

        guard head.exitCode != 0 else {
            return "HEAD"
        }

        // 不加 -w 只计算哈希，不写入对象库
        let tree = try await runner.run(["hash-object", "-t", "tree", "--stdin"], input: Data())
        return String(decoding: tree, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
