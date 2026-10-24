import Foundation

// MARK: - RepositoryReadError

/// 结构化 Git 输出损坏时拒绝显示不完整或错位的数据。
public enum RepositoryReadError: Error, Sendable, Equatable {
    /// 发生格式错误的查询名称。
    case malformedOutput(String)

    /// 查询参数不能表示单个提交或有界分页。
    case invalidQuery
}

// MARK: - HistoryCommit

/// 历史中的不可变提交元信息，日期以 64 位 Unix 秒读取。
public struct HistoryCommit: Sendable, Equatable, Identifiable {
    /// 与 ``parse(_:)`` 配套的 log 格式：十个以 NUL 分隔的字段，正文在最后。
    static let format = "--format=tformat:%H%x00%T%x00%P%x00%an%x00%ae%x00%at%x00%cn%x00%ce%x00%ct%x00%B"

    /// 完整对象标识，不限定 SHA-1 的长度。
    public let id: String

    /// 提交对应的树对象。
    public let tree: String

    /// 按 Git 原始顺序排列的父提交。
    public let parents: [String]

    /// 原始作者姓名。
    public let author: String

    /// 原始作者邮箱。
    public let authorEmail: String

    /// 作者日期。
    public let authorDate: Date

    /// 实际提交人姓名。
    public let committer: String

    /// 实际提交人邮箱。
    public let committerEmail: String

    /// 列表使用提交人日期。
    public let commitDate: Date

    /// 包含标题和正文的完整提交信息。
    public let message: String

    /// 列表只展示第一行，详情保留全文。
    public var subject: String { String(message.prefix { $0 != "\n" }) }

    /// 短哈希只用于显示，动作始终使用完整对象标识。
    public var shortID: String { String(id.prefix(8)) }

    /// 逐组读取固定数量的 NUL 字段，正文中的换行和分隔控制字符不影响边界。
    static func parse(_ data: Data) throws -> [Self] {
        guard !data.isEmpty else { return [] }
        guard data.last == 0 else { throw RepositoryReadError.malformedOutput("log") }
        let fields = data.dropLast().split(separator: 0, omittingEmptySubsequences: false)
        guard fields.count.isMultiple(of: 10) else { throw RepositoryReadError.malformedOutput("log") }

        return try stride(from: 0, to: fields.count, by: 10)
            .map { start in
                try Self(fields: fields[start ..< (start + 10)].map { String(decoding: $0, as: UTF8.self) })
            }
    }
}

extension HistoryCommit {
    /// 按 ``format`` 的字段顺序解出一个提交；引用日志在同一条记录前面另加字段时也用它。
    ///
    /// - Parameter fields: 恰好十个字段，正文在最后。
    init(fields values: [String]) throws {
        guard values.count == 10 else { throw RepositoryReadError.malformedOutput("log") }

        let parents = values[2].split(separator: " ").map(String.init)

        guard
            GitObjectID.isValid(values[0]), GitObjectID.isValid(values[1]),
            parents.allSatisfy(GitObjectID.isValid),
            let authorTime = Int64(values[5]), let commitTime = Int64(values[8])
        else { throw RepositoryReadError.malformedOutput("log") }

        self.init(
            id: values[0],
            tree: values[1],
            parents: parents,
            author: values[3],
            authorEmail: values[4],
            authorDate: Date(timeIntervalSince1970: Double(authorTime)),
            committer: values[6],
            committerEmail: values[7],
            commitDate: Date(timeIntervalSince1970: Double(commitTime)),
            message: values[9]
        )
    }
}

// MARK: - HistoryPage

/// 一页历史与继续加载标记，额外读取一条即可判断是否存在下一页。
public struct HistoryPage: Sendable {
    /// 当前页的提交。
    public let commits: [HistoryCommit]

    /// 下一页是否仍有数据。
    public let hasMore: Bool
}

// MARK: - CommitFileChange

/// 提交变更集中的单个文件，路径来自 NUL 字段而非补丁标题。
public struct CommitFileChange: Sendable, Equatable, Identifiable {
    /// 修改后的路径，删除时为原路径。
    public let path: String

    /// 重命名或复制的来源路径。
    public let originalPath: String?

    /// Git raw 格式中的状态字母，包含类型变化。
    public let status: String

    /// 文本新增行数，二进制为 nil。
    public var additions: Int?

    /// 文本删除行数，二进制为 nil。
    public var deletions: Int?

    /// 新路径作为变更集内的稳定标识。
    public var id: String { path }

    /// raw 与 numstat 通过原始路径配对，二进制和重命名不会让后续统计错位。
    ///
    /// - Parameter combined: 请求的是组合 Diff。合并提交的记录以 `::` 开头、没有增删行数；
    ///   同一输出里的 numstat 是与第一父提交比较的结果，对不上单父记录的统计忽略。
    static func parse(_ data: Data, combined: Bool = false) throws -> [Self] {
        guard !data.isEmpty else { return [] }
        guard data.last == 0 else { throw RepositoryReadError.malformedOutput("changeset") }

        let fields = data
            .dropLast()
            .split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        var records: [(file: Self, combined: Bool)] = []
        var statistics: [ChangeStatistic] = []
        var cursor = 0

        // 组合 Diff 的 numstat 排在 raw 之前，先分别收集两种记录，再按路径配对。
        while cursor < fields.count {
            let field = fields[cursor]
            cursor += 1

            if field.hasPrefix(":") {
                records.append(try record(field, fields: fields, cursor: &cursor))
            } else {
                statistics.append(try ChangeStatistic(field, fields: fields, cursor: &cursor))
            }
        }

        return try counted(records, statistics: statistics, strict: !combined)
    }

    /// 解析一条 raw 记录：单父为 “:旧模式 新模式 旧哈希 新哈希 状态”，组合 Diff 的冒号、模式与哈希随父提交数增加。
    private static func record(
        _ header: String,
        fields: [String],
        cursor: inout Int
    ) throws -> (file: Self, combined: Bool) {
        let parents = header.prefix { $0 == ":" }.count
        let parts = header.dropFirst(parents).split(separator: " ")

        guard
            parts.count == 2 * (parents + 1) + 1,
            parts.prefix(parents + 1).allSatisfy({ $0.count == 6 && $0.allSatisfy { "01234567".contains($0) } }),
            parts.dropFirst(parents + 1).dropLast().allSatisfy({ GitObjectID.isValid(String($0)) }),
            let letters = parts.last,
            cursor < fields.count
        else { throw RepositoryReadError.malformedOutput("changeset") }

        // 单父的状态可带相似度分数，如 R100；组合 Diff 每个父提交一个字母
        let statuses = parents == 1 ? String(letters.prefix(1)) : String(letters)

        guard
            statuses.count == parents,
            statuses.allSatisfy({ "ADMCRTU".contains($0) })
        else { throw RepositoryReadError.malformedOutput("changeset") }

        let original = fields[cursor]
        cursor += 1

        // 组合 Diff 只给出合并结果里的路径，重命名的来源路径只出现在单父记录里
        let renamed = parents == 1 && (statuses == "R" || statuses == "C")

        guard !renamed || cursor < fields.count else {
            throw RepositoryReadError.malformedOutput("changeset")
        }

        let path = renamed ? fields[cursor] : original
        if renamed { cursor += 1 }

        guard !path.isEmpty, !original.isEmpty else { throw RepositoryReadError.malformedOutput("changeset") }

        // 组合 Diff 相对各父提交的状态不同时按修改显示
        let status = Set(statuses).count == 1 ? String(statuses.prefix(1)) : "M"

        let file = Self(
            path: path,
            originalPath: renamed ? original : nil,
            status: status,
            additions: nil,
            deletions: nil
        )

        return (file, parents > 1)
    }

    /// 把增删行数填回对应的单父记录；严格模式下每条统计都必须配对，两种模式下每条单父记录都必须有统计。
    private static func counted(
        _ records: [(file: Self, combined: Bool)],
        statistics: [ChangeStatistic],
        strict: Bool
    ) throws -> [Self] {
        var files = records.map(\.file)
        var indices: [String: Int] = [:]

        for (index, file) in files.enumerated() {
            guard indices[file.path] == nil else { throw RepositoryReadError.malformedOutput("changeset") }
            indices[file.path] = index
        }

        var counted = Set<String>()

        for statistic in statistics {
            guard
                let index = indices[statistic.path],
                !records[index].combined,
                !counted.contains(statistic.path),
                files[index].originalPath == statistic.original
            else {
                if strict { throw RepositoryReadError.malformedOutput("numstat") }
                continue
            }

            files[index].additions = statistic.additions
            files[index].deletions = statistic.deletions
            counted.insert(statistic.path)
        }

        guard counted.count == records.count(where: { !$0.combined }) else {
            throw RepositoryReadError.malformedOutput("numstat")
        }

        return files
    }
}

// MARK: - ChangeStatistic

/// 一条 numstat 记录；二进制文件的增删行数为 nil。
private struct ChangeStatistic {
    /// 修改后的路径。
    let path: String

    /// 重命名或复制的来源路径。
    let original: String?

    /// 新增行数。
    let additions: Int?

    /// 删除行数。
    let deletions: Int?

    /// 解析 “增\t删\t路径”；重命名的路径字段为空，随后是来源与目标两个 NUL 字段。
    init(_ field: String, fields: [String], cursor: inout Int) throws {
        let stats = field.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
        guard stats.count == 3 else { throw RepositoryReadError.malformedOutput("numstat") }

        var path = String(stats[2])
        var original: String? = nil

        if path.isEmpty {
            guard cursor + 1 < fields.count else { throw RepositoryReadError.malformedOutput("numstat") }

            original = fields[cursor]
            path = fields[cursor + 1]
            cursor += 2
        }

        let binary = stats[0] == "-" && stats[1] == "-"
        let additions = Int(stats[0])
        let deletions = Int(stats[1])

        guard binary || ((additions ?? -1) >= 0 && (deletions ?? -1) >= 0) else {
            throw RepositoryReadError.malformedOutput("numstat")
        }

        self.path = path
        self.original = original
        self.additions = additions
        self.deletions = deletions
    }
}

// MARK: - CommitDiff

/// 历史补丁只读，沿用工作区的大 Diff 阈值与解析器。
public struct CommitDiff: Sendable {
    /// 单次补丁字节数。
    public let byteCount: Int

    /// 超过阈值时等待用户放行。
    public let diff: RepositoryDiff?

    /// 忽略空白后没有剩下任何改动；变更集列出的文件一定有差异，空补丁只能来自空白。
    public let onlyWhitespaceChanges: Bool
}

// MARK: - RepositoryHistory

/// 历史读取在仓库所在机器完成；分页的根固定为对象哈希，避免新提交导致翻页重复。
public struct RepositoryHistory: Sendable {
    /// 屏蔽用户配置中的签名、编码与根提交显示选项，保持协议稳定；文件历史沿用同一组选项。
    static let logOptions = [
        "-c", "log.showSignature=false", "-c", "i18n.logOutputEncoding=UTF-8",
        "-c", "log.date=default", "-c", "log.showRoot=true",
    ]

    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建只读历史服务。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 读取固定根集合按查询筛选、排序后的一页；空集合表示仓库没有可显示的提交。
    public func page(
        roots: [String],
        query: HistoryQuery = HistoryQuery(),
        offset: Int = 0,
        limit: Int = 100
    ) async throws -> HistoryPage {
        guard offset >= 0, (1 ... 1000).contains(limit), roots.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }
        guard !roots.isEmpty else { return HistoryPage(commits: [], hasMore: false) }

        // 按哈希搜索最多命中几个提交，不经分页
        if !query.hashPrefixes.isEmpty {
            let commits = try await commits(matchingHashesIn: query, roots: roots)
            return HistoryPage(commits: Array(commits.dropFirst(offset).prefix(limit)), hasMore: false)
        }

        // 根集合经 stdin 传递，引用数量不会扩大进程参数长度；固定根与固定条件的分页结果不再变化，可按哈希复用。
        let output = try await runner.immutableRun(
            RepositoryFileViews.storedPathOptions + Self.logOptions + [
                "log", "--no-color", "--no-decorate", "--no-patch", "-z", HistoryCommit.format,
            ]
                + query.orderArguments
                + query.filterArguments
                + ["--max-count=\(limit + 1)", "--skip=\(offset)", "--stdin", "--"]
                + query.paths,
            input: Self.rootsInput(roots)
        )
        let commits = try HistoryCommit.parse(output)
        return HistoryPage(commits: Array(commits.prefix(limit)), hasMore: commits.count > limit)
    }

    /// 根提交显式显示全部新增，合并提交按指定方式比较；变更集只由提交哈希与方式决定，按参数复用。
    public func changes(
        in commit: String,
        mergeMode: MergeDiffMode = .firstParent
    ) async throws -> [CommitFileChange] {
        guard GitObjectID.isValid(commit) else { throw RepositoryReadError.invalidQuery }

        let output = try await runner.immutableRun(
            Self.logOptions
                + ["show", "--format=", "--root"]
                + mergeMode.arguments
                + [
                    "--no-color", "--no-ext-diff", "--no-textconv", "--raw", "--numstat", "--no-abbrev",
                    "-z", "-M", "-C", commit, "--",
                ]
        )

        return try CommitFileChange.parse(output, combined: mergeMode == .mergedFilePaths)
    }

    /// 按需加载指定提交的文件补丁，不沿历史搜索更早修改；补丁按提交哈希、方式与路径复用。
    public func diff(
        in commit: String,
        file: CommitFileChange,
        mergeMode: MergeDiffMode = .firstParent,
        options: DiffOptions = DiffOptions(),
        warningKilobytes: Int = WorkingCopyOperations.defaultWarningKilobytes,
        showLarge: Bool = false
    ) async throws -> CommitDiff {
        guard GitObjectID.isValid(commit) else { throw RepositoryReadError.invalidQuery }
        let paths = [file.path] + (file.originalPath.map { [$0] } ?? [])
        let patch = try await runner.immutableRun(
            RepositoryFileViews.storedPathOptions + Self.logOptions
                + ["show", "--format=", "--root"]
                + mergeMode.arguments
                + [
                    "--no-color", "--word-diff=none", "--no-ext-diff", "--no-textconv", "--full-index",
                    "-M", "-C", "--src-prefix=a/", "--dst-prefix=b/",
                ]
                + options.arguments + [commit, "--"] + paths
        )

        return try CommitDiff(
            patch: patch,
            options: options,
            warningKilobytes: warningKilobytes,
            showLarge: showLarge
        )
    }

}

// MARK: - GitObjectID

/// 对象参数只接受十六进制，长度由仓库算法决定。
enum GitObjectID {
    /// 拒绝空值、选项和修订表达式，允许 Git 支持的动态哈希长度。
    static func isValid(_ value: String) -> Bool {
        value.count >= 4 && value.utf8.allSatisfy { (48 ... 57).contains($0) || (97 ... 102).contains($0) }
    }
}
