import Foundation
import Subprocess
import Testing

@testable import SpookyKit

/// 真实 Git 验证文件历史、Blame 与原文的命令、解析和 Unicode 路径。
struct RepositoryFileViewsTests {
    /// 文件名同时含有中文、空格、制表符、换行、引号、反斜杠与通配符。
    private static let path = "目录 [*]/你好 \t\n'\\.txt"

    /// 文件历史只包含修改过该文件的提交；翻页、计数与贡献者筛选都由 Git 在仓库所在的机器上完成。
    @Test("文件历史的分页、计数与贡献者筛选", arguments: ["sha1", "sha256"])
    func history(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let file = fixture.directory.appending(path: Self.path)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // 三次修改目标文件，其间夹一次只改动其它文件的提交
        try Data("one\n".utf8).write(to: file)
        try await commit(in: fixture, message: "add", author: "Alice", date: "2020-01-01T00:00:00Z")

        try Data("other\n".utf8).write(to: fixture.directory.appending(path: "other.txt"))
        try await commit(in: fixture, message: "unrelated", author: "Bob", date: "2021-01-01T00:00:00Z")

        try Data("one\ntwo\n".utf8).write(to: file)
        try await commit(in: fixture, message: "edit", author: "Bob [x]", date: "2022-01-01T00:00:00Z")

        try Data("one\ntwo\nthree\n".utf8).write(to: file)
        try await commit(
            in: fixture,
            message: "applied",
            author: "Alice",
            committer: "Carol",
            date: "2023-01-01T00:00:00Z"
        )

        let views = RepositoryFileViews(runner: fixture.runner)
        let head = try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")

        // 翻页沿固定起点进行，只出现修改过该文件的提交
        let first = try await views.page(of: Self.path, from: head, limit: 2)
        #expect(first.commits.map(\.subject) == ["applied", "edit"])
        #expect(first.hasMore)
        #expect(first.commits.first?.id.count == (objectFormat == "sha1" ? 40 : 64))

        let second = try await views.page(of: Self.path, from: head, offset: 2, limit: 2)
        #expect(second.commits.map(\.subject) == ["add"])
        #expect(!second.hasMore)
        #expect(try await views.count(of: Self.path, from: head) == 3)

        // 按条件读取第一页的标题
        let subjects: (FileHistoryFilter) async throws -> [String] = {
            try await views.page(of: Self.path, from: head, filter: $0).commits.map(\.subject)
        }

        // 贡献者按字面子串匹配并忽略大小写，方括号不会被当成正则
        let bob = FileHistoryFilter(scope: .author, text: " bob [X ")
        #expect(try await subjects(bob) == ["edit"])
        #expect(try await views.count(of: Self.path, from: head, filter: bob) == 1)

        let carol = FileHistoryFilter(scope: .committer, text: "carol")
        #expect(try await subjects(carol) == ["applied"])

        // 版本范围改变的是起点，不会变成作者或提交人条件
        #expect(FileHistoryFilter(scope: .revision, text: "HEAD~1").arguments.isEmpty)

        // 贡献者按提交数排列，作者与提交人不同时只统计作者
        let contributors = try await views.contributors(of: Self.path, at: head)
        #expect(contributors.map(\.name) == ["Alice", "Bob [x]"])
        #expect(contributors.first?.commitCount == 2)
        #expect(contributors.first?.email == "alice@example.invalid")
    }

    /// Blame 的段、提交元信息与原文按 porcelain 协议解析，哈希长度随仓库算法变化。
    @Test("Blame 的段、元信息、特殊路径与无结尾换行", arguments: ["sha1", "sha256"])
    func blame(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let file = fixture.directory.appending(path: Self.path)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // 最后一行没有换行，第二次提交只改中间一行
        try Data("a\nb\nc".utf8).write(to: file)
        try await commit(in: fixture, message: "第一版", author: "李 café", date: "2020-01-01T00:00:00Z")
        let refs = RepositoryReferences(runner: fixture.runner)
        let root = try await refs.resolve("HEAD")

        try Data("a\n\tB\r\nc".utf8).write(to: file)
        try await commit(in: fixture, message: "改第二行", author: "Bob", date: "2021-01-01T00:00:00Z")
        let head = try await refs.resolve("HEAD")

        let views = RepositoryFileViews(runner: fixture.runner)
        let blame = try await views.blame(Self.path, at: head)

        // 中间一行把同一提交的两段分开，原文保留制表符与回车
        #expect(blame.lines == ["a", "\tB\r", "c"])
        #expect(blame.groups.map(\.commitID) == [root, head, root])
        #expect(blame.groups.map(\.firstLine) == [1, 2, 3])
        #expect(blame.groups.last?.originalLine == 3)
        #expect(blame.commits[head]?.author == "Bob")
        #expect(blame.commits[head]?.summary == "改第二行")
        #expect(blame.commits[root]?.author == "李 café")
        #expect(blame.commits[root]?.authorEmail == "李 café".lowercased() + "@example.invalid")
        #expect(blame.commits[root]?.authorDate == ISO8601DateFormatter().date(from: "2020-01-01T00:00:00Z"))
        #expect(blame.commits[head]?.id.count == (objectFormat == "sha1" ? 40 : 64))

        // 早期版本的追溯只有一段
        let early = try await views.blame(Self.path, at: root)
        #expect(early.groups == [BlameGroup(commitID: root, firstLine: 1, lineCount: 3, originalLine: 1)])
    }

    /// 原文按对象哈希读取；版本中没有的文件返回 nil，由界面说明不能显示的原因。
    @Test("原文读取、版本中缺失的文件与整棵树的条目")
    func contents() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let file = fixture.directory.appending(path: Self.path)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("text\n".utf8).write(to: file)
        try Data([0, 1, 2, 255]).write(to: fixture.directory.appending(path: "binary"))
        try await commit(in: fixture, message: "root", author: "Alice", date: "2020-01-01T00:00:00Z")

        // 提交之后才出现的文件不在这个版本里
        try Data("new\n".utf8).write(to: fixture.directory.appending(path: "untracked.txt"))

        let views = RepositoryFileViews(runner: fixture.runner)
        let head = try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")

        let entry = try #require(try await views.entry(at: Self.path, in: head))
        #expect(entry.mode == "100644")
        #expect(!entry.isSubmodule)
        #expect(try await views.contents(of: entry) == Data("text\n".utf8))

        let binary = try #require(try await views.entry(at: "binary", in: head))
        #expect(try await views.contents(of: binary) == Data([0, 1, 2, 255]))

        #expect(try await views.entry(at: "untracked.txt", in: head) == nil)
        #expect(try await views.storedEntry(for: "untracked.txt", in: head) == nil)
        #expect(try await views.files(in: head).map(\.path).sorted() == ["binary", Self.path].sorted())
    }

    /// macOS 上的 Git 默认把命令行路径转成 NFC，树中以 NFD 存储的文件也必须能查到历史、Blame、原文与补丁。
    @Test("NFD 文件名的历史、Blame、原文与补丁")
    func decomposedPaths() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let decomposed = "caf\u{65}\u{301}/n\u{303}o.txt"
        let composed = decomposed.precomposedStringWithCanonicalMapping
        #expect(Array(decomposed.utf8) != Array(composed.utf8))

        // 直接把 NFD 路径写进索引，模拟在 Linux 上提交、或关闭 precomposeunicode 时加入的文件
        for (index, content) in ["one\n", "one\ntwo\n"].enumerated() {
            let blob = try await runner.run(["hash-object", "-w", "--stdin"], input: Data(content.utf8))
            let id = String(decoding: blob, as: UTF8.self).trimmingCharacters(in: .newlines)
            _ = try await runner.run(
                ["update-index", "--add", "-z", "--index-info"],
                input: Data("100644 blob \(id)\t\(decomposed)\0".utf8)
            )

            // 工作区里没有这个文件，直接提交索引，不能先把工作区的状态加入索引
            _ = try await runner.run(["commit", "-q", "-m", "版本 \(index)"])
        }

        let views = RepositoryFileViews(runner: runner)
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")

        // 按 NFC 请求时找到树中存储的 NFD 形式，后续查询都使用它
        let entry = try #require(try await views.storedEntry(for: composed, in: head))
        #expect(Array(entry.path.utf8) == Array(decomposed.utf8))
        #expect(try await views.contents(of: entry) == Data("one\ntwo\n".utf8))
        #expect(try await views.page(of: entry.path, from: head).commits.count == 2)
        #expect(try await views.blame(entry.path, at: head).lines == ["one", "two"])

        let diff = try await views.diff(of: entry.path, in: head)
        #expect(!(diff.diff?.files.first?.hunks.isEmpty ?? true))

        // 提交详情的补丁使用变更集给出的原样路径，同样不被转成 NFC
        let change = try #require(try await RepositoryHistory(runner: runner).changes(in: head).first)
        let commitDiff = try await RepositoryHistory(runner: runner).diff(in: head, file: change)
        #expect(!(commitDiff.diff?.files.first?.hunks.isEmpty ?? true))
    }

    /// 输出错位时拒绝显示不完整的结果，不能把残缺的追溯当成文件原文。
    @Test("Blame、ls-tree 与 shortlog 的格式错误")
    func malformedOutput() throws {
        let hash = String(repeating: "a", count: 40)
        let metadata = [
            "author A", "author-mail <a@e>", "author-time 1", "author-tz +0000",
            "committer C", "committer-mail <c@e>", "committer-time 2", "committer-tz +0000", "summary s",
        ]
        .joined(separator: "\n")

        // 完整的一段可以解析，元信息里的邮箱去掉尖括号
        let valid = try FileBlame.parse(Data("\(hash) 1 1 1\n\(metadata)\n\tline\n".utf8))
        #expect(valid.commits[hash]?.authorEmail == "a@e")
        #expect(valid.lines == ["line"])
        #expect(try FileBlame.parse(Data()).lines.isEmpty)

        let broken = [
            "zz 1 1 1\n\(metadata)\n\tline\n",
            "\(hash) 1 1 1\n\(metadata)\n",
            "\(hash) 1 1 1\nauthor A\n\tline\n",
            "\(hash) 1 1 2\n\(metadata)\n\tline\n",
            "\(hash) 1 2 1\n\(metadata)\n\tline\n",
            "\(hash) 1 1 1\n\(metadata)\n\tline",
            "\tline\n",
        ]

        for output in broken {
            #expect(throws: RepositoryReadError.malformedOutput("blame")) {
                try FileBlame.parse(Data(output.utf8))
            }
        }

        // 树条目要有六位八进制模式、已知类型、合法哈希与制表符后的路径
        let entry = "100644 blob \(hash)\tdir/a\tb.txt\0"
        #expect(try TreeEntry.parse(Data(entry.utf8)).first?.path == "dir/a\tb.txt")

        for output in [
            "100644 blob \(hash)\tpath",
            "10064 blob \(hash)\tpath\0",
            "100644 tree \(hash)\tpath\0",
            "100644 blob \(hash) path\0",
        ] {
            #expect(throws: RepositoryReadError.malformedOutput("ls-tree")) {
                try TreeEntry.parse(Data(output.utf8))
            }
        }

        // 姓名可以含有尖括号，邮箱取行尾的最后一对
        let contributors = try FileContributor.parse(Data("     2\tLi <x> Lei <l@e>\n     1\tBob <>\n".utf8))
        #expect(contributors == [
            FileContributor(name: "Li <x> Lei", email: "l@e", commitCount: 2),
            FileContributor(name: "Bob", email: "", commitCount: 1),
        ])

        for output in ["two\tName <e>\n", "     2 Name <e>\n", "     2\tName\n"] {
            #expect(throws: RepositoryReadError.malformedOutput("shortlog")) {
                try FileContributor.parse(Data(output.utf8))
            }
        }
    }

    /// 文件视图的查询都不写入仓库，可以与写操作并行，不占用仓库写队列。
    @Test("文件视图的查询登记为只读")
    func readOnlyCommands() {
        #expect(RepositoryOperationQueue.isReadOnly(RepositoryFileViews.storedPathOptions + ["blame", "--porcelain"]))
        #expect(RepositoryOperationQueue.isReadOnly(["ls-tree", "-r", "-z"]))
        #expect(RepositoryOperationQueue.isReadOnly(RepositoryHistory.logOptions + ["shortlog", "-n", "-s"]))
    }

    /// 以指定身份与时间提交全部改动，作者与提交人可以不同。
    private func commit(
        in fixture: TemporaryRepository,
        message: String,
        author: String,
        committer: String = "Spooky Test",
        date: String
    ) async throws {
        let runner = GitRunner(
            location: .local(path: fixture.directory.path),
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_AUTHOR_NAME": author,
                "GIT_AUTHOR_EMAIL": author.lowercased() + "@example.invalid",
                "GIT_AUTHOR_DATE": date,
                "GIT_COMMITTER_NAME": committer,
                "GIT_COMMITTER_EMAIL": committer.lowercased() + "@example.invalid",
                "GIT_COMMITTER_DATE": date,
            ])
        )

        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", message])
    }
}
