import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 自动获取的调度与失败记录、同步停在哪一步的说明，以及快速操作缺少跟踪分支时的说明。
extension RepositorySessionTests {
    /// 只在前台、到期且仓库可写时获取；设了 skipFetchAll 的远端不获取；间隔为 0 时不获取。
    @Test("自动获取的间隔、前台限制与跳过的远端")
    func autoFetchSchedule() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (runner, other) = try await makeSyncRepository(in: directory)
        let session = try await openSession(runner)
        defer { session.close() }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defaults.set(300, forKey: RepositoryAutoFetch.intervalKey)

        let foreground = ForegroundState()
        let scheduler = RepositoryAutoFetch(session: session, defaults: defaults) { foreground.isActive }
        let start = Date()

        // 打开后先等一会儿；App 不在前台时到期也不获取
        #expect(!scheduler.check(now: start))
        #expect(!scheduler.check(now: start.addingTimeInterval(RepositoryAutoFetch.initialDelay + 1)))

        foreground.isActive = true
        let pushed = try await commitAndPush(other, message: "remote")

        #expect(scheduler.check(now: start.addingTimeInterval(RepositoryAutoFetch.initialDelay + 1)))
        await session.writeTask?.value
        #expect(try await tracking(runner) == pushed)

        let activity = RepositoryActivities.shared.items.first { $0.repository == runner.location }
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

    /// 自动获取失败不弹错误，原因记进 Activity。
    @Test("自动获取失败只记进 Activity")
    func autoFetchFailure() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (runner, _) = try await makeSyncRepository(in: directory)
        let session = try await openSession(runner)
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        _ = try await runner.run(["remote", "set-url", "origin", directory.appending(path: "missing.git").path])

        #expect(session.autoFetch())
        await session.writeTask?.value

        let activity = RepositoryActivities.shared.items.first { $0.repository == runner.location }
        #expect(failures.isEmpty)
        #expect(activity?.state == "activity.failed")
        #expect(activity?.log.contains("does not appear to be a git repository") ?? false)
    }

    /// 推送被拒时错误说明写明停在推送、获取与拉取已完成；没有跟踪分支的快速推送说明原因。
    @Test("同步停下的步骤与快速推送缺少跟踪分支")
    func syncFailureNote() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (runner, _) = try await makeSyncRepository(in: directory)
        let session = try await openSession(runner)
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        // 远端的 pre-receive 钩子拒绝一切推送
        let hooks = directory.appending(path: "remote.git/hooks")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: hooks.appending(path: "pre-receive"))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: hooks.appending(path: "pre-receive").path
        )
        _ = try await runner.run(["commit", "--allow-empty", "-m", "local"])

        #expect(session.sync(remote: "origin", branch: "refs/heads/main", options: SyncOptions()))
        await session.writeTask?.value

        let completed = ListFormatter.localizedString(byJoining: [SyncProgress.name(.fetch), SyncProgress.name(.pull)])
        let note = AppLocalization.text("sync.stopped", SyncProgress.name(.push), completed)
        #expect(failures.count == 1)
        #expect(failures.first?.message.hasPrefix(note) ?? false)

        // 新分支没有跟踪分支，快速推送不开始写入，只说明原因
        _ = try await runner.run(["switch", "-q", "-c", "topic"])
        session.refresh(full: true)
        await session.refreshTask?.value
        try await waitForSession { session.headBranch?.id == "refs/heads/topic" }

        session.quickPush()
        #expect(!session.isWriting)
        #expect(failures.last?.title == AppLocalization.text("sync.error.upstream"))
    }

    // MARK: 辅助

    /// 本测试专用的临时目录。
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-sync-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    /// 本地仓库发布 `main` 到同目录的裸远端，并克隆出另一个工作区模拟别人推送。
    private func makeSyncRepository(in directory: URL) async throws -> (local: GitRunner, other: GitRunner) {
        let local = directory.appending(path: "local")
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: false)

        let runner = try await initializeRepository(at: .local(path: local.path))
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

    /// 打开仓库并等到引用快照读进来。
    private func openSession(_ runner: GitRunner) async throws -> RepositorySession {
        let session = RepositorySession(makeRunner: { _ in runner })
        session.display(runner.location)
        session.refresh()
        await session.refreshTask?.value
        try await waitForSession { !(session.history.snapshot?.remotes.isEmpty ?? true) }
        return session
    }

    /// 另一个克隆提交并推送，返回推上去的提交。
    private func commitAndPush(_ other: GitRunner, message: String) async throws -> String {
        _ = try await other.run(["commit", "--allow-empty", "-m", message])
        _ = try await other.run(["push", "-q", "origin", "HEAD:main"])
        return try await RepositoryReferences(runner: other).resolve("HEAD")
    }

    /// 本地仓库里 `origin/main` 指向的提交。
    private func tracking(_ runner: GitRunner) async throws -> String {
        try await RepositoryReferences(runner: runner).resolve("refs/remotes/origin/main")
    }

    /// 等会话的异步读取满足条件，5 分钟后记为失败。
    private func waitForSession(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while !condition() {
            guard .now < deadline else {
                Issue.record("等待会话状态超时")
                return
            }

            try await Task.sleep(for: .milliseconds(50))
        }
    }
}

// MARK: - ForegroundState

/// 测试里切换 App 是否在前台，自动获取的调度器经闭包读它。
@MainActor
private final class ForegroundState {
    /// App 是否在前台。
    var isActive = false
}
