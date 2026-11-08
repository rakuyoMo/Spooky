import Foundation
import Testing

@testable import SpookyKit

/// 分支、标签、远端名、refspec 与远端地址在写入前按 Git 规则校验：注入、控制字符与歧义名字一律拒绝。
struct ReferenceNamesTests {
    /// 每类名字都会混进的非法写法：选项形式、控制字符、引用表达式、空白、通配符、`.lock` 结尾与完整对象哈希。
    private static let invalidNames = [
        "", "-x", "--upload-pack=touch", "a\u{1}b", "a\nb", "a\u{7f}", "main@{1}", "a..b", "a b", "a:b",
        "a~1", "a^", "a?", "a*", "a[", "a\\b", "x.lock", "x/", "/x", "HEAD",
        String(repeating: "a", count: 40), String(repeating: "0", count: 64),
    ]

    /// 分支与标签名：斜杠分层、中文、点号与引号都是合法名字，非法写法逐一被拒绝；
    /// 远端名可以含斜杠与点，但不能是 “.”、“..”，也不能含会改变命令行配置键的 “=”；
    /// refspec 的强制前缀、通配符成对，push 允许空来源表示删除，fetch 必须有目标；
    /// 远端地址只拒绝会被当作选项、带控制字符或首尾空白的写法，各种协议与本机路径都放行。
    @Test("分支、标签、远端名、refspec 与远端地址的合法与非法写法")
    func validation() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let refs = RepositoryReferences(runner: fixture.runner)

        // 分支与标签名
        for name in ["feature/v1.2/功能", "release-1.0", "it's", "a\"b", String(repeating: "a", count: 39)] {
            try await refs.validate(name: name)
            try await refs.validate(tag: name)
        }

        for name in Self.invalidNames {
            await #expect(throws: ReferenceError.self, "分支名应被拒绝：\(name.debugDescription)") {
                try await refs.validate(name: name)
            }

            await #expect(throws: ReferenceError.self, "标签名应被拒绝：\(name.debugDescription)") {
                try await refs.validate(tag: name)
            }
        }

        // 远端名
        for name in ["origin", "up.stream", "team/fork", "上游"] {
            try await refs.validate(remote: name)
        }

        for name in Self.invalidNames + [".", "..", "a=b", "x.url=evil"] {
            await #expect(throws: ReferenceError.self, "远端名应被拒绝：\(name.debugDescription)") {
                try await refs.validate(remote: name)
            }
        }

        // fetch 与 push 的 refspec
        let validFetch = [
            "+refs/heads/*:refs/remotes/origin/*",
            "refs/heads/main:refs/remotes/origin/main",
            "refs/tags/*:refs/tags/*",
        ]

        for spec in validFetch {
            try await refs.validate(refspec: spec, push: false)
        }

        for spec in ["HEAD:refs/for/main", ":refs/heads/old", "refs/heads/main", "+refs/heads/*:refs/heads/*"] {
            try await refs.validate(refspec: spec, push: true)
        }

        let invalidFetch = [
            "", ":", "+", ":refs/heads/x", "refs/heads/*:refs/remotes/o/x", "a:b:c", "-x:refs/heads/x",
            "refs/heads/a b:refs/heads/a", "refs/heads/*/*:refs/remotes/o/*/*", "refs/heads/x:refs/heads/y\n",
            "refs/heads/x@{1}:refs/heads/x", "refs/heads/x:-y",
        ]

        for spec in invalidFetch {
            await #expect(throws: ReferenceError.self, "fetch refspec 应被拒绝：\(spec.debugDescription)") {
                try await refs.validate(refspec: spec, push: false)
            }
        }

        for spec in [":", "--force:refs/heads/x", "HEAD:refs/for/*"] {
            await #expect(throws: ReferenceError.self, "push refspec 应被拒绝：\(spec.debugDescription)") {
                try await refs.validate(refspec: spec, push: true)
            }
        }

        // 远端地址
        for url in ["git@github.com:owner/repo.git", "https://example.com/a b.git", "../remote.git", "/srv/仓库.git"] {
            try RepositoryReferences.validate(url: url)
        }

        for url in ["", " https://example.com/x.git", "-oProxyCommand=touch", "ssh://x\n-oProxyCommand", "a\u{0}b"] {
            #expect(throws: ReferenceError.self, "地址应被拒绝：\(url.debugDescription)") {
                try RepositoryReferences.validate(url: url)
            }
        }
    }

    /// 新建与改名本地分支的输入规范化：空白与 `~ : ? * [` 换成 “-”，`^ \` 删掉，连续的 “.” “/” 合并，
    /// “@{” 与末尾的 “.lock” 删掉；开头的 “-” 留给校验说明，开头的 “/” “.” 与段首的 “.” 删掉，中文与版本号原样保留。
    @Test(
        "本地分支名的输入规范化",
        arguments: [
            ("feature x\ty", "feature-x-y"),
            ("a~b:c?d*e[f", "a-b-c-d-e-f"),
            ("a^b\\c", "abc"),
            ("-topic", "-topic"),
            ("a..b//c", "a.b/c"),
            ("main@{1}", "main1}"),
            ("topic.lock", "topic"),
            ("x.lock.lock", "x"),
            ("/.hidden/.b", "hidden/b"),
            ("功能/v1.2", "功能/v1.2"),
        ]
    )
    func branchNameNormalization(input: String, expected: String) {
        #expect(RepositoryReferences.normalizedBranchName(input) == expected)
    }

    /// 分支名不合法时带上原因：选项形式、控制字符、“@{”、HEAD 与完整哈希在执行前拒绝，不带 Git 结果；
    /// 其余由 `check-ref-format --branch` 以 128 拒绝，带上原因与 Git 原文。
    /// “@” 与工作区里已有的文件名都是合法分支名；`main/x` 通过校验，由建分支的 Git 命令拒绝。
    @Test("分支名不合法的原因、Git 的拒绝结果与操作时的检查")
    func branchNameProblems() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()

        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)

        // 执行前拒绝的写法
        let early: [(String, ReferenceNameProblem)] = [
            ("-x", .leadingHyphen),
            ("a\u{1}b", .character),
            ("main@{1}", .sequence),
            ("HEAD", .ambiguous),
            (String(repeating: "a", count: 40), .ambiguous),
        ]

        for (name, expected) in early {
            let error = try await #require(throws: ReferenceError.self) {
                try await refs.validate(name: name)
            }

            guard case .invalidName(_, let problem, let output) = error else {
                Issue.record("应说明名称不合法：\(error)")
                continue
            }

            #expect(problem == expected, "原因：\(name.debugDescription)")
            #expect(output == nil)
        }

        // Git 拒绝的写法
        let rejected: [(String, ReferenceNameProblem)] = [
            ("a/.b", .component),
            ("a b", .character),
            ("a..b", .sequence),
            ("x/", .boundary),
            ("x.lock", .component),
        ]

        for (name, expected) in rejected {
            let error = try await #require(throws: ReferenceError.self) {
                try await refs.validate(name: name)
            }

            guard case .invalidName(_, let problem, let output?) = error else {
                Issue.record("应带上 Git 的结果：\(error)")
                continue
            }

            #expect(problem == expected, "原因：\(name.debugDescription)")
            #expect(output.exitCode == 128)
            #expect(String(decoding: output.standardError, as: UTF8.self).contains("is not a valid branch name"))
        }

        // 与工作区文件同名的分支建好后检出的是分支，文件不受影响
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        try Data("text\n".utf8).write(to: fixture.directory.appendingPathComponent("docs"))

        try await refs.validate(name: "@")
        try await refs.create(name: "docs", startingAt: "HEAD", track: false, checkout: true)

        #expect(try await runner.status().branch.head == "docs")
        #expect(try String(contentsOf: fixture.directory.appendingPathComponent("docs"), encoding: .utf8) == "text\n")

        // 与已有分支的层级冲突通过校验，由 Git 在建分支时拒绝
        try await refs.validate(name: "main/x")

        let conflict = try await #require(throws: GitError.self) {
            try await refs.create(name: "main/x", startingAt: "HEAD", track: false, checkout: false)
        }

        #expect(conflict.exitCode == 128)
        #expect(conflict.message.contains("cannot lock ref"))
    }

    /// 网页地址：SSH、scp 写法与 git 协议换成 HTTPS 并去掉端口，HTTP(S) 保留端口，用户名、口令与 .git 后缀都去掉；
    /// 本机路径、file 协议、不认识的协议与没有仓库路径的地址都换算不出网页地址。
    @Test("远端地址换算网页地址与换算不出的地址")
    func webURLs() {
        let cases = [
            ("git@github.com:owner/repo.git", "https://github.com/owner/repo"),
            ("github.com:owner/repo", "https://github.com/owner/repo"),
            ("ssh://git@example.com:2222/team/project.git", "https://example.com/team/project"),
            ("git+ssh://example.com/team/project.git/", "https://example.com/team/project"),
            ("git://example.com/project.git", "https://example.com/project"),
            ("https://user:secret@example.com:8443/group/sub/repo.git", "https://example.com:8443/group/sub/repo"),
            ("http://example.com/repo", "http://example.com/repo"),
            ("https://example.com/仓库.git", "https://example.com/%E4%BB%93%E5%BA%93"),
            ("git@example.com:/srv/git/repo.git", "https://example.com/srv/git/repo"),
        ]

        for (remote, expected) in cases {
            #expect(RemoteConfiguration.webURL(for: remote)?.absoluteString == expected, "\(remote)")
        }

        // 换算不出网页地址的远端地址
        let remotes = [
            "/srv/git/repo.git", "../remote.git", "file:///srv/repo.git", "ftp://example.com/x.git",
            "https://example.com/", "git@example.com:", "C/x:y",
        ]

        for remote in remotes {
            #expect(RemoteConfiguration.webURL(for: remote) == nil, "不应换算出网页地址：\(remote)")
        }
    }

    /// 普通删除的报错里逐行列出未合并的分支；新旧 Git 的大小写不同，名字可以含引号、斜杠与中文。
    @Test("从删除报错中取出未合并分支")
    func unmergedBranches() {
        let message = """
            error: The branch 'feature/功能' is not fully merged.
            If you are sure you want to delete it, run 'git branch -D feature/功能'.
            error: the branch 'it's' is not fully merged
            hint: If you are sure you want to delete it, run 'git branch -D it's'
            Deleted branch merged (was 1234567).
            """

        #expect(RepositoryReferences.unmergedBranches(in: message) == ["feature/功能", "it's"])
        #expect(RepositoryReferences.unmergedBranches(in: "error: branch 'x' not found.").isEmpty)
    }

    /// 远端配置按远端名分组：名字可含点与斜杠，多值地址保留顺序，没有值的布尔键为真，格式错误整体失败。
    @Test("远端配置的解析")
    func remoteConfigurations() throws {
        let records = [
            "remote.up.stream.url\nhttps://a.example/x.git",
            "remote.up.stream.url\nhttps://b.example/x.git",
            "remote.up.stream.fetch\n+refs/heads/*:refs/remotes/up.stream/*",
            "remote.team/fork.pushurl\ngit@c.example:fork.git",
            "remote.team/fork.push\nrefs/heads/main:refs/for/main",
            "remote.team/fork.skipfetchall",
            "remote.off.skipfetchall\nfalse",
            "remote.off.proxy\nhttp://proxy",
        ]
        let data = Data((records.joined(separator: "\u{0}") + "\u{0}").utf8)
        let remotes = try RemoteConfiguration.parse(data)

        #expect(remotes.map(\.name) == ["off", "team/fork", "up.stream"])
        #expect(remotes[2].urls == ["https://a.example/x.git", "https://b.example/x.git"])
        #expect(remotes[2].fetchRefspecs == ["+refs/heads/*:refs/remotes/up.stream/*"])
        #expect(remotes[1].effectivePushURL == "git@c.example:fork.git")
        #expect(remotes[1].pushRefspecs == ["refs/heads/main:refs/for/main"])
        #expect(remotes[1].skipsFetchAll)
        #expect(!remotes[0].skipsFetchAll)
        #expect(remotes[0].url == nil)

        #expect(throws: RepositoryReadError.self) {
            try RemoteConfiguration.parse(Data("remote\nx\u{0}".utf8))
        }
        #expect(try RemoteConfiguration.parse(Data()).isEmpty)
    }
}
