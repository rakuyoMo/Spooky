import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteReferenceManagementTests

/// M7 引用管理的服务器验收，只在显式启用时访问 spooky-test 的独立测试目录；工作区与裸仓库都在 B 上。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteReferenceManagementTests {
    /// 快进、上游、改名、远端分支、标签与远端管理的命令都在 B 上执行，结果与本机一致。
    @Test("服务器上的分支、标签与远端管理", .timeLimit(.minutes(3)))
    func referenceManagement() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            try await Self.branches(runner, bare: fixture.root + "/remote.git")
            try await Self.tagsAndRemotes(runner, bare: fixture.root + "/remote.git")
            await remote.close()
            try await fixture.remove()
        } catch {
            if let error = error as? GitError { Issue.record(Comment(rawValue: error.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}

// MARK: - Steps

extension RemoteReferenceManagementTests {
    /// 快进、上游、改名、远端分支改名与删除跟踪分支。
    private static func branches(_ runner: GitRunner, bare: String) async throws {
        let refs = RepositoryReferences(runner: runner)
        _ = try await runner.run(["init", "-q", "--bare", bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "服务器根提交"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "main"])
        _ = try await runner.run(["branch", "topic"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "topic"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "第二个提交"])
        _ = try await runner.run(["push", "-q", "origin", "HEAD:refs/heads/topic"])

        try await refs.fastForward("refs/heads/topic")
        #expect(try await refs.resolve("refs/heads/topic") == refs.resolve("refs/remotes/origin/topic"))

        try await refs.unsetUpstream(of: "refs/heads/topic")
        try await refs.setUpstream("refs/remotes/origin/topic", for: "refs/heads/topic")
        try await refs.rename("refs/heads/topic", to: "功能/改名")
        try await refs.renameRemoteBranch("topic", on: "origin", to: "功能/远端")
        #expect(try await refs.resolve("refs/remotes/origin/功能/远端") == refs.resolve("HEAD"))

        try await refs.delete("refs/heads/功能/改名", force: false, deletingUpstream: false)
        try await refs.deleteRemoteBranches(["refs/heads/功能/远端"], on: "origin")
    }

    /// 标签的新建、发布与远端删除，远端的增删改名、地址与 refspec。
    private static func tagsAndRemotes(_ runner: GitRunner, bare: String) async throws {
        let tags = RepositoryTags(runner: runner)
        let remotes = RepositoryRemotes(runner: runner)
        try await tags.create(name: "v1/候选", revision: "HEAD", message: "# 说明", sign: false)
        try await tags.publish("v1/候选", to: "origin", skipHooks: true)
        try await tags.deleteRemote(["v1/候选"], on: "origin")
        try await tags.delete(["v1/候选"])

        try await remotes.add(name: "备份", url: bare)
        try await remotes.addRefspec("+refs/tags/*:refs/tags/*", to: "备份", push: false)
        try await remotes.setSkipsFetchAll(true, for: "备份")
        try await remotes.rename("备份", to: "Backup")

        let backup = try #require(try await remotes.configurations().first { $0.name == "Backup" })
        #expect(backup.url == bare && backup.skipsFetchAll)
        #expect(backup.fetchRefspecs.contains("+refs/tags/*:refs/tags/*"))

        try await remotes.remove("Backup")
        #expect(try await remotes.configurations().map(\.name) == ["origin"])
    }
}
