import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 自动获取的记录与调度、同步停在哪一步的说明、快速推送缺少跟踪分支时的说明，以及 Push 改开 Publish Branch 的条件。
extension RepositorySessionTests {
    /// 获取全部远端时每个远端记一条 Remote 记录，失败不弹错误、原因记进 Activity；
    /// 只在窗口显示仓库、到期且仓库可写时获取；设了 skipFetchAll 的远端不获取；间隔为 0 时不获取。
    @Test("自动获取：每个远端的记录、失败、调度条件与跳过的远端")
    func autoFetch() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (runner, other) = try await makeSyncRepository(in: directory)
        let session = try await openSession(runner)
        defer { session.close() }

        try await autoFetchRecords(session, runner: runner, directory: directory)

        _ = try await runner.run(["remote", "remove", "second"])
        try await autoFetchSchedule(session, runner: runner, other: other, directory: directory)
    }

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
    /// 第二个远端指向不存在的仓库：获取全部远端时每个远端记一条，标题都写自动获取；第二个失败只记进 Activity，不弹错误。
    private func autoFetchRecords(
        _ session: RepositorySession,
        runner: GitRunner,
        directory: URL
    ) async throws {
        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        _ = try await runner.run(["remote", "add", "second", directory.appending(path: "missing.git").path])

        #expect(session.autoFetch())
        await session.writeTask?.value

        let records = remoteRecords(runner).sorted {
            ($0.target?.remote ?? "") < ($1.target?.remote ?? "")
        }

        #expect(failures.isEmpty)
        #expect(records.map(\.target) == [.fetch("origin"), .fetch("second")])
        #expect(records.map(\.state) == ["activity.finished", "activity.failed"])
        let title = AppLocalization.text("sync.autoFetch")
        #expect(records.allSatisfy { $0.title == title && $0.ended != nil })
        #expect(records.last?.log.contains("does not appear to be a git repository") ?? false)
    }

    /// 调度器只在窗口显示仓库、到期时获取，间隔未到与跳过的远端都不获取；间隔为 0 时到期也不获取。
    private func autoFetchSchedule(
        _ session: RepositorySession,
        runner: GitRunner,
        other: GitRunner,
        directory: URL
    ) async throws {
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defaults.set(300, forKey: RepositoryAutoFetch.intervalKey)

        let window = RepositoryViewState()
        let scheduler = RepositoryAutoFetch(session: session, defaults: defaults) { window.showsRepository }
        let start = Date()
        let due = start.addingTimeInterval(RepositoryAutoFetch.initialDelay + 1)

        // 打开后先等一会儿；窗口不显示仓库时到期也不获取
        #expect(!scheduler.check(now: start))
        #expect(!scheduler.check(now: due))

        window.showsRepository = true
        let pushed = try await commitAndPush(other, message: "remote")

        #expect(scheduler.check(now: due))
        await session.writeTask?.value
        #expect(try await tracking(runner) == pushed)

        // 写入结束后的完整刷新另在 Repository 页记读取，只看 Remote 页最新的一条
        let activity = remoteRecords(runner).first

        #expect(activity?.title == AppLocalization.text("sync.autoFetch"))
        #expect(activity?.state == "activity.finished")

        // 间隔未到不获取；跳过的远端到期后也不获取
        #expect(!scheduler.check(now: start.addingTimeInterval(100)))

        _ = try await runner.run(["config", "--local", "remote.origin.skipFetchAll", "true"])
        _ = try await commitAndPush(other, message: "skipped")

        #expect(scheduler.check(now: start.addingTimeInterval(RepositoryAutoFetch.initialDelay + 302)))
        await session.writeTask?.value
        #expect(try await tracking(runner) == pushed)

        // 间隔为 0 时到期也不获取。0 写进另一个偏好域：覆盖同一个域里已有的值时，若进程的偏好缓存在这之前被清掉过，紧接着读到的可能仍是旧值
        let manual = try #require(UserDefaults(suiteName: directory.appending(path: "manual").path))
        manual.set(0, forKey: RepositoryAutoFetch.intervalKey)
        let paused = RepositoryAutoFetch(session: session, defaults: manual) { true }

        // 第一次检查开始计时，第二次时早已到期
        paused.check(now: start)
        #expect(!paused.check(now: start.addingTimeInterval(100_000)))
    }

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
    private func tracking(_ runner: GitRunner) async throws -> String {
        try await RepositoryReferences(runner: runner).resolve("refs/remotes/origin/main")
    }
}

// MARK: - RepositoryViewState

/// 测试里切换窗口是否正显示仓库，自动获取的调度器经闭包读它。
@MainActor
private final class RepositoryViewState {
    /// 窗口是否正显示仓库。
    var showsRepository = false
}
