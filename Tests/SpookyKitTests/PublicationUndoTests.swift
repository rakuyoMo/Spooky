import Foundation
import Testing

@testable import SpookyKit

// MARK: - PublicationUndoTests

/// 远端引用的撤销：发布的分支与标签在远端删掉，改名的远端分支改回原名；远端原来就有时不记，
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

        let publication = try #require(
            try await sync.publication(of: branch, to: "origin", as: branch, setsUpstream: true)
        )
        _ = try await sync.push(branch: branch, remote: "origin", destination: branch, setUpstream: true)
        #expect(try await Self.references(in: remote).contains("refs/heads/" + branch))
        #expect(try await RepositoryUndo(runner: runner).branchSettings() != settings)

        try await sync.undoPublish(publication)
        #expect(try await Self.references(in: remote) == ["refs/heads/main"])
        #expect(try await RepositoryUndo(runner: runner).branchSettings() == settings)
        #expect(try await BranchManagementTests.reference("refs/remotes/origin/" + branch, in: .init(runner: runner)) == nil)
    }

    /// 远端原来就有同名的分支或标签时，发布不新建引用，撤销不能删掉它，准备时不给出撤销内容。
    @Test("远端已有同名引用时不记")
    func existingOnRemote() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remote = fixture.runner(at: bare)

        // 远端另有名字更长、结尾相同的引用，列远端时会一起列出，不能当作同名
        _ = try await runner.run(["tag", "v1"])
        _ = try await runner.run([
            "push", "-q", "origin", "main:refs/heads/x/refs/heads/feature", "v1:refs/tags/x/refs/tags/v1",
        ])

        let sync = RepositorySync(runner: runner)
        let tags = RepositoryTags(runner: runner)
        #expect(try await sync.publication(of: "main", to: "origin", as: "main", setsUpstream: false) == nil)
        #expect(try await sync.publication(of: "main", to: "origin", as: "feature", setsUpstream: false) != nil)
        #expect(try await tags.publicationLease(of: "v1", on: "origin") != nil)

        _ = try await runner.run(["push", "-q", "origin", "v1"])
        #expect(try await tags.publicationLease(of: "v1", on: "origin") == nil)
        #expect(try await Self.references(in: remote).count == 4)
    }

    /// 另一个克隆把发布的分支推进一个提交之后，撤销被租约拒绝：远端分支与本机的跟踪设置都不变。
    @Test("远端分支被推进后拒绝撤销发布")
    func leaseRejected() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remote = fixture.runner(at: bare)
        let sync = RepositorySync(runner: runner)

        _ = try await runner.run(["branch", "-q", "feature"])
        let publication = try #require(
            try await sync.publication(of: "feature", to: "origin", as: "feature", setsUpstream: true)
        )
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
        let object = try #require(try await tags.publicationLease(of: "发布/v1", on: "origin"))
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

    /// 本机的前提不符时拒绝撤销，不连接远端：远端已被删掉，发布后跟踪设置以外的分支设置被改过，改名后的远端跟踪分支已不在。
    @Test("前提不符时拒绝撤销远端引用")
    func changedRepository() async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let remote = fixture.runner(at: bare)
        let sync = RepositorySync(runner: runner)

        _ = try await runner.run(["branch", "-q", "feature"])
        let publication = try #require(
            try await sync.publication(of: "feature", to: "origin", as: "feature", setsUpstream: true)
        )
        _ = try await sync.push(branch: "feature", remote: "origin", destination: "feature", setUpstream: true)

        // 发布后又给 feature 加了一项设置
        _ = try await runner.run(["config", "--local", "branch.feature.rebase", "true"])
        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await sync.undoPublish(publication) }
        #expect(try await Self.references(in: remote).contains("refs/heads/feature"))

        // 改名后的远端跟踪分支已不在，原名字的还在
        await #expect(throws: RepositoryUndoError.repositoryChanged) {
            try await RepositoryReferences(runner: runner).undoRenameRemoteBranch("feature", on: "origin", to: "missing")
        }

        // 远端已被删掉
        _ = try await runner.run(["remote", "remove", "origin"])
        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await sync.undoPublish(publication) }
        await #expect(throws: RepositoryUndoError.repositoryChanged) {
            try await RepositoryTags(runner: runner).undoPublish("v1", on: "origin", object: publication.commit)
        }
        #expect(try await Self.references(in: remote).contains("refs/heads/feature"))
    }

    /// `ls-remote` 的每一行都要是对象哈希、制表符与完整引用名，否则按格式错误抛出。
    @Test("远端引用列表的格式错误")
    func malformedListing() throws {
        let line = String(repeating: "a", count: 40) + "\trefs/heads/功能 分支\n"
        #expect(try RepositoryReferences.listedReferences(in: Data(line.utf8)) == ["refs/heads/功能 分支"])
        #expect(try RepositoryReferences.listedReferences(in: Data()).isEmpty)

        for output in ["refs/heads/main\n", String(repeating: "a", count: 40) + " refs/heads/main\n", "zz\trefs/heads/main\n"] {
            #expect(throws: RepositoryReadError.malformedOutput("ls-remote")) {
                try RepositoryReferences.listedReferences(in: Data(output.utf8))
            }
        }
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
