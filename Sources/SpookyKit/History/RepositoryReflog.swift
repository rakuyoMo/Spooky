import Foundation

// MARK: - ReflogCategory

/// 引用日志动作标记的三类配色：合并类、移动类与提交类。
public enum ReflogCategory: Sendable {
    /// 合并与拉取。
    case merge

    /// 检出、重置、变基与分支操作等只移动引用的动作。
    case move

    /// 提交、摘取与反转等生成新提交的动作。
    case commit
}

// MARK: - ReflogEntry

/// 引用日志里的一条记录：引用在某一时刻移到的提交，以及这次移动的说明。
public struct ReflogEntry: Sendable, Equatable, Identifiable {
    /// 与 ``parse(_:offset:)`` 配套的 log 格式：引用日志选择器与说明在前，后面是历史提交的十个字段。
    static let format = "--format=tformat:%gD%x00%gs%x00" + String(HistoryCommit.format.dropFirst("--format=tformat:".count))

    /// 记录在本次查询结果中的位置，从 0 起；同一提交可以出现多次，靠位置区分。
    public let id: Int

    /// 记录写入的时间。
    public let date: Date

    /// 引用日志的说明，如 `checkout: moving from main to feature`。
    public let message: String

    /// 这次移动后引用指向的提交。
    public let commit: HistoryCommit

    /// 说明里的命令名：第一个词去掉结尾的冒号，如 `commit`、`checkout`、`reset`。
    public var command: String {
        let word = message.prefix { $0 != " " }
        return String(word.hasSuffix(":") ? word.dropLast() : word)
    }

    /// 动作标记的配色类别，由命令名决定。
    public var category: ReflogCategory {
        #warning(
            "TODO: 命令名到三类配色的归属未核实：合并与拉取归合并类，提交、摘取、反转与 am 归提交类，其余归移动类。核实方式：分别做一次 merge、pull、commit --amend、cherry-pick、revert、rebase、reset 与 branch，比对 Reflog 里各自标记的颜色；影响 Reflog 列表的动作标记颜色。"
        )

        switch command {
        case "merge", "pull": return .merge
        case "commit", "cherry-pick", "revert", "am": return .commit
        default: return .move
        }
    }

    /// 逐组读取十二个 NUL 字段：选择器与说明，再加上提交的十个字段。
    ///
    /// - Parameters:
    ///   - data: `log --walk-reflogs -z --date=unix` 按 ``format`` 输出的原始字节。
    ///   - offset: 本页第一条记录在查询结果中的位置。
    static func parse(_ data: Data, offset: Int) throws -> [Self] {
        guard !data.isEmpty else { return [] }
        guard data.last == 0 else { throw RepositoryReadError.malformedOutput("reflog") }

        let fields = data.dropLast().split(separator: 0, omittingEmptySubsequences: false)
        guard fields.count.isMultiple(of: 12) else { throw RepositoryReadError.malformedOutput("reflog") }

        return try stride(from: 0, to: fields.count, by: 12)
            .enumerated()
            .map { position, start in
                let values = fields[start ..< (start + 12)].map { String(decoding: $0, as: UTF8.self) }

                return try Self(
                    id: offset + position,
                    date: date(inSelector: values[0]),
                    message: values[1],
                    commit: HistoryCommit(fields: Array(values[2...]))
                )
            }
    }

    /// 从 `HEAD@{1792839575}` 这样的选择器里取出 Unix 秒；引用名不会含 `@{`，取最后一个即可。
    private static func date(inSelector selector: String) throws -> Date {
        guard
            selector.hasSuffix("}"),
            let start = selector.range(of: "@{", options: .backwards),
            let seconds = Int64(selector[start.upperBound ..< selector.index(before: selector.endIndex)])
        else { throw RepositoryReadError.malformedOutput("reflog") }

        return Date(timeIntervalSince1970: Double(seconds))
    }
}

// MARK: - ReflogPage

/// 一页引用日志与继续加载标记，额外读取一条即可判断是否还有下一页。
public struct ReflogPage: Sendable {
    /// 当前页的记录，从新到旧。
    public let entries: [ReflogEntry]

    /// 下一页是否仍有记录。
    public let hasMore: Bool
}

// MARK: - RepositoryReflog

/// HEAD 与本地分支的引用日志：分页读取、按说明搜索，以及把分支恢复到某条记录。
public struct RepositoryReflog: Sendable {
    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建引用日志服务。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 读取一页引用日志；搜索只匹配记录的说明，不区分大小写，按字面匹配。
    ///
    /// - Parameters:
    ///   - reference: `HEAD` 或本地分支的完整引用名。
    ///   - text: 搜索框里的文字，空白表示不过滤。
    ///   - offset: 跳过的记录数。
    ///   - limit: 本页最多的记录数。
    public func page(
        of reference: String,
        matching text: String = "",
        offset: Int = 0,
        limit: Int = 100
    ) async throws -> ReflogPage {
        guard Self.isValid(reference), offset >= 0, (1 ... 1000).contains(limit) else {
            throw RepositoryReadError.invalidQuery
        }

        let filter = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let search = filter.isEmpty ? [] : ["--regexp-ignore-case", "--fixed-strings", "--grep-reflog=" + filter]

        // 日期格式让选择器带上记录写入的 Unix 秒；分页与搜索都在 Git 一侧完成
        let output = try await runner.run(
            RepositoryHistory.logOptions
                + [
                    "log", "--walk-reflogs", "--no-color", "--no-decorate", "--no-patch", "-z",
                    "--date=unix", ReflogEntry.format,
                ]
                + search
                + ["--max-count=\(limit + 1)", "--skip=\(offset)", reference, "--"]
        )

        let entries = try ReflogEntry.parse(output, offset: offset)
        return ReflogPage(entries: Array(entries.prefix(limit)), hasMore: entries.count > limit)
    }

    /// 把本地分支移回某条记录的提交，不动索引与工作区；分支已不在 `expected` 上时 Git 拒绝更新。
    ///
    /// - Parameters:
    ///   - branch: 本地分支的完整引用名。
    ///   - commit: 记录里的提交。
    ///   - expected: 读取列表时分支所在的提交。
    public func restore(_ branch: String, to commit: String, expected: String) async throws {
        guard
            branch.hasPrefix("refs/heads/"), Self.isValid(branch),
            GitObjectID.isValid(commit), GitObjectID.isValid(expected)
        else { throw RepositoryReadError.invalidQuery }

        _ = try await runner.run(["update-ref", "-m", "reflog: moving to " + commit, branch, commit, expected])
    }
}

// MARK: - Private

extension RepositoryReflog {
    /// 只接受 HEAD 与本地分支的完整引用名，挡住选项与修订表达式。
    private static func isValid(_ reference: String) -> Bool {
        reference == "HEAD"
            || (reference.hasPrefix("refs/heads/") && !reference.contains("@{") && !reference.contains(".."))
    }
}
