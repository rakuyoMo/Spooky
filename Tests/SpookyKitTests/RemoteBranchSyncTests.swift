import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteBranchSyncTests

/// 服务器上的分支、获取清理、拉取与合并、租约推送、自动储藏、获取的中断与自动获取的远端筛选，只在显式启用时访问 spooky-test 的独立测试目录。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteBranchSyncTests {
    /// 工作区、另一个克隆与裸仓库都在 B 上；每段核对 B 上实际的 HEAD、引用、upstream 与文件内容。
    @Test("服务器分支、获取清理、未跟踪文件、租约推送、自动储藏、获取中断与自动获取的远端")
    func branchAndSyncFlow() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()
        let otherRemote = RemoteConnection(
            host: "spooky-test",
            path: fixture.root + "/other",
            configuration: RemoteFixture.configuration
        )

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let bare = fixture.root + "/remote.git"
            try await prepare(runner: runner, location: location, bare: bare)

            _ = try await runner.run(["clone", "-q", "-b", "main", bare, fixture.root + "/other"])
            let otherLocation = try await otherRemote.open().location
            let other = GitRunner(location: otherLocation, remote: otherRemote)

            for (key, value) in [("user.name", "Other"), ("user.email", "other@example.invalid"), ("commit.gpgSign", "false")] {
                _ = try await other.run(["config", "--local", key, value])
            }

            try await checkBranches(runner: runner)
            try await checkPrune(runner: runner, other: other)
            try await checkUntrackedFiles(runner: runner, other: other, location: location)
            try await checkLease(runner: runner, other: other)
            try await checkAutoStash(runner: runner, location: location)
            try await checkFetchInterruption(runner: runner, remote: remote, bare: bare)
            try await checkAutoFetchTargets(runner: runner, bare: bare)

            await otherRemote.close()
            await remote.close()
            try await fixture.remove()
        } catch {
            if let error = error as? GitError {
                Issue.record(Comment(rawValue: error.message))
            }

            await otherRemote.close()
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}

// MARK: - Private

extension RemoteBranchSyncTests {
    /// 在 B 上建好带一个提交的工作区与裸仓库，`main` 跟踪 `origin/main`。
    private func prepare(runner: GitRunner, location: RepositoryLocation, bare: String) async throws {
        let files = RepositoryFiles(runner: runner)
        let working = WorkingCopyOperations(runner: runner)

        _ = try await runner.run(["init", "-q", "--bare", bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        try await files.write(Data("base\n".utf8), to: location.path + "/notes.txt")
        try await working.stageAll(staged: true)
        try await working.commit(subject: "服务器根提交", body: "")

        _ = try await RepositorySync(runner: runner)
            .push(branch: "main", remote: "origin", destination: "main", setUpstream: true)
    }

    /// 先建再检出、跟踪远端分支、改名与删除保护，核对 HEAD、引用与 upstream。
    private func checkBranches(runner: GitRunner) async throws {
        let references = RepositoryReferences(runner: runner)

        // 先建再检出：HEAD 换到新分支
        try await references.createThenCheckOut(name: "topic/新建", startingAt: "main", track: false)
        #expect(try await runner.status().branch.head == "topic/新建")

        // 跟踪远端分支只建不检出：upstream 是所选的远端分支，HEAD 不变
        try await references.create(
            name: "tracked",
            startingAt: "refs/remotes/origin/main",
            track: true,
            checkout: false
        )

        let upstream = try await runner.run(["rev-parse", "--abbrev-ref", "tracked@{upstream}"])
        #expect(String(decoding: upstream, as: UTF8.self) == "origin/main\n")
        #expect(try await runner.status().branch.head == "topic/新建")

        // 改名后旧引用消失，upstream 随分支保留
        try await references.rename("refs/heads/tracked", to: "tracked-renamed")
        #expect(try await references.resolve("refs/heads/tracked-renamed") == references.resolve("main"))

        let renamedUpstream = try await runner.run(["rev-parse", "--abbrev-ref", "tracked-renamed@{upstream}"])
        #expect(String(decoding: renamedUpstream, as: UTF8.self) == "origin/main\n")
        await #expect(throws: GitError.self) { try await references.resolve("refs/heads/tracked") }

        // 未合并的分支普通删除被拒绝，分支仍在；强制删除后消失
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "未合并"])
        try await references.checkout("refs/heads/main")

        await #expect(throws: ReferenceError.self) {
            try await references.delete("refs/heads/topic/新建", force: false, deletingUpstream: false)
        }

        _ = try await references.resolve("refs/heads/topic/新建")
        try await references.delete("refs/heads/topic/新建", force: true, deletingUpstream: false)
        try await references.delete("refs/heads/tracked-renamed", force: false, deletingUpstream: false)
        await #expect(throws: GitError.self) { try await references.resolve("refs/heads/topic/新建") }
    }

    /// 普通映射清理时保留本地独有标签；映射含标签时按 Git 的结果删掉远端没有的本地标签。
    private func checkPrune(runner: GitRunner, other: GitRunner) async throws {
        let sync = RepositorySync(runner: runner)
        let references = RepositoryReferences(runner: runner)

        _ = try await other.run(["push", "-q", "origin", "main:refs/heads/gone"])
        _ = try await sync.fetch(remote: "origin", prune: true)
        _ = try await references.resolve("refs/remotes/origin/gone")

        _ = try await runner.run(["tag", "local-only"])
        _ = try await other.run(["push", "-q", "origin", "--delete", "gone"])
        _ = try await sync.fetch(remote: "origin", prune: true)
        await #expect(throws: GitError.self) { try await references.resolve("refs/remotes/origin/gone") }
        _ = try await references.resolve("refs/tags/local-only")

        _ = try await runner.run(["config", "--local", "--add", "remote.origin.fetch", "+refs/tags/*:refs/tags/*"])
        _ = try await sync.fetch(remote: "origin", prune: true)
        await #expect(throws: GitError.self) { try await references.resolve("refs/tags/local-only") }
    }

    /// 只有未跟踪文件时拉取与合并直接执行；同名的未跟踪文件被 Git 拒绝，文件与 HEAD 都不变。
    private func checkUntrackedFiles(runner: GitRunner, other: GitRunner, location: RepositoryLocation) async throws {
        let sync = RepositorySync(runner: runner)
        let references = RepositoryReferences(runner: runner)
        let files = RepositoryFiles(runner: runner)
        let scratch = location.path + "/scratch.txt"
        let clash = location.path + "/clash.txt"

        // 拉取：未跟踪的 scratch.txt 不挡住，内容不动
        try await files.write(Data("scratch\n".utf8), to: scratch)
        _ = try await other.run(["pull", "-q", "--ff-only"])
        _ = try await other.run(["commit", "-q", "--allow-empty", "-m", "另一个克隆的提交"])
        _ = try await other.run(["push", "-q", "origin", "main"])
        try await sync.pull(rebase: false)
        #expect(try await references.resolve("HEAD") == RepositoryReferences(runner: other).resolve("HEAD"))
        #expect(try await files.read([scratch])[scratch] == Data("scratch\n".utf8))

        // 拉取：远端带来同名文件时被拒绝
        try await files.write(Data("local clash\n".utf8), to: clash)
        try await RepositoryFiles(runner: other).write(Data("remote clash\n".utf8), to: other.location.path + "/clash.txt")
        _ = try await other.run(["add", "clash.txt"])
        _ = try await other.run(["commit", "-q", "-m", "加入 clash.txt"])
        _ = try await other.run(["push", "-q", "origin", "main"])

        let head = try await references.resolve("HEAD")
        await #expect(throws: GitError.self) { try await sync.pull(rebase: false) }
        #expect(try await references.resolve("HEAD") == head)
        #expect(try await files.read([clash])[clash] == Data("local clash\n".utf8))

        // 合并：未跟踪文件不挡住；同名文件同样被拒绝
        _ = try await runner.run(["branch", "incoming", "origin/main"])
        _ = try await runner.run(["branch", "side", "main"])
        try await references.checkout("refs/heads/side")
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "side"])
        try await references.checkout("refs/heads/main")
        #expect(try await sync.merge("refs/heads/side") == .merged)
        #expect(try await files.read([scratch])[scratch] == Data("scratch\n".utf8))

        let merged = try await references.resolve("HEAD")
        await #expect(throws: GitError.self) { try await sync.merge("refs/heads/incoming") }
        #expect(try await references.resolve("HEAD") == merged)
        #expect(try await files.read([clash])[clash] == Data("local clash\n".utf8))

        // 拿掉两份未跟踪文件，回到远端的 main
        _ = try await runner.run(["clean", "-q", "-f", "--", "scratch.txt", "clash.txt"])
        _ = try await runner.run(["reset", "-q", "--hard", "origin/main"])
    }

    /// 安全强推的期望值过期时远端拒绝，远端分支保持另一个克隆推上去的提交。
    private func checkLease(runner: GitRunner, other: GitRunner) async throws {
        let sync = RepositorySync(runner: runner)
        let expected = try await RepositoryReferences(runner: runner).resolve("refs/remotes/origin/main")

        _ = try await other.run(["pull", "-q", "--ff-only"])
        _ = try await other.run(["commit", "-q", "--allow-empty", "-m", "抢先推送"])
        _ = try await other.run(["push", "-q", "origin", "main"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "本地改写"])

        let error = await #expect(throws: GitError.self) {
            try await sync.push(
                branch: "main",
                remote: "origin",
                destination: "main",
                setUpstream: false,
                lease: expected
            )
        }

        let rejected = try #require(error)
        #expect(rejected.category == .pushRejected)
        #expect(String(decoding: rejected.result.standardOutput, as: UTF8.self).contains("stale info"))

        let remoteHead = try await RepositoryReferences(runner: other).resolve("HEAD")
        let listed = try await runner.run(["ls-remote", "origin", "refs/heads/main"])
        #expect(String(decoding: listed, as: UTF8.self).hasPrefix(remoteHead))

        _ = try await RepositorySync(runner: runner).fetch(remote: "origin")
        _ = try await runner.run(["reset", "-q", "--hard", "origin/main"])
    }

    /// 自动储藏不恢复时储藏留着、改动不回到工作区；恢复时改动回到工作区、储藏清掉。
    private func checkAutoStash(runner: GitRunner, location: RepositoryLocation) async throws {
        let stashes = RepositoryStashes(runner: runner)
        let files = RepositoryFiles(runner: runner)
        let notes = location.path + "/notes.txt"

        _ = try await runner.run(["branch", "-f", "stash-target", "main"])

        try await files.write(Data("kept\n".utf8), to: notes)
        try await stashes.stashingLocalChanges(message: "kept", reapply: false) {
            try await RepositoryReferences(runner: runner).checkout("refs/heads/stash-target")
        }

        #expect(try await stashes.list().map(\.message) == ["kept"])
        #expect(try await files.read([notes])[notes] == Data("base\n".utf8))

        try await files.write(Data("reapplied\n".utf8), to: notes)
        try await stashes.stashingLocalChanges(message: "reapplied", reapply: true) {
            try await RepositoryReferences(runner: runner).checkout("refs/heads/main")
        }

        #expect(try await stashes.list().map(\.message) == ["kept"])
        #expect(try await files.read([notes])[notes] == Data("reapplied\n".utf8))
    }

    /// 获取停在传输中时取消或断开主连接：报告取消或断线，重连后远端跟踪引用不变。
    private func checkFetchInterruption(runner: GitRunner, remote: RemoteConnection, bare: String) async throws {
        let sync = RepositorySync(runner: runner)
        let references = ["for-each-ref", "--format=%(refname) %(objectname)", "refs/remotes"]

        // 这个远端的 upload-pack 先在标准错误报到再停 30 秒，获取一定停在等远端回应的阶段
        _ = try await runner.run(["remote", "add", "slow", bare])
        _ = try await runner.run(["config", "--local", "remote.slow.uploadpack", "echo SPOOKY_WAITING >&2; sleep 30; :"])
        let before = try await runner.run(references)

        for disconnect in [false, true] {
            let (events, continuation) = AsyncStream<GitOutputEvent>.makeStream()
            let task = Task {
                defer { continuation.finish() }
                return try await sync.fetch(
                    remote: "slow",
                    prune: true,
                    onOutput: { continuation.yield($0) }
                )
            }

            var stderr = Data()
            var waiting = false

            // 等远端报到后才中断，确认中断落在传输中的获取上
            for await event in events {
                if case .standardError(let data) = event {
                    stderr.append(data)
                }

                if String(decoding: stderr, as: UTF8.self).contains("SPOOKY_WAITING") {
                    waiting = true

                    if disconnect {
                        try await remote.interruptMaster()
                    } else {
                        task.cancel()
                    }

                    break
                }
            }

            #expect(waiting)

            do {
                _ = try await task.value
                Issue.record("中断的获取不能报告成功")
            } catch {
                #expect(
                    error is CancellationError || error is RemoteConnectionError
                        || ((error as? GitError)?.isCancelled ?? false)
                )
            }

            _ = try await remote.reconnect()
            #expect(try await runner.run(references) == before)
        }

        _ = try await runner.run(["remote", "remove", "slow"])
    }

    /// 服务器仓库的自动获取只去掉 skipFetchAll：B 上的路径与 A 解析不了的主机都保留，B 上实际获取成功。
    private func checkAutoFetchTargets(runner: GitRunner, bare: String) async throws {
        let sync = RepositorySync(runner: runner)

        _ = try await runner.run(["remote", "add", "server-path", bare])
        _ = try await runner.run(["remote", "add", "internal", "ssh://internal.invalid/repo.git"])
        _ = try await runner.run(["remote", "add", "skipped", bare])
        _ = try await runner.run(["config", "--local", "remote.skipped.skipFetchAll", "true"])

        let targets = try await sync.autoFetchTargets(
            among: ["origin", "server-path", "internal", "skipped"],
            requiresHost: false
        )

        #expect(targets == ["origin", "server-path", "internal"])

        _ = try await sync.fetch(remote: "server-path")
        _ = try await RepositoryReferences(runner: runner).resolve("refs/remotes/server-path/main")
    }
}
