import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryReflogTests

/// 引用日志的解析、按引用分页、按说明搜索与恢复分支的真实 Git 结果。
///
/// 夹具由 Git 2.54 在忽略系统与用户配置、固定提交身份与时间的临时仓库中生成，从新到旧依次是：
/// 摘取、重置、合并、检出、提交、检出与首次提交；分支名是中文的 `功能/分支`，
/// 一次提交的标题带双引号、单引号、通配符与方括号，正文有两行。
struct RepositoryReflogTests {
    /// 每条记录的时间来自选择器，命令名与配色类别取自说明，提交的完整信息与列表相同。
    @Test("reflog 夹具：时间、说明、命令名与提交")
    func parseFixture() throws {
        let entries = try ReflogEntry.parse(try fixture("reflog-sha1.bin"), offset: 0)
        #expect(entries.map(\.id) == Array(0 ..< 7))
        #expect(entries.map(\.command) == ["cherry-pick", "reset", "merge", "checkout", "commit", "checkout", "commit"])
        #expect(entries.map(\.category) == [.commit, .move, .merge, .move, .commit, .move, .commit])

        // 每一步相隔一分钟，最早的是首次提交
        #expect(entries.last?.date == Date(timeIntervalSince1970: 1_767_323_220))
        #expect(entries.first?.date == Date(timeIntervalSince1970: 1_767_323_580))

        // 说明原样保留引号、通配符与中文分支名
        #expect(entries[0].message == "cherry-pick: subject \"quoted\" 'single' *.txt [x]")
        #expect(entries[3].message == "checkout: moving from 功能/分支 to main")
        #expect(entries[6].message == "commit (initial): 初始提交")

        // 提交的正文保留换行；同一提交出现在多条记录里时靠位置区分
        #expect(entries[4].commit.message.contains("body line 1\nline 2"))
        #expect(entries[1].commit.id == entries[3].commit.id)
        #expect(entries[2].commit.parents.count == 2)
        #expect(entries.allSatisfy { $0.commit.id.count == 40 })
    }

    /// 哈希长度随仓库算法变化，SHA-256 仓库同样可以解析；分页的位置从偏移量开始编号。
    @Test("reflog 夹具：SHA-256 仓库与偏移量")
    func parseSHA256() throws {
        let entries = try ReflogEntry.parse(try fixture("reflog-sha256.bin"), offset: 100)
        #expect(entries.count == 7)
        #expect(entries.map(\.id) == Array(100 ..< 107))
        #expect(entries.allSatisfy { $0.commit.id.count == 64 && $0.commit.tree.count == 64 })
    }

    /// 截断、字段数不对、选择器不是时间形式或提交字段错位时拒绝整页，不会显示错位的记录。
    @Test("reflog 格式错误")
    func malformedOutput() throws {
        let hash = String(repeating: "a", count: 40)
        let commit = [hash, hash, "", "A", "a@x", "1", "C", "c@x", "2", "message"].joined(separator: "\0")
        let valid = "HEAD@{100}\0commit: x\0" + commit + "\0"
        #expect(try ReflogEntry.parse(Data(valid.utf8), offset: 0).first?.date == Date(timeIntervalSince1970: 100))
        #expect(try ReflogEntry.parse(Data(), offset: 0).isEmpty)

        let broken = [
            String(valid.dropLast()),
            "HEAD@{100}\0" + commit + "\0",
            "HEAD@{0}x\0commit: x\0" + commit + "\0",
            "HEAD@{soon}\0commit: x\0" + commit + "\0",
            "HEAD\0commit: x\0" + commit + "\0",
            "HEAD@{100}\0commit: x\0" + commit.replacingOccurrences(of: hash + "\0" + hash, with: "HEAD\0" + hash) + "\0",
        ]

        for output in broken {
            #expect(throws: RepositoryReadError.self) {
                try ReflogEntry.parse(Data(output.utf8), offset: 0)
            }
        }
    }

    /// HEAD 与分支各有自己的记录；分页额外读一条判断是否还有下一页，位置延续上一页。
    @Test("按引用分页读取")
    func pages() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let reflog = RepositoryReflog(runner: repository.runner)

        let head = try await reflog.page(of: "HEAD", limit: 2)
        #expect(head.entries.map(\.command) == ["checkout", "commit"])
        #expect(head.hasMore)

        let next = try await reflog.page(of: "HEAD", offset: 2, limit: 2)
        #expect(next.entries.map(\.id) == [2, 3])
        #expect(!next.hasMore)

        // 分支的记录只有它自己的移动
        let branch = try await reflog.page(of: "refs/heads/功能/分支")
        #expect(branch.entries.map(\.message) == ["commit: 功能 [x] *", "branch: Created from HEAD"])
    }

    /// 搜索只看说明，不区分大小写，方括号与星号按字面匹配。
    @Test("按说明搜索")
    func search() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let reflog = RepositoryReflog(runner: repository.runner)

        let moving = try await reflog.page(of: "HEAD", matching: "MOVING FROM")
        #expect(moving.entries.map(\.command) == ["checkout", "checkout"])

        let literal = try await reflog.page(of: "refs/heads/功能/分支", matching: " [x] *")
        #expect(literal.entries.count == 1)

        let none = try await reflog.page(of: "HEAD", matching: "rebase")
        #expect(none.entries.isEmpty)
    }

    /// 分支移回记录里的提交；分支已经不在读取时的位置上时 Git 拒绝，分支保持原样。
    @Test("把分支恢复到某条记录")
    func restoreBranch() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let runner = repository.runner
        let reflog = RepositoryReflog(runner: runner)
        let entries = try await reflog.page(of: "refs/heads/功能/分支").entries
        let tip = entries[0].commit.id
        let start = entries[1].commit.id

        await #expect(throws: GitError.self) {
            try await reflog.restore("refs/heads/功能/分支", to: start, expected: start)
        }

        try await reflog.restore("refs/heads/功能/分支", to: start, expected: tip)
        #expect(try await revision("refs/heads/功能/分支", in: runner) == start)

        // 恢复本身也写进分支的引用日志
        let after = try await reflog.page(of: "refs/heads/功能/分支").entries
        #expect(after.first?.command == "reflog")
    }

    /// 只接受 HEAD 与本地分支，选项和修订表达式在执行 Git 之前就被拒绝。
    @Test("拒绝非法引用与分页参数")
    func invalidQueries() async throws {
        let reflog = RepositoryReflog(runner: GitRunner(location: .local(path: "/nonexistent")))

        for reference in ["--all", "main", "refs/remotes/origin/main", "refs/heads/a..b", "refs/heads/x@{1}"] {
            await #expect(throws: RepositoryReadError.invalidQuery) {
                try await reflog.page(of: reference)
            }
        }

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await reflog.page(of: "HEAD", limit: 0)
        }

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await reflog.restore("HEAD", to: "abcd", expected: "abcd")
        }
    }
}

// MARK: - Helpers

extension RepositoryReflogTests {
    /// 主分支一个提交，从它新建中文分支并提交一次，再检出回主分支。
    private func makeRepository() async throws -> TemporaryRepository {
        let repository = try TemporaryRepository()
        try await repository.initialize()
        let runner = repository.runner

        try Data("base\n".utf8).write(to: repository.directory.appending(path: "a b.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])
        _ = try await runner.run(["checkout", "-q", "-b", "功能/分支"])
        try Data("feature\n".utf8).write(to: repository.directory.appending(path: "a b.txt"))
        _ = try await runner.run(["commit", "-q", "-a", "-m", "功能 [x] *"])
        _ = try await runner.run(["checkout", "-q", "main"])
        return repository
    }

    /// 引用当前指向的提交。
    private func revision(_ reference: String, in runner: GitRunner) async throws -> String {
        String(decoding: try await runner.run(["rev-parse", reference]), as: UTF8.self)
            .trimmingCharacters(in: .newlines)
    }

    /// 读取测试资源中的固定 Git 输出。
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
