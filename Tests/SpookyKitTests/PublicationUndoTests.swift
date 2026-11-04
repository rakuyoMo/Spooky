import Foundation
import Testing

@testable import SpookyKit

// MARK: - PublicationUndoTests

/// 远端引用的撤销：发布的分支与标签在远端删掉，改名的远端分支改回原名；发布时推送的结果记进写操作的记录，
/// 远端被别人改过时租约拒绝，本机的前提不符时不连接远端。
struct PublicationUndoTests {
    /// 撤销发布分支：远端没有这个分支，本机的远端跟踪分支随之删掉；发布前跟踪本地分支、另有一项设置的分支段原样换回。
    @Test("撤销发布分支")
    func undoPublishBranch() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remote = fixture.runner(at: bare)
        let sync = RepositorySync(runner: runner)
        let branch = "功能/发布"

        _ = try await runner.run(["branch", "-q", "--track", branch, "main"])
        _ = try await runner.run(["config", "--local", "branch." + branch + ".rebase", "true"])
        let settings = try await RepositoryUndo(runner: runner).branchSettings()

        let publication = try await sync.publication(of: branch, to: "origin", as: branch, setsUpstream: true)
        _ = try await sync.push(branch: branch, remote: "origin", destination: branch, setUpstream: true)
        #expect(try await Self.references(in: remote).contains("refs/heads/" + branch))
        #expect(try await RepositoryUndo(runner: runner).branchSettings() != settings)

        try await sync.undoPublish(publication)
        #expect(try await Self.references(in: remote) == ["refs/heads/main"])
        #expect(try await RepositoryUndo(runner: runner).branchSettings() == settings)
        #expect(try await BranchManagementTests.reference("refs/remotes/origin/" + branch, in: .init(runner: runner)) == nil)
    }

    /// 发布分支与标签时推送的逐条结果记进当前写操作的记录：远端原来没有时是新建，已有且快进是更新，已指向同一对象是已是最新。
    @Test("推送的结果记进写操作的记录")
    func pushResults() async throws {
        let (fixture, _) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let sync = RepositorySync(runner: runner)
        let tags = RepositoryTags(runner: runner)
        let log = PushLog()

        _ = try await runner.run(["branch", "-q", "功能/发布"])
        _ = try await runner.run(["tag", "v1"])

        try await PushLog.$current.withValue(log) {
            _ = try await sync.push(branch: "功能/发布", remote: "origin", destination: "功能/发布", setUpstream: true)
            try await tags.publish("v1", to: "origin")
        }

        #expect(log.result(of: "refs/heads/功能/发布", on: "origin") == .created)
        #expect(log.result(of: "refs/tags/v1", on: "origin") == .created)
        #expect(log.result(of: "refs/heads/功能/发布", on: "fork") == nil)

        // 再推一次已是最新；提交之后再推是快进，同一个引用取最近一次推送的结果
        try await PushLog.$current.withValue(log) {
            _ = try await sync.push(branch: "功能/发布", remote: "origin", destination: "功能/发布", setUpstream: false)
            try await tags.publish("v1", to: "origin")
        }

        #expect(log.result(of: "refs/heads/功能/发布", on: "origin") == .upToDate)
        #expect(log.result(of: "refs/tags/v1", on: "origin") == .upToDate)

        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "其它"])
        _ = try await runner.run(["branch", "-q", "-f", "功能/发布", "main"])

        try await PushLog.$current.withValue(log) {
            _ = try await sync.push(branch: "功能/发布", remote: "origin", destination: "功能/发布", setUpstream: false)
        }

        #expect(log.result(of: "refs/heads/功能/发布", on: "origin") == .updated)
    }

    /// 另一个克隆把发布的分支推进一个提交之后，撤销被租约拒绝：远端分支与本机的跟踪设置都不变。
    /// 本机的前提不符时拒绝撤销，不连接远端：发布后跟踪设置以外的分支设置被改过，改名后的远端跟踪分支已不在，远端已被删掉。
    @Test("远端分支被推进或本机前提不符时拒绝撤销")
    func rejectedUndo() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remote = fixture.runner(at: bare)
        let sync = RepositorySync(runner: runner)

        _ = try await runner.run(["branch", "-q", "feature"])
        let publication = try await sync.publication(of: "feature", to: "origin", as: "feature", setsUpstream: true)
        _ = try await sync.push(branch: "feature", remote: "origin", destination: "feature", setUpstream: true)

        // 另一个克隆在 feature 上提交并推送
        let clone = fixture.directory.appendingPathComponent("wt").path
        _ = try await runner.run(["clone", "-q", "--branch", "feature", "--", bare, clone])
        let other = fixture.runner(at: clone)
        _ = try await other.run([
            "-c", "user.name=Other", "-c", "user.email=other@example.invalid",
            "commit", "-q", "--allow-empty", "-m", "其它",
        ])
        _ = try await other.run(["push", "-q", "origin", "feature"])

        let pushed = try await Self.object("refs/heads/feature", in: remote)
        let settings = try await RepositoryUndo(runner: runner).branchSettings()

        await #expect(throws: GitError.self) { try await sync.undoPublish(publication) }
        #expect(try await Self.object("refs/heads/feature", in: remote) == pushed)
        #expect(try await RepositoryUndo(runner: runner).branchSettings() == settings)

        // 被拒绝的撤销没有改动本机；发布后又给 feature 加了一项设置
        _ = try await runner.run(["config", "--local", "branch.feature.rebase", "true"])
        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await sync.undoPublish(publication) }
        #expect(try await Self.references(in: remote).contains("refs/heads/feature"))

        // 改名后的远端跟踪分支已不在，原名字的还在
        await #expect(throws: RepositoryUndoError.repositoryChanged) {
            try await RepositoryReferences(runner: runner)
                .undoRenameRemoteBranch("feature", on: "origin", to: "missing")
        }

        // 远端已被删掉
        _ = try await runner.run(["remote", "remove", "origin"])
        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await sync.undoPublish(publication) }

        await #expect(throws: RepositoryUndoError.repositoryChanged) {
            try await RepositoryTags(runner: runner)
                .undoPublish("v1", on: "origin", object: publication.commit)
        }

        #expect(try await Self.references(in: remote).contains("refs/heads/feature"))
    }

    /// 撤销发布附注标签：远端没有这个标签；远端标签被改指别的对象后，撤销被租约拒绝。
    @Test("撤销发布标签")
    func undoPublishTag() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remote = fixture.runner(at: bare)
        let tags = RepositoryTags(runner: runner)

        try await tags.create(name: "发布/v1", revision: "main", message: "说明", sign: false)
        let object = try await tags.publicationLease(of: "发布/v1")
        #expect(try await Self.object("refs/tags/发布/v1", in: remote) == nil)

        try await tags.publish("发布/v1", to: "origin")
        #expect(try await Self.object("refs/tags/发布/v1", in: remote) == object)

        try await tags.undoPublish("发布/v1", on: "origin", object: object)
        #expect(try await Self.object("refs/tags/发布/v1", in: remote) == nil)

        // 再发布后远端标签被改指 main 的提交
        try await tags.publish("发布/v1", to: "origin")
        _ = try await runner.run(["push", "-q", "--force", "origin", "main:refs/tags/发布/v1"])

        await #expect(throws: GitError.self) { try await tags.undoPublish("发布/v1", on: "origin", object: object) }
        #expect(try await Self.object("refs/tags/发布/v1", in: remote) != nil)
    }

    /// 撤销重命名远端分支：远端只剩原名字，指向原来的提交。
    @Test("撤销重命名远端分支")
    func undoRenameRemoteBranch() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remote = fixture.runner(at: bare)
        let refs = RepositoryReferences(runner: runner)
        let original = try await Self.object("refs/heads/main", in: remote)

        try await refs.renameRemoteBranch("main", on: "origin", to: "功能/改名")
        #expect(try await Self.references(in: remote) == ["refs/heads/功能/改名"])

        try await refs.undoRenameRemoteBranch("main", on: "origin", to: "功能/改名")
        #expect(try await Self.references(in: remote) == ["refs/heads/main"])
        #expect(try await Self.object("refs/heads/main", in: remote) == original)
    }
}

// MARK: - Helpers

extension PublicationUndoTests {
    /// 裸仓库里全部分支与标签的引用名，按名称排列。
    ///
    /// - Parameter remote: 裸仓库的执行器。
    static func references(in remote: GitRunner) async throws -> [String] {
        let output = try await remote.run(["for-each-ref", "--format=%(refname)", "refs/heads", "refs/tags"])
        return String(decoding: output, as: UTF8.self).split(separator: "\n").map(String.init)
    }

    /// 裸仓库里一个引用指向的对象；没有这个引用时为 nil。
    ///
    /// - Parameter remote: 裸仓库的执行器。
    static func object(_ reference: String, in remote: GitRunner) async throws -> String? {
        let output = try await remote.run(["for-each-ref", "--format=%(objectname)", reference])
        let value = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
        return value.isEmpty ? nil : value
    }
}
