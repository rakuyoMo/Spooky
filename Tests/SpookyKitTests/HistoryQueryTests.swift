import Foundation
import Subprocess
import Testing

@testable import SpookyKit

// MARK: - HistoryQueryTests

/// 真实 Git 验证历史搜索的条件组合、特殊路径、哈希前缀、日期、排序与第一父。
struct HistoryQueryTests {
    /// 测试仓库里的提交，按创建顺序。
    private struct Commits {
        /// Alice 在 2026-01-01 添加带空格、中文与方括号的路径。
        let initial: String

        /// Unicode 作者、提交人 Bob，在 2026-01-02 添加带引号、换行与通配符的路径。
        let fix: String

        /// side 分支上 Carol 的提交，2026-01-03。
        let side: String

        /// main 上的提交，2026-01-04。
        let main: String

        /// 合并 side 的提交，2026-01-05。
        let merge: String
    }

    /// 带空格、中文与方括号的路径。
    private static let bracketPath = "文档/说明 [v1].md"

    /// 带引号、换行与通配符的路径。
    private static let weirdPath = "weird \"quote\"\nname*.txt"

    /// 日期条件按 UTC 的整天换算，结果不随运行机器的时区变化。
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// 每类条件单独筛选，同类取并集、不同类取交集；说明、作者与提交人按基本正则匹配、忽略大小写，文件按字面匹配。
    @Test("按信息、作者、提交人与文件组合搜索", arguments: ["sha1", "sha256"])
    func textConditions(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let commits = try await Self.makeHistory(in: fixture, objectFormat: objectFormat)
        let history = RepositoryHistory(runner: fixture.runner)

        // 忽略大小写的基本正则：转义的星号按字面匹配，`.*` 与行首、行尾按正则解释
        #expect(try await Self.subjects(history, commits, [.init(kind: .message, text: "fix BUG")]) == ["Fix bug *star*"])
        #expect(try await Self.subjects(history, commits, [.init(kind: .message, text: "bug \\*STAR\\*")]) == ["Fix bug *star*"])
        #expect(try await Self.subjects(history, commits, [.init(kind: .message, text: "^fix.*\\*$")]) == ["Fix bug *star*"])
        #expect(
            Set(try await Self.subjects(history, commits, [.init(kind: .message, text: "work$")])) ==
                ["side work", "main work"]
        )

        // Unicode 作者与提交人
        #expect(try await Self.subjects(history, commits, [.init(kind: .author, text: "李 café")]) == ["Fix bug *star*"])
        #expect(try await Self.subjects(history, commits, [.init(kind: .committer, text: "bob")]) == ["Fix bug *star*"])

        // 同类条件取并集，不同类条件取交集
        let either = try await Self.subjects(
            history,
            commits,
            [.init(kind: .author, text: "alice"), .init(kind: .author, text: "carol")]
        )
        #expect(Set(either) == ["初始提交", "side work"])

        let both = try await Self.subjects(
            history,
            commits,
            [.init(kind: .author, text: "alice"), .init(kind: .message, text: "side")]
        )
        #expect(both.isEmpty)

        // 文件按字面路径匹配，通配符不会展开
        #expect(try await Self.subjects(history, commits, [.init(kind: .file, text: Self.bracketPath)]) == ["初始提交"])
        #expect(try await Self.subjects(history, commits, [.init(kind: .file, text: Self.weirdPath)]) == ["Fix bug *star*"])
        #expect(try await Self.subjects(history, commits, [.init(kind: .file, text: "*")]).isEmpty)
        #expect(try await Self.subjects(history, commits, [.init(kind: .file, text: "文档")]) == ["初始提交"])

        // 空条件不参与筛选
        let all = try await Self.subjects(history, commits, [.init(kind: .message, text: "  ")])
        #expect(all.count == 5)
    }

    /// 哈希前缀解析成唯一的提交，只在所选引用的历史里出现，并与其它条件取交集。
    @Test("按哈希前缀搜索", arguments: ["sha1", "sha256"])
    func hashConditions(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let commits = try await Self.makeHistory(in: fixture, objectFormat: objectFormat)
        let history = RepositoryHistory(runner: fixture.runner)
        let prefix = String(commits.fix.prefix(7)).uppercased()

        let found = try await history.page(
            roots: [commits.merge],
            query: HistoryQuery(conditions: [.init(kind: .hash, text: " \(prefix) ")])
        )
        #expect(found.commits.map(\.id) == [commits.fix])
        #expect(!found.hasMore)
        #expect(found.commits.first?.id.count == (objectFormat == "sha1" ? 40 : 64))

        // side 上的提交不在合并之前的 main 历史里
        let unreachable = try await history.page(
            roots: [commits.main],
            query: HistoryQuery(conditions: [.init(kind: .hash, text: String(commits.side.prefix(8)))])
        )
        #expect(unreachable.commits.isEmpty)

        // 不是十六进制、少于 4 位或与其它条件不符时没有结果
        for text in ["xyz1", String(commits.fix.prefix(3))] {
            let page = try await history.page(
                roots: [commits.merge],
                query: HistoryQuery(conditions: [.init(kind: .hash, text: text)])
            )
            #expect(page.commits.isEmpty)
        }

        let mismatch = HistoryQuery(conditions: [
            .init(kind: .hash, text: prefix),
            .init(kind: .message, text: "nothing"),
        ])
        #expect(try await history.page(roots: [commits.merge], query: mismatch).commits.isEmpty)
        #expect(try await history.count(roots: [commits.merge], query: mismatch, limit: 10) == 0)
        #expect(try await history.contains(commits.side, roots: [commits.merge]))
        #expect(try await !history.contains(commits.side, roots: [commits.main]))
    }

    /// 日期条件按整天比较提交人日期；多个日期条件取交集。
    @Test("按日期之后、之前与区间搜索", arguments: ["sha1", "sha256"])
    func dateConditions(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let commits = try await Self.makeHistory(in: fixture, objectFormat: objectFormat)
        let history = RepositoryHistory(runner: fixture.runner)
        let third = try Self.day(3)

        let after = HistorySearchCondition(kind: .date, relation: .after, date: third)
        #expect(Set(try await Self.subjects(history, commits, [after])) == ["main work", "merge side"])

        let before = HistorySearchCondition(kind: .date, relation: .before, date: try Self.day(2))
        #expect(try await Self.subjects(history, commits, [before]) == ["初始提交"])

        // 结束日早于起始日时交换两端
        let range = HistorySearchCondition(kind: .date, relation: .range, date: third, endDate: try Self.day(2))
        #expect(Set(try await Self.subjects(history, commits, [range])) == ["Fix bug *star*", "side work"])

        #expect(try await Self.subjects(history, commits, [after, before]).isEmpty)
    }

    /// 只沿第一父时不出现合并进来的提交；按日期排序时严格按提交人日期倒序；计数到上限为止。
    @Test("排序、第一父、计数与分页", arguments: ["sha1", "sha256"])
    func orderAndCount(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let commits = try await Self.makeHistory(in: fixture, objectFormat: objectFormat)
        let history = RepositoryHistory(runner: fixture.runner)
        let roots = [commits.merge]

        let firstParent = try await history.page(roots: roots, query: HistoryQuery(firstParentOnly: true))
        #expect(firstParent.commits.map(\.id) == [commits.merge, commits.main, commits.fix, commits.initial])

        let byDate = try await history.page(roots: roots, query: HistoryQuery(order: .date))
        #expect(byDate.commits.map(\.id) == [commits.merge, commits.main, commits.side, commits.fix, commits.initial])

        // 拓扑序里子提交总在父提交之前
        let topo = try await history.page(roots: roots, query: HistoryQuery(order: .topological)).commits
        let positions = Dictionary(uniqueKeysWithValues: topo.enumerated().map { ($0.element.id, $0.offset) })

        for commit in topo {
            for parent in commit.parents {
                #expect((positions[commit.id] ?? 0) < (positions[parent] ?? -1))
            }
        }

        #expect(try await history.count(roots: roots, limit: 100) == 5)
        #expect(try await history.count(roots: roots, limit: 3) == 3)
        #expect(try await history.count(roots: roots, query: HistoryQuery(firstParentOnly: true), limit: 100) == 4)
        #expect(try await history.count(roots: [], limit: 100) == 0)

        // 搜索结果同样分页
        let query = HistoryQuery(conditions: [.init(kind: .author, text: "spooky")])
        let first = try await history.page(roots: roots, query: query, limit: 1)
        let second = try await history.page(roots: roots, query: query, offset: 1, limit: 1)
        #expect(first.hasMore)
        #expect(!second.hasMore)
        #expect(first.commits.map(\.subject) + second.commits.map(\.subject) == ["merge side", "main work"])
    }

    /// rev-list 的计数不是整数时拒绝显示。
    @Test("计数输出损坏时报告格式错误")
    func malformedCount() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let executable = fixture.directory.appending(path: "broken-git")
        try Data("#!/bin/sh\ncat > /dev/null\nprintf 'many\\n'\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let runner = fixture.runner(at: fixture.directory.path, executable: executable.path)
        let root = String(repeating: "a", count: 40)

        await #expect(throws: RepositoryReadError.malformedOutput("rev-list")) {
            try await RepositoryHistory(runner: runner).count(roots: [root], limit: 10)
        }
    }
}

// MARK: - Position

extension HistoryQueryTests {
    /// 回到历史时按提交的下标决定是否询问，下标必须与列表分页的顺序一致，否则会多载或少载。
    @Test("提交在历史中的位置与分页顺序一致", arguments: ["sha1", "sha256"])
    func position(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let commits = try await Self.makeHistory(in: fixture, objectFormat: objectFormat)
        let history = RepositoryHistory(runner: fixture.runner)
        let roots = [commits.merge]

        // 各种排序、只沿第一父与带特殊字符的文件条件下，下标都等于分页里的次序
        let queries = [
            HistoryQuery(order: .topological),
            HistoryQuery(order: .date),
            HistoryQuery(order: .default, firstParentOnly: true),
            HistoryQuery(conditions: [.init(kind: .file, text: Self.bracketPath)]),
            HistoryQuery(conditions: [.init(kind: .file, text: Self.weirdPath)]),
        ]

        for query in queries {
            let order = try await history.page(roots: roots, query: query).commits.map(\.id)

            for (index, id) in order.enumerated() {
                #expect(try await history.position(of: id, roots: roots, query: query, limit: 100) == index)
            }
        }

        // 只看前 limit 个；只沿第一父时合并进来的提交、文件条件之外的提交都不在其中
        #expect(try await history.position(of: commits.initial, roots: roots, limit: 2) == nil)
        #expect(
            try await history.position(
                of: commits.side,
                roots: roots,
                query: HistoryQuery(firstParentOnly: true),
                limit: 100
            ) == nil
        )
        #expect(try await history.position(of: commits.fix, roots: roots, query: queries[3], limit: 100) == nil)
        #expect(try await history.position(of: commits.merge, roots: [], limit: 100) == nil)

        // 不是哈希的提交、哈希条件与非正的上限都拒绝
        let hashQuery = HistoryQuery(conditions: [.init(kind: .hash, text: String(commits.fix.prefix(7)))])

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await history.position(of: "HEAD", roots: roots, limit: 100)
        }

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await history.position(of: commits.fix, roots: roots, query: hashQuery, limit: 100)
        }

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await history.position(of: commits.fix, roots: roots, limit: 0)
        }
    }

    /// rev-list 每行一个哈希；空输出里没有位置，夹杂别的文字时拒绝，不把它当成找不到。
    @Test("解析提交位置的输出")
    func parsePosition() throws {
        let first = String(repeating: "a", count: 40)
        let second = String(repeating: "b", count: 64)
        let output = Data("\(first)\n\(second)\n".utf8)

        #expect(try RepositoryHistory.position(of: second, in: output) == 1)
        #expect(try RepositoryHistory.position(of: String(repeating: "c", count: 40), in: output) == nil)
        #expect(try RepositoryHistory.position(of: first, in: Data()) == nil)

        #expect(throws: RepositoryReadError.malformedOutput("rev-list")) {
            try RepositoryHistory.position(of: first, in: Data("\(first)\nwarning: refname is ambiguous\n".utf8))
        }
    }
}

// MARK: - Regex

extension HistoryQueryTests {
    /// 说明、作者与提交人按基本正则匹配，与在 Git 里直接搜索相同；仓库配置的 grep.patternType 不改变匹配方式。
    @Test("说明、作者与提交人按基本正则匹配", arguments: ["sha1", "sha256"])
    func regexConditions(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let head = try await Self.makeRegexHistory(in: fixture, objectFormat: objectFormat)
        let history = RepositoryHistory(runner: fixture.runner)

        // 点号匹配任一字符，转义后只匹配点号本身
        let dot = try await Self.subjects(history, head: head, [.init(kind: .message, text: "A.C")])
        #expect(Set(dot) == ["abc search target", "axc other", "a.c literal target"])

        let escaped = try await Self.subjects(history, head: head, [.init(kind: .message, text: "a\\.c")])
        #expect(escaped == ["a.c literal target"])

        // 作者与提交人同样按正则匹配，行首从姓名开始
        let author = try await Self.subjects(history, head: head, [.init(kind: .author, text: "^C.ROL")])
        #expect(author == ["call(x) done"])

        let committer = try await Self.subjects(history, head: head, [.init(kind: .committer, text: "^bob <.*>$")])
        #expect(committer == ["axc other"])

        // 交给 Git 的参数固定按基本正则匹配、忽略大小写
        let query = HistoryQuery(conditions: [.init(kind: .message, text: "a.c")])
        #expect(query.filterArguments == ["-i", "--basic-regexp", "--grep=a.c"])

        // 仓库配置成扩展正则时，括号仍按基本正则当作普通字符，列表与计数一致
        _ = try await fixture.runner.run(["config", "--local", "grep.patternType", "extended"])
        let parenthesis = HistoryQuery(conditions: [.init(kind: .message, text: "l(x")])

        #expect(try await history.page(roots: [head], query: parenthesis).commits.map(\.subject) == ["call(x) done"])
        #expect(try await history.count(roots: [head], query: parenthesis, limit: 10) == 1)
    }

    /// Git 编译不了的正则不执行 Git：列表为空、计数为 0、没有位置，也不报错。
    @Test("编译不了的正则没有结果，不报错", arguments: ["sha1", "sha256"])
    func invalidPatterns(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let head = try await Self.makeRegexHistory(in: fixture, objectFormat: objectFormat)
        let history = RepositoryHistory(runner: fixture.runner)

        let conditions: [HistorySearchCondition] = [
            .init(kind: .message, text: "x["),
            .init(kind: .message, text: "\\("),
            .init(kind: .author, text: "x["),
            .init(kind: .committer, text: "\\("),
        ]

        for condition in conditions {
            let query = HistoryQuery(conditions: [condition])
            let page = try await history.page(roots: [head], query: query)

            #expect(page.commits.isEmpty)
            #expect(!page.hasMore)
            #expect(try await history.count(roots: [head], query: query, limit: 100) == 0)
            #expect(try await history.position(of: head, roots: [head], query: query, limit: 100) == nil)
        }

        // 与哈希条件同时使用时同样没有结果
        let hash = HistoryQuery(conditions: [
            .init(kind: .hash, text: String(head.prefix(7))),
            .init(kind: .message, text: "x["),
        ])

        #expect(try await history.page(roots: [head], query: hash).commits.isEmpty)
        #expect(try await history.count(roots: [head], query: hash, limit: 100) == 0)
    }

    /// 能否编译的判断与 Git 相同：Git 报错退出的写法都判为编译不了，其余都能编译；文件与哈希条件不参与。
    @Test("判断正则能否编译与 Git 一致")
    func patternValidity() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        _ = try await fixture.runner.run(["commit", "-q", "--allow-empty", "-m", "start"])

        let invalid = ["x[", "\\(", "a\\)", "a\\{1", "[z-a]", "a\\"]
        let valid = ["a.c", "fix(", "a\\+", "*abc", "中文", "^fix.*$", "a{1"]

        for text in invalid + valid {
            let query = HistoryQuery(conditions: [.init(kind: .message, text: text)])
            let result = try await fixture.runner.execute(
                ["log", "--format=%H"] + query.filterArguments,
                acceptedExitCodes: [0, 128]
            )

            #expect(query.hasInvalidPattern == invalid.contains(text))
            #expect(query.hasInvalidPattern == (result.exitCode == 128))
        }

        // 文件按字面匹配，哈希另行解析，空条件不参与筛选
        #expect(!HistoryQuery(conditions: [.init(kind: .file, text: "x[")]).hasInvalidPattern)
        #expect(!HistoryQuery(conditions: [.init(kind: .hash, text: "x[")]).hasInvalidPattern)
        #expect(!HistoryQuery(conditions: [.init(kind: .message, text: "  ")]).hasInvalidPattern)
    }
}

// MARK: - Helpers

extension HistoryQueryTests {
    /// 2026 年 1 月某一天的正午（UTC）。
    private static func day(_ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: 12)))
    }

    /// 以合并提交为根，按条件读取的提交标题。
    private static func subjects(
        _ history: RepositoryHistory,
        _ commits: Commits,
        _ conditions: [HistorySearchCondition]
    ) async throws -> [String] {
        let query = HistoryQuery(conditions: conditions, calendar: calendar)
        return try await history.page(roots: [commits.merge], query: query).commits.map(\.subject)
    }

    /// 从指定提交起按条件读取的提交标题。
    private static func subjects(
        _ history: RepositoryHistory,
        head: String,
        _ conditions: [HistorySearchCondition]
    ) async throws -> [String] {
        try await history.page(roots: [head], query: HistoryQuery(conditions: conditions)).commits.map(\.subject)
    }

    /// 建立说明含 abc、axc 与 a.c 的一条历史，返回最新的提交；axc 的提交人是 Bob，最新的提交由 Carol 写。
    private static func makeRegexHistory(in fixture: TemporaryRepository, objectFormat: String) async throws -> String {
        try await fixture.initialize(objectFormat: objectFormat)

        _ = try await commit(in: fixture, file: "1.txt", message: "abc search target", day: 1)
        _ = try await commit(
            in: fixture,
            file: "2.txt",
            message: "axc other",
            committer: ("Bob", "bob@example.invalid"),
            day: 2
        )
        _ = try await commit(in: fixture, file: "3.txt", message: "a.c literal target", day: 3)

        return try await commit(
            in: fixture,
            file: "4.txt",
            message: "call(x) done",
            author: "Carol <carol@example.invalid>",
            day: 4
        )
    }

    /// 建立带分支与合并的历史，每个提交的作者、提交人与日期都固定。
    private static func makeHistory(in fixture: TemporaryRepository, objectFormat: String) async throws -> Commits {
        try await fixture.initialize(objectFormat: objectFormat)

        let initial = try await commit(
            in: fixture,
            file: bracketPath,
            message: "初始提交",
            author: "Alice <alice@example.invalid>",
            day: 1
        )
        let fix = try await commit(
            in: fixture,
            file: weirdPath,
            message: "Fix bug *star*",
            author: "李 café 🐈 <li@example.invalid>",
            committer: ("Bob", "bob@example.invalid"),
            day: 2
        )

        _ = try await fixture.runner.run(["switch", "-q", "-c", "side"])
        let side = try await commit(
            in: fixture,
            file: "side.txt",
            message: "side work",
            author: "Carol <carol@example.invalid>",
            day: 3
        )

        _ = try await fixture.runner.run(["switch", "-q", "main"])
        let main = try await commit(in: fixture, file: "main.txt", message: "main work", day: 4)

        _ = try await runner(in: fixture, day: 5).run(["merge", "-q", "--no-ff", "-m", "merge side", "side"])
        let merge = try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")

        return Commits(initial: initial, fix: fix, side: side, main: main, merge: merge)
    }

    /// 写入一个文件并提交，返回新提交的哈希。
    private static func commit(
        in fixture: TemporaryRepository,
        file: String,
        message: String,
        author: String? = nil,
        committer: (name: String, email: String)? = nil,
        day: Int
    ) async throws -> String {
        let url = fixture.directory.appending(path: file)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(message.utf8).write(to: url)

        let runner = runner(in: fixture, day: day, committer: committer)
        _ = try await runner.run(["add", "--", file])
        _ = try await runner.run(["commit", "-q", "-m", message] + (author.map { ["--author=" + $0] } ?? []))

        return try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
    }

    /// 固定作者与提交人日期的隔离执行器；可以另指定提交人。
    private static func runner(
        in fixture: TemporaryRepository,
        day: Int,
        committer: (name: String, email: String)? = nil
    ) -> GitRunner {
        let date = String(format: "2026-01-%02dT10:00:00Z", day)
        var overrides: [Environment.Key: String?] = [
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_SYSTEM": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_PARAMETERS": nil,
            "GIT_CONFIG_COUNT": nil,
            "GIT_ATTR_NOSYSTEM": "1",
            "GIT_AUTHOR_DATE": date,
            "GIT_COMMITTER_DATE": date,
        ]

        if let committer {
            overrides["GIT_COMMITTER_NAME"] = committer.name
            overrides["GIT_COMMITTER_EMAIL"] = committer.email
        }

        return GitRunner(
            location: .local(path: fixture.directory.path),
            environment: .inherit.updating(overrides)
        )
    }
}
