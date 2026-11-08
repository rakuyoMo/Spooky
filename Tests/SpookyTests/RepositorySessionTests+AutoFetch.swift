import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 自动获取的调度：逐个远端判断是否到期，跨重启保留的获取时刻，跳过的远端与暂停、重新计时。
extension RepositorySessionTests {
    /// 远端 origin 与 second 的地址带主机，经测试用的 ssh 在本机取；nearby 是本机路径，file 是 `file://`，自动获取都跳过。
    /// 每个到期的远端各记一条记录，second 失败只记进 Activity；手动获取、失败的获取同样更新时刻，重建调度后仍按保存的时刻判断。
    @Test("自动获取：逐远端到期、记录、跳过的远端与保存的时刻")
    func autoFetch() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (runner, other) = try await makeSyncRepository(in: directory)
        try await useHostAddresses(runner, in: directory)

        let session = try await openSession(runner)
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defaults.set(300, forKey: RepositoryAutoFetch.intervalKey)

        // 从整秒开始：保存的时刻按 Unix 秒存取，整秒读回来与原值相等
        let conditions = AutoFetchConditions(now: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded()))
        let scheduler = conditions.scheduler(for: session, defaults: defaults)

        try await firstChecks(scheduler, conditions: conditions, runner: runner, other: other, defaults: defaults)
        #expect(failures.isEmpty)

        try await perRemoteTimes(scheduler, conditions: conditions, session: session, defaults: defaults)
        try await skippedChecks(conditions: conditions, session: session, runner: runner, defaults: defaults)
        await rescheduling(scheduler, conditions: conditions, defaults: defaults)
    }
}

// MARK: - Auto Fetch Steps

extension RepositorySessionTests {
    /// 重新计时后 10 s 检查；窗口不显示仓库时不获取，下一次检查排在 160 s 后；
    /// 显示仓库后两个带主机的远端都从没获取过，各自获取、各记一条，本机路径与 `file://` 不获取也不记时刻。
    private func firstChecks(
        _ scheduler: RepositoryAutoFetch,
        conditions: AutoFetchConditions,
        runner: GitRunner,
        other: GitRunner,
        defaults: UserDefaults
    ) async throws {
        let first = conditions.now.addingTimeInterval(RepositoryAutoFetch.initialDelay)

        scheduler.restart()
        #expect(scheduler.nextCheck == first)

        #expect(await scheduler.check(now: first).isEmpty)
        #expect(scheduler.nextCheck == first.addingTimeInterval(RepositoryAutoFetch.checkInterval))

        // 显示仓库后获取：origin 带来新提交，second 指向不存在的仓库
        conditions.showsRepository = true
        let pushed = try await commitAndPush(other, message: "remote")

        #expect(await scheduler.check(now: first) == ["origin", "second"])
        #expect(try await tracking(runner) == pushed)

        let records = Array(remoteRecords(runner).prefix(2))
        let title = AppLocalization.text("sync.autoFetch")

        #expect(records.map(\.target) == [.fetch("second"), .fetch("origin")])
        #expect(records.map(\.state) == ["activity.failed", "activity.finished"])
        #expect(records.allSatisfy { $0.title == title })

        // 获取时刻在主线程上补记
        let repository = runner.location
        await until { RemoteFetchTimes.lastFetch(of: "second", in: repository, defaults: defaults) != nil }

        #expect(RemoteFetchTimes.lastFetch(of: "origin", in: repository, defaults: defaults) != nil)
        #expect(RemoteFetchTimes.lastFetch(of: "nearby", in: repository, defaults: defaults) == nil)
        #expect(RemoteFetchTimes.lastFetch(of: "file", in: repository, defaults: defaults) == nil)
    }

    /// 间隔未到不获取；只有 origin 到期时只取 origin，刚取过的 second 不挡它；
    /// 手动获取 second 失败也更新它的时刻；重建调度对象后照保存的时刻判断。
    private func perRemoteTimes(
        _ scheduler: RepositoryAutoFetch,
        conditions: AutoFetchConditions,
        session: RepositorySession,
        defaults: UserDefaults
    ) async throws {
        let repository = try #require(session.repository)
        let old = conditions.now.addingTimeInterval(-1000)
        let later = conditions.now.addingTimeInterval(100)

        #expect(await scheduler.check(now: later).isEmpty)

        RemoteFetchTimes.record("origin", in: repository, at: old, defaults: defaults)
        #expect(await scheduler.check(now: later) == ["origin"])

        // 手动获取失败同样更新时刻
        let before = RemoteFetchTimes.lastFetch(of: "second", in: repository, defaults: defaults)
        session.quickFetch(remote: "second", defaults: defaults)
        await session.writeTask?.value

        await until { RemoteFetchTimes.lastFetch(of: "second", in: repository, defaults: defaults) != before }

        // 模拟重启：新的调度对象读到保存的时刻，origin 刚取过、不到期
        let reopened = conditions.scheduler(for: session, defaults: defaults)

        await until { RemoteFetchTimes.lastFetch(of: "origin", in: repository, defaults: defaults) ?? old > old }
        #expect(await reopened.check(now: later).isEmpty)
    }

    /// origin 设了 skipFetchAll、系统网络路径不可用或另有写操作时都不获取，跳过不更新它的时刻。
    private func skippedChecks(
        conditions: AutoFetchConditions,
        session: RepositorySession,
        runner: GitRunner,
        defaults: UserDefaults
    ) async throws {
        let repository = runner.location
        let old = conditions.now.addingTimeInterval(-1000)
        let later = conditions.now.addingTimeInterval(100)
        let scheduler = conditions.scheduler(for: session, defaults: defaults)

        RemoteFetchTimes.record("origin", in: repository, at: old, defaults: defaults)

        _ = try await runner.run(["config", "--local", "remote.origin.skipFetchAll", "true"])
        #expect(await scheduler.check(now: later).isEmpty)

        _ = try await runner.run(["config", "--local", "--unset", "remote.origin.skipFetchAll"])
        conditions.networkAvailable = false
        #expect(await scheduler.check(now: later).isEmpty)
        #expect(RemoteFetchTimes.lastFetch(of: "origin", in: repository, defaults: defaults) == old)

        // 另有写操作时不获取
        conditions.networkAvailable = true
        session.quickFetch(remote: "second", defaults: defaults)

        #expect(await scheduler.check(now: later).isEmpty)
        await session.writeTask?.value
    }

    /// 暂停后不排检查，重新计时排在 10 s 后；开始计时后改了间隔重新计时，改成 Never 停止。
    private func rescheduling(
        _ scheduler: RepositoryAutoFetch,
        conditions: AutoFetchConditions,
        defaults: UserDefaults
    ) async {
        scheduler.pause()
        #expect(scheduler.nextCheck == nil)

        scheduler.restart()
        #expect(scheduler.nextCheck == conditions.now.addingTimeInterval(RepositoryAutoFetch.initialDelay))

        // 时钟不动时周期检查不会到期，只看偏好变化后的重新计时
        scheduler.start()
        defer { scheduler.stop() }

        conditions.now = conditions.now.addingTimeInterval(5)
        defaults.set(600, forKey: RepositoryAutoFetch.intervalKey)

        let expected = conditions.now.addingTimeInterval(RepositoryAutoFetch.initialDelay)
        await until { scheduler.nextCheck == expected }

        defaults.set(0, forKey: RepositoryAutoFetch.intervalKey)
        await until { scheduler.nextCheck == nil }

        #expect(await scheduler.check(now: expected).isEmpty)
        #expect(scheduler.nextCheck == nil)
    }

    /// origin 与 second 改用带主机的地址，经测试用的 ssh 在本机执行服务端命令；另加本机路径与 `file://` 两个远端。
    private func useHostAddresses(_ runner: GitRunner, in directory: URL) async throws {
        let bare = directory.appending(path: "remote.git").path
        let ssh = directory.appending(path: "fake-ssh")

        // 最后一个参数是 “git-upload-pack '<路径>'”，换成 git 子命令在本机执行
        try Data("#!/bin/sh\nfor last; do :; done\nexec sh -c \"git ${last#git-}\"\n".utf8).write(to: ssh)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: ssh.path)

        _ = try await runner.run(["config", "--local", "core.sshCommand", ssh.path])
        _ = try await runner.run(["config", "--local", "ssh.variant", "simple"])
        _ = try await runner.run(["remote", "set-url", "origin", "ssh://example.invalid" + bare])
        _ = try await runner.run([
            "remote", "add", "second", "ssh://example.invalid" + directory.appending(path: "missing.git").path,
        ])
        _ = try await runner.run(["remote", "add", "nearby", bare])
        _ = try await runner.run(["remote", "add", "file", "file://" + bare])
    }
}

// MARK: - AutoFetchConditions

/// 测试里控制自动获取调度看到的时刻、窗口与网络。
@MainActor
private final class AutoFetchConditions {
    /// 调度读到的当前时刻。
    var now: Date

    /// 窗口是否正显示仓库且没有挂 sheet。
    var showsRepository = false

    /// 系统网络路径是否可用。
    var networkAvailable = true

    /// 从这个时刻开始。
    init(now: Date) {
        self.now = now
    }

    /// 建立读这些条件的调度对象。
    func scheduler(for session: RepositorySession, defaults: UserDefaults) -> RepositoryAutoFetch {
        RepositoryAutoFetch(
            session: session,
            defaults: defaults,
            clock: { [weak self] in self?.now ?? .distantPast },
            isNetworkAvailable: { [weak self] in self?.networkAvailable ?? false },
            showsRepository: { [weak self] in self?.showsRepository ?? false }
        )
    }
}
