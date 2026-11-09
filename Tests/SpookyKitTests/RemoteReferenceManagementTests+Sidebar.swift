import Foundation
import Testing

@testable import SpookyKit

// MARK: - Sidebar

extension RemoteReferenceManagementTests {
    /// 侧边栏发起的写入在 B 上执行：同名跟踪的检出、工作树占用与检出失败，父分支与归档，
    /// 以及非 HEAD 分支的安全强推与单分支推送；每一步之后都重新读取 HEAD、分支提交与上游。
    @Test("服务器上的同名跟踪、父分支、归档与指定分支的推送")
    func sidebarWrites() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            try await Self.trackingCheckout(runner, fixture: fixture)
            try await Self.parentAndArchive(runner)
            try await Self.branchPushes(runner, fixture: fixture)
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

// MARK: - Sidebar Steps

extension RemoteReferenceManagementTests {
    /// 检出同名本地分支并改设上游时保留本地提交；被别的工作树占用时不写上游；
    /// 本地修改挡住检出时上游已改、HEAD 与本地修改不变；未跟踪文件始终留在原处。
    private static func trackingCheckout(_ runner: GitRunner, fixture: RemoteFixture) async throws {
        let refs = RepositoryReferences(runner: runner)
        let bare = fixture.root + "/remote.git"

        _ = try await runner.run(["init", "-q", "--bare", bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        try await write("main\n", to: "a.txt", in: fixture)
        _ = try await runner.run(["add", "a.txt"])
        _ = try await runner.run(["commit", "-q", "-m", "main"])
        _ = try await runner.run(["push", "-q", "-u", "origin", "main"])

        // 远端的同名分支停在 main 上，本地分支各有自己的提交
        for name in ["other", "busy", "blocked"] {
            _ = try await runner.run(["push", "-q", "origin", "main:refs/heads/" + name])
            _ = try await runner.run(["switch", "-q", "-c", name, "main"])
            try await write(name + "\n", to: "a.txt", in: fixture)
            _ = try await runner.run(["commit", "-q", "-am", name])
        }

        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["fetch", "-q", "origin"])
        _ = try await runner.run(["branch", "-q", "--set-upstream-to=origin/main", "other"])
        try await write("keep\n", to: "untracked.txt", in: fixture)

        // 检出并把上游从 origin/main 改为 origin/other，本地提交不被远端分支覆盖
        let other = try await refs.resolve("refs/heads/other")

        try await refs.checkout("refs/heads/other", tracking: "refs/remotes/origin/other")

        #expect(try await runner.status().branch.head == "other")
        #expect(try await refs.resolve("refs/heads/other") == other)
        #expect(try await upstream(of: "other", runner) == "refs/remotes/origin/other")

        // 在 B 上别的工作树检出的分支：说明那个工作树，不写上游，HEAD 不变
        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["worktree", "add", "-q", fixture.root + "/wt", "busy"])

        let occupied = try await #require(throws: ReferenceError.self) {
            try await refs.checkout("refs/heads/busy", tracking: "refs/remotes/origin/busy")
        }

        guard case .checkedOutInWorktree("busy", let path) = occupied else {
            Issue.record("应说明分支在别的工作树检出：\(occupied)")
            return
        }

        #expect(path.hasSuffix("/wt"))
        #expect(try await upstream(of: "busy", runner) == nil)
        #expect(try await runner.status().branch.head == "main")

        // 本地修改挡住检出：上游已经改了，HEAD、分支的提交与本地修改都不变
        let blocked = try await refs.resolve("refs/heads/blocked")
        try await write("local\n", to: "a.txt", in: fixture)

        let failure = try await #require(throws: ReferenceError.self) {
            try await refs.checkout("refs/heads/blocked", tracking: "refs/remotes/origin/blocked")
        }

        guard case .trackingCheckoutFailed("blocked", "refs/remotes/origin/blocked", let checkout) = failure else {
            Issue.record("应说明上游已设好、检出失败：\(failure)")
            return
        }

        #expect(checkout.category == .localChanges)
        #expect(try await upstream(of: "blocked", runner) == "refs/remotes/origin/blocked")
        #expect(try await refs.resolve("refs/heads/blocked") == blocked)
        #expect(try await runner.status().branch.head == "main")
        #expect(try await read("a.txt", in: fixture) == "local\n")
        #expect(try await read("untracked.txt", in: fixture) == "keep\n")

        _ = try await runner.run(["checkout", "-q", "--", "a.txt"])
    }

    /// 父分支的设置与移除、归档与取消归档只改分支配置，HEAD 与各分支的提交不动。
    private static func parentAndArchive(_ runner: GitRunner) async throws {
        let refs = RepositoryReferences(runner: runner)
        let tips = try await runner.run(["for-each-ref", "--format=%(refname) %(objectname)", "refs/heads"])

        try await refs.setParent("refs/heads/main", of: "refs/heads/other")
        #expect(try await refs.metadata()["refs/heads/other"]?.parent == "refs/heads/main")

        try await refs.setParent(nil, of: "refs/heads/other")
        #expect(try await refs.metadata()["refs/heads/other"]?.parent == nil)

        // 当前分支 main 与非 HEAD 分支一起归档，再取消归档
        try await refs.setArchived(true, branches: ["refs/heads/main", "refs/heads/other"])
        let archived = try await refs.metadata()

        #expect(archived["refs/heads/main"]?.isArchived ?? false)
        #expect(archived["refs/heads/other"]?.isArchived ?? false)

        try await refs.setArchived(false, branches: ["refs/heads/main", "refs/heads/other"])
        let restored = try await refs.metadata()

        #expect(!(restored["refs/heads/main"]?.isArchived ?? false))
        #expect(!(restored["refs/heads/other"]?.isArchived ?? false))
        #expect(try await runner.run(["for-each-ref", "--format=%(refname) %(objectname)", "refs/heads"]) == tips)
        #expect(try await runner.status().branch.head == "main")
    }

    /// 单分支推送只把这一个本地分支推到这一个远端分支，不设上游、不带标签，会回退远端时被拒绝；
    /// 非 HEAD 分支的安全强推在远端变化后按租约拒绝并保留 Git 原文，获取后再推成功，HEAD 始终不变。
    private static func branchPushes(_ runner: GitRunner, fixture: RemoteFixture) async throws {
        let refs = RepositoryReferences(runner: runner)
        let sync = RepositorySync(runner: runner)
        let bare = fixture.root + "/remote.git"
        let main = try await refs.resolve("refs/heads/main")

        _ = try await runner.run(["push", "-q", "origin", "main:refs/heads/topic"])
        _ = try await runner.run(["switch", "-q", "-c", "side", "main"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "side"])
        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["tag", "v1", "side"])

        // 单分支推送：远端 topic 指向 side，没有标签，side 不设上游
        _ = try await sync.push(
            branch: "side",
            remote: "origin",
            destination: "topic",
            setUpstream: false,
            options: PushOptions(),
            lease: nil
        )

        #expect(try await remoteTip("topic", runner) == refs.resolve("refs/heads/side"))
        #expect(try await runner.run(["ls-remote", "--tags", "origin"]).isEmpty)
        #expect(try await upstream(of: "side", runner) == nil)
        #expect(try await runner.status().branch.head == "main")

        // 把 main 推到 topic 会回退远端，Git 按非快进拒绝
        let fastForward = await #expect(throws: GitError.self) {
            try await sync.push(
                branch: "main",
                remote: "origin",
                destination: "topic",
                setUpstream: false,
                options: PushOptions(),
                lease: nil
            )
        }

        #expect(fastForward?.category == .pushRejected)

        // 非 HEAD 的 other 按获取到的 topic 强推；别处已把远端 topic 改回 main，租约不再匹配
        let lease = try await refs.resolve("refs/remotes/origin/topic")
        _ = try await RemoteFixture.raw(["git", "--git-dir", bare, "update-ref", "refs/heads/topic", main])

        let stale = await #expect(throws: GitError.self) {
            try await sync.push(
                branch: "other",
                remote: "origin",
                destination: "topic",
                setUpstream: false,
                lease: lease
            )
        }

        let rejected = try #require(stale)
        #expect(rejected.category == .pushRejected)
        #expect(String(decoding: rejected.result.standardOutput, as: UTF8.self).contains("stale info"))
        #expect(try await remoteTip("topic", runner) == main)

        // 获取后按新的租约强推成功，远端 main 与本地 HEAD 不动
        _ = try await runner.run(["fetch", "-q", "origin"])

        _ = try await sync.push(
            branch: "other",
            remote: "origin",
            destination: "topic",
            setUpstream: false,
            lease: refs.resolve("refs/remotes/origin/topic")
        )

        #expect(try await remoteTip("topic", runner) == refs.resolve("refs/heads/other"))
        #expect(try await remoteTip("main", runner) == main)
        #expect(try await runner.status().branch.head == "main")
    }
}

// MARK: - Sidebar Helpers

extension RemoteReferenceManagementTests {
    /// 在 B 上的工作区写入文件；路径与内容都作为位置参数传给 shell。
    private static func write(_ text: String, to name: String, in fixture: RemoteFixture) async throws {
        _ = try await RemoteFixture.raw([
            "/bin/sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", text, fixture.repository + "/" + name,
        ])
    }

    /// 读取 B 上工作区里的文件内容。
    private static func read(_ name: String, in fixture: RemoteFixture) async throws -> String {
        let result = try await RemoteFixture.raw(["/bin/cat", "--", fixture.repository + "/" + name])
        return String(decoding: result.standardOutput, as: UTF8.self)
    }

    /// 本地分支的上游完整引用名；没有上游时为 nil。
    private static func upstream(of name: String, _ runner: GitRunner) async throws -> String? {
        let output = try await runner.run(["for-each-ref", "--format=%(upstream)", "refs/heads/" + name])
        let upstream = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
        return upstream.isEmpty ? nil : upstream
    }

    /// 远端仓库上分支当前指向的提交。
    private static func remoteTip(_ branch: String, _ runner: GitRunner) async throws -> String {
        let output = try await runner.run(["ls-remote", "origin", "refs/heads/" + branch])
        return String(String(decoding: output, as: UTF8.self).prefix { !$0.isWhitespace })
    }
}
