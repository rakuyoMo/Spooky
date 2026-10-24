import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Search

extension FileViewsTests {
    /// 补全写进搜索框的是 “姓名 <邮箱>”：带空格与中文的姓名整条替换，按字面子串筛选时只命中这个人；
    /// 同名多个邮箱时另给一条只写姓名的建议，选它能匹配这个人的全部提交。
    @Test("贡献者补全的建议")
    func contributorSuggestions() {
        let contributors = [
            FileContributor(name: "李 雷", email: "li@example.invalid", commitCount: 5),
            FileContributor(name: "Zoë Adams", email: "zoe@example.invalid", commitCount: 3),
            FileContributor(name: "李 雷", email: "lei@example.invalid", commitCount: 1),
        ]

        // 查询忽略大小写与变音符号，只按姓名匹配
        #expect(ContributorSuggestion.matches("zoe", in: contributors).map(\.text) == [
            "Zoë Adams <zoe@example.invalid>",
        ])
        #expect(ContributorSuggestion.matches("example", in: contributors).isEmpty)
        #expect(ContributorSuggestion.matches("  ", in: contributors).isEmpty)

        // 同名的第一条之前插入只写姓名的一条，其余保持提交数的顺序
        let li = ContributorSuggestion.matches("李", in: contributors)
        #expect(li.map(\.text) == ["李 雷", "李 雷 <li@example.invalid>", "李 雷 <lei@example.invalid>"])
        #expect(li.map(\.email) == [nil, "li@example.invalid", "lei@example.invalid"])
    }

    /// 补全列出整个仓库的作者（不是提交人），换文件仍沿用；有新提交后重读，新作者随之出现。
    @Test("文件历史补全读取整个仓库的作者")
    func repositoryAuthors() async throws {
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
        await session.refreshTask?.value

        session.showFileHistory("a.txt")
        try await Self.wait { session.fileHistory.totalCount != nil }
        #expect(try await session.fileHistory.authors().map(\.name) == ["Author A", "Author B"])

        // HEAD 移动后重读
        try Data("two\n".utf8).write(to: directory.appending(path: "b.txt"))
        _ = try await runner.run(["commit", "-q", "-a", "--author=Author C <c@example.invalid>", "-m", "c"])
        session.refresh(full: true)
        await session.refreshTask?.value

        session.showFileHistory("b.txt")
        try await Self.wait { session.fileHistory.totalCount != nil }
        #expect(try await session.fileHistory.authors().map(\.name) == ["Author A", "Author B", "Author C"])
    }
}
