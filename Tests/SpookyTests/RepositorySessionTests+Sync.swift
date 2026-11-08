import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 同步停在哪一步的说明、快速推送缺少跟踪分支时的说明，以及 Push 改开 Publish Branch 的条件。
extension RepositorySessionTests {
    /// 没有跟踪分支的快速推送不开始写入，只说明原因；同步里的推送记录只写远端分支，当前分支与远端分支不同名时也是；
    /// 推送被拒时错误说明写明停在推送、获取与拉取已完成，Activity 把同步记成拉取与推送两条，拉取完成、推送失败。
    @Test("快速推送缺少跟踪分支，同步的记录与停下的步骤")
    func syncRecords() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (runner, _) = try await makeSyncRepository(in: directory)
        _ = try await runner.run(["switch", "-q", "-c", "topic"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "topic"])

        let session = try await openSession(runner)
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        // 新分支没有跟踪分支，快速推送不开始写入，只说明原因
        #expect(session.headBranch?.id == "refs/heads/topic")

        session.quickPush()

        #expect(!session.isWriting)
        #expect(failures.last?.title == AppLocalization.text("error.synchronization"))
        #expect(failures.last?.message.hasPrefix(AppLocalization.text("sync.error.upstream")) ?? false)

        // 同步成功：推上去的是 topic 的提交，两条记录的标题都只写远端分支
        #expect(session.sync(remote: "origin", branch: "refs/heads/main", options: SyncOptions()))
        await session.writeTask?.value

        let records = remoteRecords(runner)

        #expect(records.map(\.target) == [
            .push("origin", refspec: "refs/heads/main"),
            .pull("origin", refspec: "refs/heads/main"),
        ])

        #expect(records.allSatisfy { $0.state == "activity.finished" })

        let pushed = try await runner.run(["rev-parse", "--verify", "refs/remotes/origin/main"])
        let topic = try await runner.run(["rev-parse", "--verify", "refs/heads/topic"])
        #expect(pushed == topic)

        try await rejectedSync(session, runner: runner, directory: directory)
    }

    /// HEAD 没有上游时，推送 HEAD 分支改开发布分支；有上游、指定了目标远端分支或推的是别的分支时仍是推送。
    @Test("HEAD 没有上游时 Push 改开 Publish Branch")
    func pushWithoutUpstreamPublishes() {
        let untracked = BranchStatus(head: "feature/一", oid: "abc", upstream: nil)
        let tracked = BranchStatus(head: "feature/一", oid: "abc", upstream: "origin/feature/一")

        // 菜单、工具栏与右键 HEAD 分支的推送都改开发布，远端与本地分支原样带上
        let menu = RepositoryActionRequest(kind: .push).resolved(for: untracked)
        #expect(menu.kind == .publish)
        #expect(menu.localBranch == nil)

        let head = RepositoryActionRequest(kind: .push, remote: "origin", localBranch: "feature/一")
            .resolved(for: untracked)
        #expect(head.kind == .publish)
        #expect(head.remote == "origin")
        #expect(head.localBranch == "feature/一")

        // 有上游、拖到远端分支指定了目标、推的是别的本地分支，以及读不到状态时仍是推送
        #expect(RepositoryActionRequest(kind: .push).resolved(for: tracked).kind == .push)
        #expect(
            RepositoryActionRequest(kind: .push, reference: "refs/remotes/origin/main", localBranch: "feature/一")
                .resolved(for: untracked).kind == .push
        )

        #expect(RepositoryActionRequest(kind: .push, localBranch: "main").resolved(for: untracked).kind == .push)
        #expect(RepositoryActionRequest(kind: .push).resolved(for: nil).kind == .push)

        // 别的动作不受影响
        #expect(RepositoryActionRequest(kind: .pull).resolved(for: untracked).kind == .pull)
    }
}

// MARK: - Steps

extension RepositorySessionTests {
    /// 远端的 pre-receive 钩子拒绝一切推送时同步停在推送：说明写明获取与拉取已完成，最新的两条记录是失败的推送与完成的拉取。
    private func rejectedSync(
        _ session: RepositorySession,
        runner: GitRunner,
        directory: URL
    ) async throws {
        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        let hook = directory.appending(path: "remote.git/hooks/pre-receive")
        try FileManager.default.createDirectory(
            at: hook.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "local"])

        #expect(session.sync(remote: "origin", branch: "refs/heads/main", options: SyncOptions()))
        await session.writeTask?.value

        let completed = ListFormatter.localizedString(
            byJoining: [SyncProgress.name(.fetch), SyncProgress.name(.pull)]
        )
        let note = AppLocalization.text("sync.stopped", SyncProgress.name(.push), completed)

        #expect(failures.count == 1)
        #expect(failures.first?.message.hasPrefix(note) ?? false)

        // 新的在前：推送记录在拉取记录之前
        let records = Array(remoteRecords(runner).prefix(2))

        #expect(records.map(\.target) == [
            .push("origin", refspec: "refs/heads/main"),
            .pull("origin", refspec: "refs/heads/main"),
        ])

        #expect(records.map(\.state) == ["activity.failed", "activity.finished"])
        #expect(records.first?.log.contains("pre-receive hook declined") ?? false)
    }
}

// MARK: - Sync Helpers

extension RepositorySessionTests {
    /// 本测试专用的临时目录。
    func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-sync-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    /// 本地仓库发布 `main` 到同目录的裸远端，并克隆出另一个工作区模拟别人推送。
    func makeSyncRepository(in directory: URL) async throws -> (local: GitRunner, other: GitRunner) {
        let local = directory.appending(path: "local")
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: false)

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: local.path))
        let bare = directory.appending(path: "remote.git").path
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["init", "-q", "--bare", bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        _ = try await runner.run(["push", "-q", "-u", "origin", "main"])

        let otherPath = directory.appending(path: "other").path
        _ = try await runner.run(["clone", "-q", "-b", "main", bare, otherPath])

        let other = GitRunner(
            location: .local(path: otherPath),
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )

        _ = try await other.run(["config", "--local", "user.name", "Other"])
        _ = try await other.run(["config", "--local", "user.email", "other@example.invalid"])

        return (runner, other)
    }

    /// 打开仓库，等刷新与它带起的引用读取都结束。
    func openSession(_ runner: GitRunner) async throws -> RepositorySession {
        let session = RepositorySession(makeRunner: { _ in runner })
        session.display(runner.location)
        session.refresh()
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }

        #expect(!(session.history.snapshot?.remotes.isEmpty ?? true))
        return session
    }

    /// 本地仓库在 Activity 的 Remote 页上的记录，新的在前。
    func remoteRecords(_ runner: GitRunner) -> [RepositoryActivity] {
        RepositoryActivities.shared.items.filter {
            $0.repository == runner.location && $0.kind == .remote
        }
    }

    /// 另一个克隆提交并推送，返回推上去的提交。
    func commitAndPush(_ other: GitRunner, message: String) async throws -> String {
        _ = try await other.run(["commit", "--allow-empty", "-m", message])
        _ = try await other.run(["push", "-q", "origin", "HEAD:main"])
        return try await RepositoryReferences(runner: other).resolve("HEAD")
    }

    /// 本地仓库里 `origin/main` 指向的提交。
    func tracking(_ runner: GitRunner) async throws -> String {
        try await RepositoryReferences(runner: runner).resolve("refs/remotes/origin/main")
    }
}
