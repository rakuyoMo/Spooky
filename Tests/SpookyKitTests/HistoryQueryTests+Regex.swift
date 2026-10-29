import Foundation
import Testing

@testable import SpookyKit

// MARK: - Regex

extension HistoryQueryTests {
    /// 没有配置时说明、作者与提交人按基本正则匹配，与在 Git 里直接搜索相同。
    @Test("说明、作者与提交人默认按基本正则匹配", arguments: ["sha1", "sha256"])
    func regexConditions(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let head = try await Self.makeRegexHistory(in: fixture, objectFormat: objectFormat)
        let history = RepositoryHistory(runner: fixture.runner)

        // 点号匹配任一字符，转义后只匹配点号本身
        let dot = try await Self.subjects(
            history,
            head: head,
            [.init(kind: .message, text: "A.C")]
        )

        #expect(Set(dot) == ["abc search target", "axc other", "a.c literal target"])

        let escaped = try await Self.subjects(
            history,
            head: head,
            [.init(kind: .message, text: "a\\.c")]
        )

        #expect(escaped == ["a.c literal target"])

        // 作者与提交人同样按正则匹配，行首从姓名开始
        let author = try await Self.subjects(
            history,
            head: head,
            [.init(kind: .author, text: "^C.ROL")]
        )

        #expect(author == ["call(x) done"])

        let committer = try await Self.subjects(
            history,
            head: head,
            [.init(kind: .committer, text: "^bob <.*>$")]
        )

        #expect(committer == ["axc other"])

        // 交给 Git 的参数写明正则的写法并忽略大小写
        let query = HistoryQuery(conditions: [.init(kind: .message, text: "a.c")])
        #expect(query.filterArguments == ["-i", "--basic-regexp", "--grep=a.c"])
        #expect(try await history.patternType() == .basic)
    }

    /// 写法跟随仓库生效的 grep.patternType 与 grep.extendedRegexp：结果与直接执行 git log 相同，计数与列表一致。
    @Test("按仓库配置的写法匹配，列表与计数一致")
    func configuredPatternType() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let head = try await Self.makeRegexHistory(in: fixture, objectFormat: "sha1")
        let history = RepositoryHistory(runner: fixture.runner)

        // 同一个键写多次时以最后一个为准；extendedRegexp 只在 patternType 是 default 或没有配置时生效
        let cases: [(entries: [(String, String)], type: HistoryQuery.PatternType)] = [
            ([], .basic),
            ([("grep.patternType", "extended")], .extended),
            ([("grep.patternType", "fixed")], .fixed),
            ([("grep.patternType", "basic"), ("grep.extendedRegexp", "true")], .basic),
            ([("grep.extendedRegexp", "true")], .extended),
            ([("grep.extendedRegexp", "1k")], .extended),
            ([("grep.patternType", "default"), ("grep.extendedRegexp", "yes")], .extended),
            ([("grep.patternType", "extended"), ("grep.patternType", "default")], .basic),
        ]

        for (entries, type) in cases {
            try await Self.configureGrep(entries, in: fixture)
            #expect(try await history.patternType() == type)

            // 点号与竖线在几种写法下的含义各不相同，两者都与 git log 一致
            for pattern in ["a.c", "abc|axc"] {
                let query = HistoryQuery(conditions: [.init(kind: .message, text: pattern)])
                let listed = try await history.page(roots: [head], query: query)
                    .commits
                    .map(\.subject)

                #expect(listed == (try await Self.logSubjects(pattern, head: head, in: fixture)))
                #expect(
                    try await history.count(roots: [head], query: query, limit: 100) == listed.count
                )
            }
        }

        // 扩展正则里编译不了的条件同样没有结果，不报错
        try await Self.configureGrep([("grep.patternType", "extended")], in: fixture)
        let unbalanced = HistoryQuery(conditions: [.init(kind: .message, text: "l(x")])

        #expect(try await history.page(roots: [head], query: unbalanced).commits.isEmpty)
        #expect(try await history.count(roots: [head], query: unbalanced, limit: 10) == 0)
    }

    /// 配了 Perl 正则时按它匹配；编译不了的条件没有结果、不报错，与其它写法相同。
    @Test(
        "配了 Perl 正则时按它匹配",
        .enabled("需要支持 Perl 正则的 Git") { try await HistoryQueryTests.gitSupportsPerl() }
    )
    func perlPatternType() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        let head = try await Self.makeRegexHistory(in: fixture, objectFormat: "sha1")
        let history = RepositoryHistory(runner: fixture.runner)

        try await Self.configureGrep([("grep.patternType", "perl")], in: fixture)
        #expect(try await history.patternType() == .perl)

        // 先行断言只有 Perl 正则支持
        let lookahead = HistoryQuery(conditions: [.init(kind: .message, text: "AB(?=C)")])
        let listed = try await history.page(roots: [head], query: lookahead).commits.map(\.subject)

        #expect(listed == ["abc search target"])
        #expect(listed == (try await Self.logSubjects("AB(?=C)", head: head, in: fixture)))
        #expect(try await history.count(roots: [head], query: lookahead, limit: 10) == 1)

        for text in ["x(", "a{2,1}"] {
            let query = HistoryQuery(conditions: [.init(kind: .message, text: text)])

            #expect(try await history.page(roots: [head], query: query).commits.isEmpty)
            #expect(try await history.count(roots: [head], query: query, limit: 10) == 0)
            #expect(
                try await history.position(of: head, roots: [head], query: query, limit: 10) == nil
            )
        }
    }

    /// Git 不支持 Perl 正则时，列表与计数都报出 Git 的原文，不当成没有结果。
    @Test("Git 不支持 Perl 正则时照原文报错")
    func perlUnsupported() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        // 替身 Git：配置里写着 Perl 正则，凡是用 Perl 正则的命令都照不支持时的原文失败
        let executable = fixture.directory.appending(path: "no-pcre-git")
        let script = """
            #!/bin/sh
            case " $* " in
            *" config "*)
                printf 'grep.patterntype\\nperl\\000'
                ;;
            *" --perl-regexp "*)
                cat > /dev/null
                echo 'fatal: cannot use Perl-compatible regexes when not compiled with USE_LIBPCRE' >&2
                exit 128
                ;;
            *)
                exit 1
                ;;
            esac

            """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let runner = fixture.runner(at: fixture.directory.path, executable: executable.path)
        let history = RepositoryHistory(runner: runner)
        let root = String(repeating: "a", count: 40)
        let query = HistoryQuery(conditions: [.init(kind: .message, text: "a.c")])

        let error = try await #require(throws: GitError.self) {
            try await history.page(roots: [root], query: query)
        }
        #expect(error.exitCode == 128)
        #expect(error.message.contains("cannot use Perl-compatible regexes"))

        await #expect(throws: GitError.self) {
            try await history.count(roots: [root], query: query, limit: 10)
        }
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
            #expect(
                try await history.position(of: head, roots: [head], query: query, limit: 100) == nil
            )
        }

        // 与哈希条件同时使用时同样没有结果
        let hash = HistoryQuery(conditions: [
            .init(kind: .hash, text: String(head.prefix(7))),
            .init(kind: .message, text: "x["),
        ])

        #expect(try await history.page(roots: [head], query: hash).commits.isEmpty)
        #expect(try await history.count(roots: [head], query: hash, limit: 100) == 0)
    }

    /// 能否编译的判断与 Git 相同：基本与扩展正则里 Git 报错退出的写法都判为编译不了；字面与 Perl 正则不在本机判断。
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
            #expect(query.hasInvalidPattern == invalid.contains(text))
            #expect(try await Self.gitRejects(query, in: fixture) == query.hasInvalidPattern)
        }

        // 扩展正则另有自己的写法，判断同样与 Git 相同
        for text in invalid + valid + ["(x", "a|b", "a{2,1}", "a**"] {
            var query = HistoryQuery(conditions: [.init(kind: .message, text: text)])
            query.patternType = .extended
            #expect(try await Self.gitRejects(query, in: fixture) == query.hasInvalidPattern)
        }

        // 字面匹配总能编译，Perl 正则交给 Git；文件按字面匹配，哈希另行解析，空条件不参与筛选
        for type in [HistoryQuery.PatternType.fixed, .perl] {
            var query = HistoryQuery(conditions: [.init(kind: .message, text: "x[")])
            query.patternType = type
            #expect(!query.hasInvalidPattern)
        }

        #expect(!HistoryQuery(conditions: [.init(kind: .file, text: "x[")]).hasInvalidPattern)
        #expect(!HistoryQuery(conditions: [.init(kind: .hash, text: "x[")]).hasInvalidPattern)
        #expect(!HistoryQuery(conditions: [.init(kind: .message, text: "  ")]).hasInvalidPattern)
    }

    /// 读搜索写法的配置只是查询，越过写队列。
    @Test("读搜索写法的配置登记为只读命令")
    func patternTypeReadIsReadOnly() {
        let read = [
            "config",
            "-z",
            "--type=bool-or-str",
            "--get-regexp",
            "^grep\\.(patterntype|extendedregexp)$",
        ]

        #expect(RepositoryOperationQueue.isReadOnly(read))
        #expect(!RepositoryOperationQueue.isReadOnly(["config", "--local", "grep.patternType", "perl"]))
    }
}

// MARK: - Regex Helpers

extension HistoryQueryTests {
    /// 本机的 Git 能否编译 Perl 正则；不能时跳过依赖它的测试。
    static func gitSupportsPerl() async throws -> Bool {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()

        let result = try await fixture.runner.execute(
            ["rev-list", "--stdin", "--perl-regexp", "--grep=."],
            input: Data(),
            acceptedExitCodes: [0, 128]
        )

        return result.exitCode == 0
    }

    /// 从指定提交起按条件读取的提交标题。
    private static func subjects(
        _ history: RepositoryHistory,
        head: String,
        _ conditions: [HistorySearchCondition]
    ) async throws -> [String] {
        try await history.page(roots: [head], query: HistoryQuery(conditions: conditions))
            .commits
            .map(\.subject)
    }

    /// 不写明正则写法、直接按说明搜索时 git log 列出的标题，即仓库配置下 Git 自己的结果。
    private static func logSubjects(
        _ pattern: String,
        head: String,
        in fixture: TemporaryRepository
    ) async throws -> [String] {
        let output = try await fixture.runner.run(["log", "-i", "--grep=" + pattern, "--format=%s", head])

        return String(decoding: output, as: UTF8.self)
            .split(separator: "\n")
            .map(String.init)
    }

    /// Git 按这个查询的筛选参数编译条件时是否报错退出。
    private static func gitRejects(
        _ query: HistoryQuery,
        in fixture: TemporaryRepository
    ) async throws -> Bool {
        let result = try await fixture.runner.execute(
            ["log", "--format=%H"] + query.filterArguments,
            acceptedExitCodes: [0, 128]
        )

        return result.exitCode == 128
    }

    /// 清掉仓库本地的两项 grep 配置后依次写入；同一个键可以写多次。
    private static func configureGrep(
        _ entries: [(String, String)],
        in fixture: TemporaryRepository
    ) async throws {
        for key in ["grep.patternType", "grep.extendedRegexp"] {
            _ = try await fixture.runner.execute(
                ["config", "--local", "--unset-all", key],
                acceptedExitCodes: [0, 5]
            )
        }

        for (key, value) in entries {
            _ = try await fixture.runner.run(["config", "--local", "--add", key, value])
        }
    }

    /// 建立说明含 abc、axc 与 a.c 的一条历史，返回最新的提交；axc 的提交人是 Bob，最新的提交由 Carol 写。
    private static func makeRegexHistory(
        in fixture: TemporaryRepository,
        objectFormat: String
    ) async throws -> String {
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
}
