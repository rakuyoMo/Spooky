import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 自动获取的调度：逐个远端判断是否到期，跨重启保留的获取时刻，跳过的远端、让路与暂停、重新计时。
extension RepositorySessionTests {
    /// 远端 origin 与 second 的地址带主机，经测试用的 ssh 在本机取；nearby 是本机路径，file 是 `file://`，自动获取都跳过。
    /// 每个到期的远端各记一条记录，second 失败只记进 Activity；手动获取、失败的获取同样更新时刻，重建调度后仍按保存的时刻判断；
    /// 获取中途有用户发起的写操作时停下让路。
    @Test("自动获取：逐远端到期、记录、跳过的远端、让路与保存的时刻")
    func autoFetch() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let gate = try ProcessGate(in: directory)
        let (runner, other) = try await makeSyncRepository(in: directory)
        try await useHostAddresses(runner, in: directory, gate: gate)

        let session = try await openSession(runner)
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defaults.set(300, forKey: RepositoryAutoFetch.intervalKey)

        // 从整秒开始：保存的时刻按 Unix 秒存取，整秒读回来与原值相等
        let conditions = AutoFetchConditions(now: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded()))
        let scheduler = conditions.scheduler(for: session, defaults: defaults)

        try await firstChecks(scheduler, conditions: conditions, session: session, other: other, defaults: defaults)
        #expect(failures.isEmpty)

        try await perRemoteTimes(scheduler, conditions: conditions, session: session, defaults: defaults)
        try await skippedChecks(conditions: conditions, session: session, runner: runner, defaults: defaults)
        try await yielding(scheduler, conditions: conditions, session: session, gate: gate, defaults: defaults)
        await rescheduling(scheduler, conditions: conditions, session: session, defaults: defaults)
    }
}

// MARK: - Auto Fetch Steps

extension RepositorySessionTests {
    /// 重新计时后 10 s 检查；窗口不显示仓库时不获取，下一次检查排在 160 s 后；
    /// 显示仓库后两个带主机的远端都从没获取过，各自获取、各记一条，本机路径与 `file://` 不获取也不记时刻。
    private func firstChecks(
        _ scheduler: RepositoryAutoFetch,
        conditions: AutoFetchConditions,
        session: RepositorySession,
        other: GitRunner,
        defaults: UserDefaults
    ) async throws {
        let runner = try #require(session.runner)
        let first = conditions.now.addingTimeInterval(RepositoryAutoFetch.initialDelay)

        scheduler.restart()
        #expect(scheduler.nextCheck == first)

        await expectCheck(scheduler, now: first, fetches: [], session: session, defaults: defaults)
        #expect(scheduler.nextCheck == first.addingTimeInterval(RepositoryAutoFetch.checkInterval))

        // 显示仓库后获取：origin 带来新提交，second 指向不存在的仓库
        conditions.showsRepository = true
        let pushed = try await commitAndPush(other, message: "remote")

        // 后面等获取时刻的步骤以这两次获取为前提，没开始时立即结束，不空等
        let both = ["origin", "second"]
        try #require(await expectCheck(scheduler, now: first, fetches: both, session: session, defaults: defaults))
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

        await expectCheck(scheduler, now: later, fetches: [], session: session, defaults: defaults)

        // 只让 origin 到期；后面要等它的新时刻，这次获取没开始时立即结束
        RemoteFetchTimes.record("origin", in: repository, at: old, defaults: defaults)
        try #require(await expectCheck(scheduler, now: later, fetches: ["origin"], session: session, defaults: defaults))

        // 手动获取失败同样更新时刻
        let before = RemoteFetchTimes.lastFetch(of: "second", in: repository, defaults: defaults)
        session.quickFetch(remote: "second", defaults: defaults)
        await session.writeTask?.value

        await until { RemoteFetchTimes.lastFetch(of: "second", in: repository, defaults: defaults) != before }

        // 模拟重启：新的调度对象读到保存的时刻，origin 刚取过、不到期
        let reopened = conditions.scheduler(for: session, defaults: defaults)

        await until { RemoteFetchTimes.lastFetch(of: "origin", in: repository, defaults: defaults) ?? old > old }
        await expectCheck(reopened, now: later, fetches: [], session: session, defaults: defaults)
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
        await expectCheck(scheduler, now: later, fetches: [], session: session, defaults: defaults)

        _ = try await runner.run(["config", "--local", "--unset", "remote.origin.skipFetchAll"])
        conditions.networkAvailable = false
        await expectCheck(scheduler, now: later, fetches: [], session: session, defaults: defaults)
        #expect(RemoteFetchTimes.lastFetch(of: "origin", in: repository, defaults: defaults) == old)

        // 另有写操作时不获取
        conditions.networkAvailable = true
        session.quickFetch(remote: "second", defaults: defaults)

        await expectCheck(scheduler, now: later, fetches: [], session: session, defaults: defaults)
        await session.writeTask?.value
    }

    /// origin 与 second 都到期，origin 获取到一半时手动获取 nearby：自动获取停下让路，记录写明让给了哪个操作、记为取消，
    /// 这次检查里 second 不再获取；origin 的时刻保留开始获取时记下的值，手动获取随后照常完成。
    private func yielding(
        _ scheduler: RepositoryAutoFetch,
        conditions: AutoFetchConditions,
        session: RepositorySession,
        gate: ProcessGate,
        defaults: UserDefaults
    ) async throws {
        let runner = try #require(session.runner)
        let repository = runner.location
        let old = conditions.now.addingTimeInterval(-1000)
        let later = conditions.now.addingTimeInterval(100)

        RemoteFetchTimes.record("origin", in: repository, at: old, defaults: defaults)
        RemoteFetchTimes.record("second", in: repository, at: old, defaults: defaults)

        // origin 的获取停在测试用的 ssh 里，开始时记下的时刻在主线程上补记
        try gate.arm()
        defer { gate.release() }

        let checking = Task { await scheduler.check(now: later) }
        await gate.arrival()
        await until { RemoteFetchTimes.lastFetch(of: "origin", in: repository, defaults: defaults) != old }

        let started = RemoteFetchTimes.lastFetch(of: "origin", in: repository, defaults: defaults)
        session.quickFetch(remote: "nearby", defaults: defaults)

        #expect(await checking.value == ["origin"])
        await until { RepositoryWriteQueue.shared.isIdle(repository) }

        // 新的在前：手动获取 nearby 完成，origin 的自动获取写明让给了它
        let records = Array(remoteRecords(runner).prefix(2))
        let quickFetch = AppLocalization.text("sync.quickFetch")

        #expect(records.map(\.target) == [.fetch("nearby"), .fetch("origin")])
        #expect(records.map(\.state) == ["activity.finished", "activity.cancelled"])
        #expect(records.last?.log.contains(AppLocalization.text("sync.autoFetch.yielded", quickFetch)) ?? false)

        #expect(RemoteFetchTimes.lastFetch(of: "origin", in: repository, defaults: defaults) == started)
        #expect(RemoteFetchTimes.lastFetch(of: "second", in: repository, defaults: defaults) == old)
    }

    /// 暂停后不排检查，重新计时排在 10 s 后；开始计时后改了间隔重新计时，改成 Never 停止。
    private func rescheduling(
        _ scheduler: RepositoryAutoFetch,
        conditions: AutoFetchConditions,
        session: RepositorySession,
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

        await expectCheck(scheduler, now: expected, fetches: [], session: session, defaults: defaults)
        #expect(scheduler.nextCheck == nil)
    }

    /// 检查一次并核对这次获取的远端；不符时的记录带上实际获取的远端，以及决定获取哪些远端的状态：
    /// 仓库能否获取、会话读到的远端、各远端距上次获取的秒数。
    ///
    /// - Parameters:
    ///   - scheduler: 调度对象。
    ///   - now: 这次检查的时刻。
    ///   - expected: 应当获取的远端。
    ///   - session: 调度对象所属的会话。
    ///   - defaults: 保存获取时刻的偏好域。
    ///   - sourceLocation: 记录指向的调用位置。
    /// - Returns: 获取的远端是否与预期相符。
    @discardableResult
    private func expectCheck(
        _ scheduler: RepositoryAutoFetch,
        now: Date,
        fetches expected: [String],
        session: RepositorySession,
        defaults: UserDefaults,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async -> Bool {
        // 状态在检查之前取：检查会改写获取时刻
        let remotes = session.history.snapshot?.remotes.map(\.name)

        let times = (remotes ?? []).map { remote in
            let last = session.repository.flatMap { RemoteFetchTimes.lastFetch(of: remote, in: $0, defaults: defaults) }
            return "\(remote)=\(last.map { String(now.timeIntervalSince($0)) } ?? "nil")"
        }

        let state = "canFetch=\(session.canFetch) isWriting=\(session.isWriting) "
            + "remotes=\(remotes.map(String.init(describing:)) ?? "nil") secondsSinceFetch=\(times)"

        let fetched = await scheduler.check(now: now)

        #expect(fetched == expected, "\(state)", sourceLocation: sourceLocation)
        return fetched == expected
    }

    /// origin 与 second 改用带主机的地址，经测试用的 ssh 在本机执行服务端命令；另加本机路径与 `file://` 两个远端。
    ///
    /// - Parameters:
    ///   - runner: 本地仓库的执行器。
    ///   - directory: 放远端仓库与测试用 ssh 的目录。
    ///   - gate: 武装后，第一次经测试用的 ssh 连接认领武装并停在闸门上。
    private func useHostAddresses(_ runner: GitRunner, in directory: URL, gate: ProcessGate) async throws {
        let bare = directory.appending(path: "remote.git").path
        let ssh = directory.appending(path: "fake-ssh")

        // 最后一个参数是 “git-upload-pack '<路径>'”，换成 git 子命令在本机执行
        let source = """
            #!/bin/sh
            for last; do :; done
            if \(gate.claim); then
                \(gate.hold)
            fi
            exec sh -c "git ${last#git-}"

            """

        try Data(source.utf8).write(to: ssh)
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
