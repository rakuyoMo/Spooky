import Foundation
import Testing

@testable import SpookyKit

// MARK: - BranchManagementTests

/// 快进、上游、改名与删除都经仓库写队列执行；远端是测试目录里的裸仓库。
struct BranchManagementTests {
    /// 只落后于上游的非当前分支可以快进；当前分支、无上游、已分叉与在工作树检出的分支都说明原因且不改动引用。
    /// 设置与取消上游只改跟踪设置：分支配置段里的置顶保留；上游可以是远端分支或本地分支。
    @Test("快进到上游、不能快进的原因与设置、取消上游")
    func fastForwardAndUpstream() async throws {
        let (fixture, _) = try await Self.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)

        _ = try await runner.run(["branch", "topic"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "topic"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "second"])
        _ = try await runner.run(["push", "-q", "origin", "HEAD:refs/heads/topic"])

        // 分支落后一个提交、没有自己的提交，快进后与上游相同；再快进一次什么都不做
        try await refs.fastForward("refs/heads/topic")

        #expect(try await refs.resolve("refs/heads/topic") == refs.resolve("refs/remotes/origin/topic"))

        try await refs.fastForward("refs/heads/topic")

        // 当前分支与没有上游的分支
        let current = try await #require(throws: ReferenceError.self) {
            try await refs.fastForward("refs/heads/main")
        }

        switch current {
        case .currentBranch("main"):
            break

        default:
            Issue.record("应说明是当前分支：\(current)")
        }

        _ = try await runner.run(["branch", "lonely", "HEAD~1"])

        let missing = try await #require(throws: GitError.self) {
            try await refs.fastForward("refs/heads/lonely")
        }

        #expect(missing.category == .noUpstream)

        // 已分叉的分支保持原样
        _ = try await runner.run(["switch", "-q", "-c", "side", "HEAD~1"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "side"])
        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["branch", "-q", "--set-upstream-to=origin/topic", "side"])

        let side = try await refs.resolve("refs/heads/side")

        let diverged = try await #require(throws: ReferenceError.self) {
            try await refs.fastForward("refs/heads/side")
        }

        switch diverged {
        case .diverged(branch: "side", upstream: "refs/remotes/origin/topic"):
            break

        default:
            Issue.record("应说明分支已分叉：\(diverged)")
        }

        #expect(try await refs.resolve("refs/heads/side") == side)

        // 在另一个工作树检出的分支由 Git 拒绝更新，那个工作树不受影响
        _ = try await runner.run(["branch", "-q", "--track", "checked", "origin/topic"])
        _ = try await runner.run(["branch", "-q", "-f", "checked", "HEAD~1"])

        let worktree = fixture.directory.appendingPathComponent("wt").path
        _ = try await runner.run(["worktree", "add", "-q", worktree, "checked"])

        let before = try await refs.resolve("refs/heads/checked")

        await #expect(throws: GitError.self) {
            try await refs.fastForward("refs/heads/checked")
        }

        #expect(try await refs.resolve("refs/heads/checked") == before)

        // 设置、取消与改设上游
        let branch = "refs/heads/功能/分支"
        _ = try await runner.run(["branch", "功能/分支"])
        try await refs.setPinned(true, branches: [branch])

        try await refs.setUpstream("refs/remotes/origin/topic", for: branch)

        #expect(try await Self.reference(branch, in: refs)?.upstream == "refs/remotes/origin/topic")

        try await refs.unsetUpstream(of: branch)

        #expect(try await Self.reference(branch, in: refs)?.upstream == nil)
        #expect(try await refs.metadata()[branch]?.isPinned ?? false)

        try await refs.setUpstream("refs/heads/main", for: branch)

        #expect(try await Self.reference(branch, in: refs)?.upstream == "refs/heads/main")

        // 上游不能是标签，也不能是分支自身
        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await refs.setUpstream("refs/tags/v1", for: branch)
        }

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await refs.setUpstream(branch, for: branch)
        }
    }

    /// 新建分支时置顶与父分支和分支一起写入；改名带走分支自己的父分支与置顶，以它为父分支的分支改指新名字；
    /// 重名与非法名字不改动任何分支。
    @Test("新建分支同时置顶并设置父分支，重命名本地分支并更新父分支关系")
    func createAndRename() async throws {
        let fixture = try await Self.committedRepository(objectFormat: "sha256")
        defer { fixture.remove() }

        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)

        try await refs.create(
            name: "feature/旧",
            startingAt: "refs/heads/main",
            track: false,
            checkout: false,
            pinned: true,
            parent: "refs/heads/main"
        )

        #expect(
            try await refs.metadata()["refs/heads/feature/旧"]
                == BranchMetadata(isPinned: true, parent: "refs/heads/main")
        )

        _ = try await runner.run(["branch", "child"])
        try await refs.setParent("refs/heads/feature/旧", of: "refs/heads/child")

        try await refs.rename("refs/heads/feature/旧", to: "feature/新-名")

        let renamed = "refs/heads/feature/新-名"
        let names = try await refs.snapshot().references.map(\.id)

        #expect(names.contains(renamed) && !names.contains("refs/heads/feature/旧"))

        let metadata = try await refs.metadata()

        #expect(metadata[renamed] == BranchMetadata(isPinned: true, parent: "refs/heads/main"))
        #expect(metadata["refs/heads/child"]?.parent == renamed)

        // 重名由 Git 拒绝，非法名字在执行前拒绝
        await #expect(throws: GitError.self) {
            try await refs.rename(renamed, to: "child")
        }

        await #expect(throws: ReferenceError.self) {
            try await refs.rename(renamed, to: "bad..name")
        }

        #expect(try await refs.snapshot().references.contains { $0.id == renamed })
    }

    /// 先建分支再检出：检出成功时 HEAD 在新分支上，置顶一起写入；本地修改挡住检出时分支已经建好、HEAD 不变、
    /// 本地修改原样保留，错误说明已创建、未检出，并带着 Git 的退出码与原文。
    @Test("新建分支后检出，检出被本地修改挡住时分支保留")
    func createThenCheckOut() async throws {
        let fixture = try await Self.committedRepository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        let file = fixture.directory.appendingPathComponent("a.txt")

        // 两个提交里 a.txt 内容不同，HEAD 在第二个提交上
        try Data("one\n".utf8).write(to: file)
        _ = try await runner.run(["add", "a.txt"])
        _ = try await runner.run(["commit", "-q", "-m", "one"])
        try Data("two\n".utf8).write(to: file)
        _ = try await runner.run(["commit", "-q", "-am", "two"])

        // 检出成功
        try await refs.createThenCheckOut(name: "topic", startingAt: "HEAD", track: false, pinned: true)

        #expect(try await runner.status().branch.head == "topic")
        #expect(try await refs.metadata()["refs/heads/topic"] == BranchMetadata(isPinned: true, parent: nil))

        // 本地修改挡住检出
        try Data("local\n".utf8).write(to: file)

        let error = try await #require(throws: ReferenceError.self) {
            try await refs.createThenCheckOut(name: "old", startingAt: "HEAD~1", track: false)
        }

        guard case .createdBranchCheckoutFailed("old", let checkout) = error else {
            Issue.record("应说明已创建、未检出：\(error)")
            return
        }

        #expect(checkout.category == .localChanges)
        #expect(checkout.exitCode == 1)
        #expect(checkout.message.contains("would be overwritten by checkout"))
        #expect(try await refs.resolve("refs/heads/old") == refs.resolve("HEAD~1"))
        #expect(try await runner.status().branch.head == "topic")
        #expect(try String(contentsOf: file, encoding: .utf8) == "local\n")
    }

    /// 未合并的分支普通删除失败并列出名字，能删的照删；强制删除成功；同时删除跟踪的远端分支。
    /// 远端分支改名保留原提交；新名字已存在时推送被拒，原分支仍在；删除远端分支一次推送完成。
    @Test("删除本地分支与跟踪的远端分支，重命名与删除远端分支")
    func deleteAndRenameRemoteBranches() async throws {
        let (fixture, bare) = try await Self.repository(objectFormat: "sha1")
        defer { fixture.remove() }

        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        let remote = fixture.runner(at: bare)

        // 普通删除遇到未合并的分支时失败，能删的照删
        _ = try await runner.run(["branch", "merged"])
        _ = try await runner.run(["switch", "-q", "-c", "it's/未合并"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "unmerged"])
        _ = try await runner.run(["switch", "-q", "main"])

        let unmerged = try await #require(throws: ReferenceError.self) {
            try await refs.delete(["refs/heads/it's/未合并", "refs/heads/merged"])
        }

        switch unmerged {
        case .unmergedBranches(let names, let git):
            #expect(names == ["refs/heads/it's/未合并"])
            #expect(git.category == .branchNotMerged)

        default:
            Issue.record("应列出未合并的分支：\(unmerged)")
        }

        let remaining = try await refs.snapshot().references.map(\.id)

        #expect(remaining.contains("refs/heads/it's/未合并") && !remaining.contains("refs/heads/merged"))

        try await refs.delete(["refs/heads/it's/未合并"], force: true)

        #expect(try await Self.reference("refs/heads/it's/未合并", in: refs) == nil)

        // 删除本地分支时一并删除它跟踪的远端分支，本机的远端跟踪分支随推送结果移除
        _ = try await runner.run(["branch", "published"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "published"])
        try await refs.delete("refs/heads/published", force: false, deletingUpstream: true)

        let pushed = try await remote.run(["for-each-ref", "--format=%(refname)"])

        #expect(!String(decoding: pushed, as: UTF8.self).contains("refs/heads/published"))
        #expect(try await Self.reference("refs/remotes/origin/published", in: refs) == nil)

        // 重命名远端分支
        _ = try await runner.run([
            "push",
            "-q",
            "origin",
            "HEAD:refs/heads/old/名",
            "HEAD:refs/heads/taken",
        ])

        _ = try await runner.run(["fetch", "-q", "origin"])

        let object = try await refs.resolve("refs/remotes/origin/old/名")

        try await refs.renameRemoteBranch("old/名", on: "origin", to: "new/名")

        #expect(try await RepositoryReferences(runner: remote).resolve("refs/heads/new/名") == object)
        #expect(try await Self.reference("refs/remotes/origin/new/名", in: refs) != nil)
        #expect(try await Self.reference("refs/remotes/origin/old/名", in: refs) == nil)

        // 本机已知的同名远端分支直接拒绝，即使它指向同一个提交
        await #expect(throws: ReferenceError.self) {
            try await refs.renameRemoteBranch("new/名", on: "origin", to: "taken")
        }

        // 本机还不知道的同名远端分支由 lease 拦下，原分支仍在
        _ = try await runner.run(["commit", "--allow-empty", "-m", "hidden"])
        _ = try await runner.run(["push", "-q", "origin", "HEAD:refs/heads/hidden"])
        _ = try await runner.run(["update-ref", "-d", "refs/remotes/origin/hidden"])

        let rejected = try await #require(throws: GitError.self) {
            try await refs.renameRemoteBranch("new/名", on: "origin", to: "hidden")
        }

        #expect(rejected.category == .pushRejected)
        #expect(try await RepositoryReferences(runner: remote).resolve("refs/heads/new/名") == object)

        // 一次推送删除多个远端分支
        try await refs.deleteRemoteBranches(
            ["refs/heads/new/名", "refs/heads/taken", "refs/heads/hidden"],
            on: "origin"
        )

        let heads = try await remote.run(["for-each-ref", "--format=%(refname)"])

        #expect(String(decoding: heads, as: UTF8.self).split(separator: "\n") == ["refs/heads/main"])
    }
}

// MARK: - Helpers

extension BranchManagementTests {
    /// 只有一个空的根提交、没有远端的工作区；用不到远端的测试用它。
    static func committedRepository(objectFormat: String) async throws -> TemporaryRepository {
        let fixture = try TemporaryRepository()
        try await fixture.initialize(objectFormat: objectFormat)
        _ = try await fixture.runner.run(["commit", "--allow-empty", "-m", "root"])
        return fixture
    }

    /// 带一个已推送 main 的裸仓库远端的工作区；裸仓库放在工作区里并列入排除规则。
    static func repository(objectFormat: String) async throws -> (TemporaryRepository, bare: String) {
        let fixture = try await committedRepository(objectFormat: objectFormat)
        let runner = fixture.runner
        let bare = fixture.directory.appendingPathComponent("remote.git").path

        try FileManager.default.createDirectory(
            at: fixture.directory.appendingPathComponent(".git/info"),
            withIntermediateDirectories: true
        )
        try Data("remote.git/\nwt/\n".utf8).write(to: fixture.directory.appendingPathComponent(".git/info/exclude"))

        _ = try await runner.run(["init", "-q", "--bare", "--object-format=" + objectFormat, bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        _ = try await runner.run(["push", "-q", "-u", "origin", "main"])
        return (fixture, bare)
    }

    /// 快照里指定完整引用名的引用；不存在时为 nil。
    static func reference(_ id: String, in refs: RepositoryReferences) async throws -> RepositoryReference? {
        try await refs.snapshot().references.first { $0.id == id }
    }
}
