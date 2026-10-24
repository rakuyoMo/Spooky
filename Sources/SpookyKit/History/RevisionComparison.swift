import Foundation

// MARK: - RevisionComparison

/// 两个版本的比较：目标里有、基准里没有的提交，以及从基准到目标的文件改动。
///
/// 两侧都是对象哈希，结果只由哈希决定，按参数复用。
public struct RevisionComparison: Sendable {
    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 比较的基准提交。
    public let base: String

    /// 比较的目标提交。
    public let target: String

    /// 两侧都必须是对象哈希，不能成为 Git 选项或修订表达式。
    private var isValid: Bool {
        GitObjectID.isValid(base) && GitObjectID.isValid(target)
    }

    /// 创建比较，不立即访问仓库。
    ///
    /// - Parameters:
    ///   - base: 基准提交的完整哈希。
    ///   - target: 目标提交的完整哈希。
    public init(runner: GitRunner, base: String, target: String) {
        self.runner = runner
        self.base = base
        self.target = target
    }

    /// 一页目标独有的提交，按拓扑序从新到旧。
    public func commits(offset: Int = 0, limit: Int = 100) async throws -> HistoryPage {
        guard isValid, offset >= 0, (1 ... 1000).contains(limit) else {
            throw RepositoryReadError.invalidQuery
        }

        // 多取一条判断是否还有下一页
        let output = try await runner.immutableRun(
            RepositoryHistory.logOptions + [
                "log", "--no-color", "--no-decorate", "--no-patch", "--topo-order", "-z", HistoryCommit.format,
                "--max-count=\(limit + 1)", "--skip=\(offset)", target, "^" + base, "--",
            ]
        )

        let commits = try HistoryCommit.parse(output)

        return HistoryPage(commits: Array(commits.prefix(limit)), hasMore: commits.count > limit)
    }

    /// 从基准到目标改动的文件。
    public func changes() async throws -> [CommitFileChange] {
        guard isValid else {
            throw RepositoryReadError.invalidQuery
        }

        let output = try await runner.immutableRun([
            "diff", "--no-color", "--no-ext-diff", "--no-textconv", "--raw", "--numstat", "--no-abbrev",
            "-z", "-M", "-C", base, target, "--",
        ])

        return try CommitFileChange.parse(output)
    }

    /// 单个文件从基准到目标的补丁，超过大 Diff 阈值时等待放行。
    public func diff(
        of file: CommitFileChange,
        options: DiffOptions = DiffOptions(),
        warningKilobytes: Int = WorkingCopyOperations.defaultWarningKilobytes,
        showLarge: Bool = false
    ) async throws -> CommitDiff {
        guard isValid else {
            throw RepositoryReadError.invalidQuery
        }

        let paths = [file.path] + (file.originalPath.map { [$0] } ?? [])

        let patch = try await runner.immutableRun(
            RepositoryFileViews.storedPathOptions
                + [
                    "diff", "--no-color", "--word-diff=none", "--no-ext-diff", "--no-textconv", "--full-index",
                    "-M", "-C", "--src-prefix=a/", "--dst-prefix=b/",
                ]
                + options.arguments + [base, target, "--"] + paths
        )

        return try CommitDiff(
            patch: patch,
            options: options,
            warningKilobytes: warningKilobytes,
            showLarge: showLarge
        )
    }
}

// MARK: - CommitDiff

extension CommitDiff {
    /// 按大 Diff 阈值决定是否解析补丁；二进制补丁很短，总是解析。
    init(patch: Data, options: DiffOptions, warningKilobytes: Int, showLarge: Bool) throws {
        let threshold = max(0, min(warningKilobytes, Int.max / 1000)) * 1000

        // Foundation 的 range(of:) 与 contains 结果相同，在数十 MB 的补丁上快数百倍。
        // swiftlint:disable:next contains_over_range_nil_comparison
        let binary = patch.range(of: Data("\nBinary files ".utf8)) != nil

        self.init(
            byteCount: patch.count,
            diff: patch.count <= threshold || showLarge || binary ? try RepositoryDiff(patch: patch) : nil,
            onlyWhitespaceChanges: options.ignoresWhitespace && patch.isEmpty
        )
    }
}
