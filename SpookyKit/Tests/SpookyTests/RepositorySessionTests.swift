import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 刷新生命周期的回归测试，以受控响应验证旧数据保留和过期请求隔离。
@MainActor
struct RepositorySessionTests {
    /// 刷新中和失败后都保留快照，恢复成功后替换状态并保留仍存在的选区。
    @Test("刷新保留旧数据、失败恢复与选区")
    func refreshAndRecovery() async throws {
        let source = ControlledStatusSource()
        var calls = source.calls.makeAsyncIterator()
        let session = RepositorySession(loadStatus: { _ in try await source.read() })
        session.display(RepositoryLocation.local(path: "/temporary/repository"))

        let first = try snapshot("first.txt")
        session.refresh()
        _ = await calls.next()
        #expect(session.isRefreshing)
        await source.complete(.success(first))
        await session.refreshTask?.value
        session.selectedID = StatusRowID(path: "first.txt", kind: .untracked)
        #expect(session.status == first)

        session.refresh()
        _ = await calls.next()
        let failingTask = session.refreshTask
        #expect(session.status == first)
        #expect(session.isRefreshing)

        // 并发按刷新不会再发起第二条相同读取。
        session.refresh()
        #expect(await source.pendingCount == 1)
        await source.complete(.failure(StatusParseError(record: "broken record")))
        await failingTask?.value
        #expect(session.status == first)
        #expect(session.failure?.details == "broken record")
        #expect(!session.isRefreshing)

        session.refresh()
        _ = await calls.next()
        await source.complete(.success(first))
        await session.refreshTask?.value
        #expect(session.failure == nil)
        #expect(session.selectedID?.path == "first.txt")

        let second = try snapshot("second.txt")
        session.refresh()
        _ = await calls.next()
        await source.complete(.success(second))
        await session.refreshTask?.value
        #expect(session.status == second)
        #expect(session.selectedID == nil)
    }

    /// 切换仓库后，忽略取消的读取即使晚到也不能覆盖新结果。
    @Test("切换与关闭丢弃过期响应")
    func obsoleteResponses() async throws {
        let source = ControlledStatusSource()
        var calls = source.calls.makeAsyncIterator()
        let session = RepositorySession(loadStatus: { _ in try await source.read() })
        session.display(RepositoryLocation.local(path: "/temporary/first"))
        session.refresh()
        _ = await calls.next()
        let obsoleteTask = session.refreshTask

        session.display(RepositoryLocation.local(path: "/temporary/second"))
        session.refresh()
        _ = await calls.next()
        await source.complete(.success(try snapshot("obsolete.txt")))
        await obsoleteTask?.value
        #expect(session.repository?.path == "/temporary/second")
        #expect(session.status == nil)
        #expect(session.isRefreshing)

        await source.complete(.success(try snapshot("current.txt")))
        await session.refreshTask?.value
        #expect(session.status?.entries.first?.path == "current.txt")

        session.refresh()
        _ = await calls.next()
        let closingTask = session.refreshTask
        session.selectedRecentLocation = .local(path: "/temporary/second")
        session.close()
        await source.complete(.success(try snapshot("late.txt")))
        await closingTask?.value
        #expect(session.repository == nil)
        #expect(session.status == nil)
        #expect(session.selectedRecentLocation == nil)
        #expect(!session.isRefreshing)
    }

    /// 同一路径的暂存删除和未跟踪状态在列表中必须有不同身份。
    @Test("同路径状态行与重复显示仓库")
    func rowIdentityAndReuse() async throws {
        #expect(
            StatusRowID(path: "same", kind: .tracked)
                != StatusRowID(path: "same", kind: .untracked)
        )

        let repository = RepositoryLocation.local(path: "/temporary/reused")
        let session = RepositorySession(loadStatus: { _ in try snapshot("file") })
        session.display(repository)
        session.refresh()
        await session.refreshTask?.value
        session.activeView = .history
        session.selectedID = StatusRowID(path: "file", kind: .untracked)
        session.display(repository)

        #expect(session.activeView == .history)
        #expect(session.selectedID?.path == "file")
        #expect(session.status?.entries.count == 1)
    }

    /// 暂存失败回滚勾选框，提交失败保留草稿，重试成功才清空输入。
    @Test("写入失败回滚、提交草稿与本机文件监听")
    func writingAndDrafts() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-session-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let location = RepositoryLocation.local(path: directory.path)
        let runner = GitRunner(location: location, environment: .inherit.updating([
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_SYSTEM": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
        ]))
        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await runner.run(["config", "--local", "commit.gpgSign", "false"])
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.display(location)
        session.refresh()
        await session.refreshTask?.value

        // 不调用手动刷新，新增文件必须由真实 FSEvents 进入列表。
        try Data("new\n".utf8).write(to: directory.appending(path: "file"))
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))

        while session.status?.entries.isEmpty != false && .now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }

        let entry = try #require(session.status?.entries.first)
        let row = StatusRowID(path: entry.path, kind: entry.kind)
        session.selectedID = row
        session.selectedIDs = [row]
        let lock = directory.appending(path: ".git/index.lock")
        try Data().write(to: lock)
        session.stage([entry], staged: true)
        #expect(session.stagingOverrides[row] == true)
        #expect(session.isWriting)
        await session.writeTask?.value
        await session.refreshTask?.value
        #expect(session.stagingOverrides.isEmpty)
        #expect(session.status?.entries.first?.kind == .untracked)
        try FileManager.default.removeItem(at: lock)
        session.stage([entry], staged: true)
        await session.writeTask?.value
        await session.refreshTask?.value
        #expect(session.status?.entries.first?.hasStagedChanges == true)
        #expect(session.selectedID?.path == entry.path)
        #expect(session.selectedID?.kind == .tracked)

        let hooks = directory.appending(path: ".git/hooks")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: false)
        let hook = hooks.appending(path: "pre-commit")
        try Data("#!/bin/sh\nprintf 'hook rejected\\n' >&2\nexit 1\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
        session.commitSubject = "标题"
        session.commitBody = "正文"
        session.commit()
        await session.writeTask?.value
        await session.refreshTask?.value
        #expect(session.commitSubject == "标题")
        #expect(session.commitBody == "正文")
        #expect(try await runner.status().branch.oid == nil)
        try FileManager.default.removeItem(at: hook)
        session.commit()
        await session.writeTask?.value
        await session.refreshTask?.value
        #expect(session.commitSubject.isEmpty && session.commitBody.isEmpty)
        #expect(session.status?.entries.isEmpty == true)
        #expect(session.status?.branch.oid != nil)
    }

    /// 用户取消后必须释放界面写锁，日志保留取消状态并允许重新刷新。
    @Test("同步取消恢复可写状态并保留活动记录")
    func cancelSync() async throws {
        let status = try snapshot("file")
        let session = RepositorySession(loadStatus: { _ in status })
        let location = RepositoryLocation.local(path: "/temporary/cancel-" + UUID().uuidString)
        session.display(location)
        defer { session.close() }
        let (started, continuation) = AsyncStream<Void>.makeStream()
        session.performGit(
            { _, output in
                output(.standardError(Data("transferring\n".utf8)))
                continuation.yield(())
                continuation.finish()
                try await Task.sleep(for: .seconds(30))
            },
            title: "Fetch"
        )
        for await _ in started { break }
        #expect(session.isWriting)
        let task = try #require(session.writeTask)
        task.cancel()
        await task.value
        await session.refreshTask?.value
        #expect(!session.isWriting)
        #expect(session.canWrite)
        #expect(session.failure == nil)
        let activity = try #require(RepositoryActivities.shared.items.first { $0.repository == location })
        #expect(activity.state == "activity.cancelled")
        #expect(activity.log.contains("transferring"))
        #expect(activity.cancel == nil)
        RepositoryActivities.shared.items.removeAll { $0.repository == location }
    }

    /// 分支写入和提交后，History 与引用必须跟随真实 Git 更新。
    @Test("History 跨视图刷新、选择与关闭生命周期")
    func historyLifecycle() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "spooky-history-" + UUID().uuidString
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let location = RepositoryLocation.local(path: directory.path)
        let runner = GitRunner(
            location: location,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )
        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await runner.run(["config", "--local", "commit.gpgSign", "false"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.display(location)
        session.refresh()
        await session.refreshTask?.value
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))

        while session.history.commits.isEmpty && .now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        let commit = try #require(session.history.commits.first)
        session.history.selectedIDs = [commit.id]
        session.activeView = .history
        session.performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner)
                    .create(
                        name: "topic",
                        startingAt: commit.id,
                        track: false,
                        checkout: true
                    )
            },
            title: "Create Branch"
        )
        await session.writeTask?.value
        await session.refreshTask?.value

        while session.history.snapshot?.references.contains(where: { $0.id == "refs/heads/topic" }) != true
            && .now < deadline
        {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(session.status?.branch.head == "topic")
        #expect(session.history.snapshot?.references.contains(where: { $0.id == "refs/heads/topic" }) == true)
        #expect(session.history.selectedIDs == [commit.id])

        // 本地与上游各增加一个提交，History 必须同时显示两侧并正确标记归属。
        session.performGit(
            { runner, _ in
                _ = try await runner.run(["commit", "--allow-empty", "-m", "local"])
                try await RepositoryReferences(runner: runner).checkout("refs/heads/main")
                _ = try await runner.run(["commit", "--allow-empty", "-m", "upstream"])
                try await RepositoryReferences(runner: runner).checkout("refs/heads/topic")
                _ = try await runner.run(["branch", "--set-upstream-to=main", "topic"])
            },
            title: "Commit"
        )
        await session.writeTask?.value
        await session.refreshTask?.value
        session.history.selectedReference = "refs/heads/topic"
        let trackingDeadline = ContinuousClock.now.advanced(by: .seconds(5))

        while session.history.unpushed.isEmpty && .now < trackingDeadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        let local = try #require(session.history.commits.first { $0.subject == "local" })
        let upstream = try #require(session.history.commits.first { $0.subject == "upstream" })
        #expect(session.history.unpushed == [local.id])
        #expect(session.history.unpulled == [upstream.id])
        #expect(
            !session.history.unpushed.contains(commit.id) && !session.history.unpulled.contains(commit.id)
        )
        session.history.loadNextPage()
        session.close()
        try await Task.sleep(for: .milliseconds(50))
        #expect(session.history.snapshot == nil)
        #expect(session.history.commits.isEmpty)
        #expect(!session.history.isLoading)
        RepositoryActivities.shared.items.removeAll { $0.repository == location }
    }

    /// 同一仓库只允许一个明确的写操作：重复点击与另一个窗口都不能再启动写入，结束后统一恢复。
    @Test("同一仓库同一时间只有一个写操作")
    func singleWriter() async throws {
        let status = try snapshot("file")
        let location = RepositoryLocation.local(path: "/temporary/writer-" + UUID().uuidString)
        let first = RepositorySession(loadStatus: { _ in status })
        let second = RepositorySession(loadStatus: { _ in status })
        first.display(location)
        second.display(location)
        defer {
            first.close()
            second.close()
            RepositoryActivities.shared.items.removeAll { $0.repository == location }
        }

        var finished: [RepositoryLocation] = []
        first.onWriteFinished = { finished.append($0) }
        let (gate, release) = AsyncStream<Void>.makeStream()
        let started = first.performGit({ _, _ in for await _ in gate {} }, title: "Push")
        #expect(started)

        // 重复点击与另一个窗口的同类写入都被拒绝，界面据此禁用入口。
        let repeated = first.performGit({ _, _ in }, title: "Push")
        let concurrent = second.performGit({ _, _ in }, title: "Push")
        #expect(!repeated && !concurrent)
        #expect(!second.canWrite)
        #expect(RepositoryWriteLocks.shared.contains(location))

        release.finish()
        await first.writeTask?.value
        #expect(first.canWrite && second.canWrite)
        #expect(!RepositoryWriteLocks.shared.contains(location))
        #expect(finished == [location])
    }

    /// 切换仓库保存视图状态，切回时恢复主视图、提交草稿与选中文件。
    @Test("切回仓库恢复视图状态")
    func viewStateRestoration() async throws {
        let session = RepositorySession(loadStatus: { _ in try snapshot("file") })
        let first = RepositoryLocation.local(path: "/temporary/first-" + UUID().uuidString)
        let second = RepositoryLocation.local(path: "/temporary/second-" + UUID().uuidString)
        defer { session.close() }
        session.display(first)
        session.refresh()
        await session.refreshTask?.value
        session.activeView = .history
        session.commitSubject = "草稿标题"
        session.commitBody = "草稿正文"
        session.selectedID = StatusRowID(path: "file", kind: .untracked)

        session.display(second)
        #expect(session.activeView == .workingCopy)
        #expect(session.commitSubject.isEmpty && session.selectedID == nil)

        session.display(first)
        #expect(session.activeView == .history)
        #expect(session.commitSubject == "草稿标题" && session.commitBody == "草稿正文")
        #expect(session.selectedID?.path == "file")
    }

    /// 每个窗口最多 15 个仓库状态，超出时淘汰最久未使用的仓库。
    @Test("视图状态缓存淘汰最久未使用的仓库")
    func viewStateEviction() {
        var cache = RepositoryViewStateCache()
        let locations = (0..<16).map { RepositoryLocation.local(path: "/temporary/cache-\($0)") }

        for location in locations.prefix(15) {
            cache.store(RepositoryViewState(), for: location)
        }

        // 读取第一个仓库会把它移到最近使用，第 16 个仓库淘汰的是第二个。
        #expect(cache.state(for: locations[0]) != nil)
        cache.store(RepositoryViewState(), for: locations[15])
        #expect(cache.order.count == RepositoryViewStateCache.capacity)
        #expect(cache.state(for: locations[1]) == nil)
        #expect(cache.state(for: locations[0]) != nil)
        #expect(cache.state(for: locations[15]) != nil)
    }

    /// 刷新进行中收到的完整刷新不会被合并丢弃，本次结束后自动再读一次。
    @Test("完整刷新请求不会在刷新中丢失")
    func pendingFullRefresh() async throws {
        let source = ControlledStatusSource()
        var calls = source.calls.makeAsyncIterator()
        let session = RepositorySession(loadStatus: { _ in try await source.read() })
        defer { session.close() }
        session.display(.local(path: "/temporary/pending-" + UUID().uuidString))
        session.refresh()
        _ = await calls.next()
        session.refresh(full: true)
        #expect(await source.pendingCount == 1)

        await source.complete(.success(try snapshot("first.txt")))
        _ = await calls.next()
        await source.complete(.success(try snapshot("second.txt")))
        await session.refreshTask?.value
        #expect(session.status?.entries.first?.path == "second.txt")
        #expect(!session.isRefreshing)
    }

    /// 退出时取消并等待写入结束，写锁随之释放，不遗留后台任务。
    @Test("退出等待任务结束并释放写锁", .timeLimit(.minutes(1)))
    func shutdown() async throws {
        let status = try snapshot("file")
        let session = RepositorySession(loadStatus: { _ in status })
        let location = RepositoryLocation.local(path: "/temporary/shutdown-" + UUID().uuidString)
        session.display(location)
        defer { RepositoryActivities.shared.items.removeAll { $0.repository == location } }

        let (started, signal) = AsyncStream<Void>.makeStream()
        session.performGit(
            { _, _ in
                signal.yield()
                try await Task.sleep(for: .seconds(30))
            },
            title: "Fetch"
        )

        for await _ in started { break }
        let start = ContinuousClock.now
        await session.shutdown()
        #expect(start.duration(to: .now) < .seconds(5))
        #expect(session.repository == nil && session.writeTask == nil)
        #expect(!RepositoryWriteLocks.shared.contains(location))
        #expect(RepositoryActivities.shared.items.first { $0.repository == location }?.state == "activity.cancelled")
    }

    /// 菜单、工具栏、右键菜单与拖放共用的可用性规则随真实仓库状态与写入状态变化。
    @Test("统一的动作可用性规则", .timeLimit(.minutes(1)))
    func actionAvailability() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-rules-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let location = RepositoryLocation.local(path: directory.path)
        let runner = GitRunner(location: location, environment: .inherit.updating([
            "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
        ]))
        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await runner.run(["config", "--local", "commit.gpgSign", "false"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["remote", "add", "origin", directory.appending(path: "missing.git").path])
        try Data("new\n".utf8).write(to: directory.appending(path: "file"))

        let session = RepositorySession(makeRunner: { _ in runner })
        defer {
            session.close()
            RepositoryActivities.shared.items.removeAll { $0.repository == location }
        }
        session.display(location)
        session.refresh()
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))

        while (session.history.snapshot == nil || session.context == nil) && .now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        let entries = session.status?.entries ?? []
        #expect(session.canFetch && session.canPush && session.canPublish && session.canCreateBranch)
        #expect(!session.canPull && !session.canMerge && !session.canCheckout)
        #expect(session.canStage(entries) && !session.canUnstage(entries) && session.canDiscard(entries))
        #expect(!session.canStage([]) && !session.canResolve(entries))

        // 写入进行中所有写入口一起禁用，结束后恢复。
        let (gate, release) = AsyncStream<Void>.makeStream()
        session.performGit({ _, _ in for await _ in gate {} }, title: "Fetch")
        #expect(!session.canFetch && !session.canPush && !session.canCreateBranch && !session.canStage(entries))
        release.finish()
        await session.writeTask?.value
        #expect(session.canFetch)
    }
}

/// 测试快照经生产解析器生成，避免镜像实现中的状态构造逻辑。
private func snapshot(_ path: String) throws -> WorkingCopyStatus {
    try WorkingCopyStatus(porcelainV2: Data(
        "# branch.oid (initial)\0# branch.head main\0? \(path)\0".utf8
    ))
}

/// 由测试决定读取完成顺序，故意允许已取消任务继续收到响应。
private actor ControlledStatusSource {
    /// 每条读取开始后发出通知。
    let calls: AsyncStream<Void>

    /// 请求通知的写入端。
    private let continuation: AsyncStream<Void>.Continuation

    /// 等待响应的读取。
    private var pending: [CheckedContinuation<WorkingCopyStatus, Error>] = []

    /// 等待中的命令数量。
    var pendingCount: Int { pending.count }

    /// 创建测试专用的异步通知通道。
    init() {
        (calls, continuation) = AsyncStream<Void>.makeStream()
    }

    /// 挂起直到测试交付结果。
    func read() async throws -> WorkingCopyStatus {
        try await withCheckedThrowingContinuation {
            pending.append($0)
            continuation.yield(())
        }
    }

    /// 完成最早的读取请求。
    func complete(_ result: Result<WorkingCopyStatus, Error>) {
        pending.removeFirst().resume(with: result)
    }
}
