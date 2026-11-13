import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Search

extension FileViewsTests {
    /// 补全写进搜索框的是 “姓名 <邮箱>”：查询的字符按顺序出现即命中，忽略大小写与变音符号，顺序保持传入的第一次出现的顺序，
    /// 不按提交数重排；同名多个邮箱时各成一条，另在前面给一条只写姓名的建议。说明的建议按标题包含查询命中，相同的标题只列一次。
    @Test("贡献者与说明补全的建议")
    func contributorSuggestions() {
        let contributors = [
            FileContributor(name: "Alice Writer", email: "alice@example.invalid", commitCount: 1),
            FileContributor(name: "Test User", email: "test@example.invalid", commitCount: 40),
            FileContributor(name: "李 雷", email: "li@example.invalid", commitCount: 5),
            FileContributor(name: "Zoë Adams", email: "zoe@example.invalid", commitCount: 3),
            FileContributor(name: "李 雷", email: "lei@example.invalid", commitCount: 1),
        ]

        let texts = { (query: String) in ContributorSuggestion.matches(query, in: contributors).map(\.text) }

        // 子序列匹配：tst 命中 Test User；er 时提交少的 Alice Writer 仍在前
        #expect(texts("tst") == ["Test User <test@example.invalid>"])
        #expect(Array(texts("er").prefix(2)) == ["Alice Writer <alice@example.invalid>", "Test User <test@example.invalid>"])

        // 忽略变音符号，空白输入没有建议
        #expect(texts("zoe") == ["Zoë Adams <zoe@example.invalid>"])
        #expect(texts("  ").isEmpty)

        // 同名不同邮箱各成一条，第一条之前插入只写姓名的一条
        let li = ContributorSuggestion.matches("李", in: contributors, group: .committers)

        #expect(li.map(\.text) == ["李 雷", "李 雷 <li@example.invalid>", "李 雷 <lei@example.invalid>"])
        #expect(li.map(\.email) == [nil, "li@example.invalid", "lei@example.invalid"])
        #expect(li.allSatisfy { $0.group == .committers })

        // 说明：包含查询即命中，相同的标题只列一次
        let messages = ContributorSuggestion.messages("FIX", in: ["Fix [x]", "Add", "fix [x]", "Fix [x]"])

        #expect(messages.map(\.text) == ["Fix [x]", "fix [x]"])
        #expect(messages.allSatisfy { $0.group == .messages && !$0.showsAvatar })
    }

    /// 补全的作者与提交人由会话在刷新后于后台读取整个仓库：作者不含只做提交人的人，换文件沿用；
    /// 有新提交后按新的 HEAD 重读，新作者排在最前。
    @Test("补全读取整个仓库的作者与提交人")
    func repositoryContributors() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await Self.initializeRepository(at: location)

        // 两个文件各由一位作者提交，提交人是另一个人
        for (file, author) in [("a.txt", "Author A <a@example.invalid>"), ("b.txt", "Author B <b@example.invalid>")] {
            try Data("one\n".utf8).write(to: directory.appending(path: file))
            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["-c", "user.name=Committer", "commit", "-q", "--author=" + author, "-m", file])
        }

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()

        let suggestions = session.history.suggestions
        let contributors = { (head: String) in await suggestions.contributors(runner: runner, head: head) }

        let first = try #require(session.status?.branch.oid)
        let initial = await contributors(first)

        #expect(initial.authors.map(\.name) == ["Author B", "Author A"])
        #expect(initial.committers.map(\.name) == ["Committer"])

        // HEAD 移动后按新的 HEAD 重读
        try Data("two\n".utf8).write(to: directory.appending(path: "b.txt"))
        _ = try await runner.run(["commit", "-q", "-a", "--author=Author C <c@example.invalid>", "-m", "c"])
        session.refresh(full: true)
        await session.waitForRefresh()

        let second = try #require(session.status?.branch.oid)

        #expect(await contributors(second).authors.map(\.name) == ["Author C", "Author B", "Author A"])
    }
}
