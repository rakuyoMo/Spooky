import Foundation
import Testing

@testable import SpookyKit

/// 仓库管理详情区的概况读取、描述与身份写入，以及本机新建仓库。
struct RepositorySummaryTests {
    /// 未出生的分支有名字但没有提交；本地身份与模板外的描述文件都来自这个仓库自己。
    @Test("空仓库的概况")
    func emptyRepository() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        try await temporary.initialize()

        let summary = try await temporary.runner.repositorySummary()

        #expect(summary.branch == "main")
        #expect(summary.lastCommit == nil)
        #expect(summary.committer == RepositorySummary.Identity(name: "Spooky Test", email: "spooky@example.invalid"))
        #expect(summary.hasRepositoryIdentity)

        // 初始化时没有模板，description 文件不存在
        #expect(summary.description == nil)
        #expect(summary.remotes.isEmpty)
    }

    /// 最后一次提交读出标题与时间，分离 HEAD 时没有分支名，远端按名字列出。
    @Test("提交、分离 HEAD 与远端")
    func commitsAndRemotes() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        try await temporary.initialize()

        let runner = temporary.runner
        _ = try await runner.run(["commit", "--allow-empty", "-q", "-m", "标题 “引号” <tag> & 'x'"])
        _ = try await runner.run(["remote", "add", "origin", "https://example.invalid/team/project.git"])
        _ = try await runner.run(["checkout", "-q", "--detach"])

        let summary = try await runner.repositorySummary()
        let commit = try #require(summary.lastCommit)

        #expect(summary.branch == nil)
        #expect(commit.subject == "标题 “引号” <tag> & 'x'")
        #expect(abs(commit.date.timeIntervalSinceNow) < 600)
        #expect(summary.remotes.map(\.name) == ["origin"])
        #expect(summary.remotes.first?.webURL?.absoluteString == "https://example.invalid/team/project")
    }

    /// 描述写进 Git 给出的 description 路径，读回原文；仓库路径含空格、中文与引号。
    @Test("写入并读回描述")
    func description() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        try await temporary.initialize()

        try await temporary.runner.setRepositoryDescription("说明 “Spooky” 'test'")

        let file = temporary.directory.appending(path: ".git/description")
        #expect(try String(contentsOf: file, encoding: .utf8) == "说明 “Spooky” 'test'")
        #expect(try await temporary.runner.repositoryDescription() == "说明 “Spooky” 'test'")
    }

    /// 清除仓库身份只删本地配置的两项，再清一次不报错。
    @Test("清除仓库身份")
    func clearIdentity() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        try await temporary.initialize()

        let operations = WorkingCopyOperations(runner: temporary.runner)
        try await operations.clearIdentity()
        try await operations.clearIdentity()

        let summary = try await temporary.runner.repositorySummary()
        #expect(!summary.hasRepositoryIdentity)
        #expect(summary.committer?.name != "Spooky Test")

        // 签名设置留在本地配置里
        let signing = try await temporary.runner.run(["config", "--local", "--get", "commit.gpgSign"])
        #expect(String(decoding: signing, as: UTF8.self) == "false\n")
    }

    /// 解析失败的提交记录抛错，身份里的姓名可以带空格与引号。
    @Test("解析最后一次提交与提交人")
    func parsing() throws {
        #expect(try RepositorySummary.commit(from: Data()) == nil)
        #expect(throws: RepositoryReadError.self) { try RepositorySummary.commit(from: Data("标题".utf8)) }

        let identity = RepositorySummary.identity(from: Data("Ann “A” O'Neil <ann@example.invalid> 1700000000 +0800\n".utf8))
        #expect(identity == RepositorySummary.Identity(name: "Ann “A” O'Neil", email: "ann@example.invalid"))
        #expect(RepositorySummary.identity(from: Data("broken".utf8)) == nil)
    }

    /// 新增的两种读取越过写队列，同一子命令的写入仍然排队。
    @Test("当前分支与本地配置读取的调度")
    func scheduling() {
        #expect(RepositoryOperationQueue.isReadOnly(["branch", "--show-current"]))
        #expect(!RepositoryOperationQueue.isReadOnly(["branch", "-D", "topic"]))
        #expect(RepositoryOperationQueue.isReadOnly(["config", "-z", "--local", "--get-regexp", "^user\\."]))
        #expect(!RepositoryOperationQueue.isReadOnly(["config", "--local", "--unset-all", "user.name"]))
    }
}
