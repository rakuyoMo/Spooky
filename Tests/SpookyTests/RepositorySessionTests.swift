import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositorySessionTests

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
        let started = first.performGit({ _, _ in for await _ in gate { } }, title: "Push")
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
        let locations = (0 ..< 16).map { RepositoryLocation.local(path: "/temporary/cache-\($0)") }

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
    @Test("退出等待任务结束并释放写锁", .timeLimit(.minutes(5)))
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
}

/// 测试快照经生产解析器生成，避免镜像实现中的状态构造逻辑。
private func snapshot(_ path: String) throws -> WorkingCopyStatus {
    try WorkingCopyStatus(porcelainV2: Data(
        "# branch.oid (initial)\0# branch.head main\0? \(path)\0".utf8
    ))
}

// MARK: - ControlledStatusSource

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

// MARK: - RepositorySession

extension RepositorySession {
    /// 等刷新全部结束：本机仓库的文件监听会在写入后另起刷新，其间要求的完整刷新排在它之后，只等当前的任务会读到旧状态。
    func waitForRefresh() async {
        while let task = refreshTask {
            await task.value
        }
    }
}
