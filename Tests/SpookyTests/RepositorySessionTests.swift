import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositorySessionTests

/// 会话的刷新生命周期、写操作与视图状态：以受控响应验证旧数据保留和过期请求隔离。
@MainActor
struct RepositorySessionTests {
    /// 刷新中和失败后都保留快照，恢复成功后替换状态并保留仍存在的选区；刷新中再次请求不重复读取，完整刷新留到本次结束后补做。
    @Test("刷新保留旧数据、失败恢复、选区与刷新中的请求")
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

        // 失败时保留旧快照；刷新中再次请求不会发起第二条相同读取
        session.refresh()
        _ = await calls.next()
        let failingTask = session.refreshTask

        #expect(session.status == first)
        #expect(session.isRefreshing)

        session.refresh()
        #expect(await source.pendingCount == 1)

        await source.complete(.failure(StatusParseError(record: "broken record")))
        await failingTask?.value
        #expect(session.status == first)
        #expect(session.failure?.details == "broken record")
        #expect(!session.isRefreshing)

        // 恢复成功后清除错误，仍存在的文件继续选中
        session.refresh()
        _ = await calls.next()
        await source.complete(.success(first))
        await session.refreshTask?.value

        #expect(session.failure == nil)
        #expect(session.selectedID?.path == "first.txt")

        // 选中的文件不在新状态里时取消选择
        let second = try snapshot("second.txt")
        session.refresh()
        _ = await calls.next()
        await source.complete(.success(second))
        await session.refreshTask?.value

        #expect(session.status == second)
        #expect(session.selectedID == nil)

        // 刷新中收到的完整刷新不会被合并丢弃，本次结束后自动再读一次
        session.refresh()
        _ = await calls.next()
        session.refresh(full: true)

        #expect(await source.pendingCount == 1)

        await source.complete(.success(first))
        _ = await calls.next()
        await source.complete(.success(second))
        await session.refreshTask?.value

        #expect(session.status == second)
        #expect(!session.isRefreshing)
    }

    /// 切换仓库后，忽略取消的读取即使晚到也不能覆盖新结果；关闭仓库后迟到的结果同样丢弃。
    @Test("切换与关闭丢弃过期响应")
    func obsoleteResponses() async throws {
        let source = ControlledStatusSource()
        var calls = source.calls.makeAsyncIterator()
        let session = RepositorySession(loadStatus: { _ in try await source.read() })

        session.display(RepositoryLocation.local(path: "/temporary/first"))
        session.refresh()
        _ = await calls.next()

        let obsoleteTask = session.refreshTask

        // 切到第二个仓库后，第一个仓库的读取晚到也不写回
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

        // 关闭仓库时进行中的读取晚到也不写回
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

    /// 用户取消后释放界面写锁，记录保留取消状态并允许重新刷新；退出时取消并等待写入结束，写锁随之释放，不遗留后台任务。
    @Test("取消与退出结束写操作并释放写锁")
    func cancelAndShutdown() async throws {
        let status = try snapshot("file")
        let session = RepositorySession(loadStatus: { _ in status }, activities: RepositoryActivities())
        let location = RepositoryLocation.local(path: "/temporary/cancel-" + UUID().uuidString)

        session.display(location)
        defer { session.close() }

        // 取消：写操作开始后由用户取消
        let (gate, release) = AsyncStream<Void>.makeStream()
        defer { release.finish() }

        await startBlockingWrite(in: session, gate: gate)
        #expect(session.isWriting)

        let task = try #require(session.writeTask)
        task.cancel()
        await task.value
        await session.refreshTask?.value

        #expect(!session.isWriting)
        #expect(session.canWrite)
        #expect(session.failure == nil)

        // 写入结束后的完整刷新另记读取，按标题找到写操作的记录
        let activity = try #require(session.activities.items.first { $0.title == "Fetch" })
        #expect(activity.state == "activity.cancelled")
        #expect(activity.log.contains("transferring"))
        #expect(activity.cancel == nil)

        // 退出：进行中的写操作被取消，等它结束后才返回
        let (closing, finish) = AsyncStream<Void>.makeStream()
        defer { finish.finish() }

        await startBlockingWrite(in: session, gate: closing)
        await session.shutdown()

        #expect(session.repository == nil && session.writeTask == nil)
        #expect(!RepositoryWriteLocks.shared.contains(location))
        #expect(session.activities.items.first { $0.title == "Fetch" }?.state == "activity.cancelled")
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

    /// 切换仓库保存视图状态，切回时恢复主视图、提交草稿与选中文件，重复显示同一仓库保留现状；
    /// 子模块与工作树视图的目标不随仓库保存，切回时显示历史；每个窗口最多 15 个仓库状态，超出时淘汰最久未使用的仓库。
    @Test("切回仓库恢复视图状态与状态缓存的淘汰")
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

        // 重复显示同一仓库不重置视图、选区与状态
        session.display(first)

        #expect(session.activeView == .history)
        #expect(session.selectedID?.path == "file")
        #expect(session.status?.entries.count == 1)

        // 另一个仓库从默认的视图状态开始，切回时恢复
        session.display(second)

        #expect(session.activeView == .workingCopy)
        #expect(session.commitSubject.isEmpty && session.selectedID == nil)

        session.display(first)

        #expect(session.activeView == .history)
        #expect(session.commitSubject == "草稿标题" && session.commitBody == "草稿正文")
        #expect(session.selectedID?.path == "file")

        // 子模块与工作树视图切回仓库时显示历史，不留下没有选中项的空视图
        session.showSubmodule("lib")
        session.display(second)
        session.display(first)

        #expect(session.activeView == .history)
        #expect(session.submodules.selectedPath == nil)

        session.showWorktree("/temporary/worktree")
        session.display(second)
        session.display(first)

        #expect(session.activeView == .history)
        #expect(session.worktrees.selectedPath == nil)

        // 读取第一个仓库会把它移到最近使用，第 16 个仓库淘汰的是第二个
        var cache = RepositoryViewStateCache()
        let locations = (0 ..< 16).map { RepositoryLocation.local(path: "/temporary/cache-\($0)") }

        for location in locations.prefix(15) {
            cache.store(RepositoryViewState(), for: location)
        }

        #expect(cache.state(for: locations[0]) != nil)

        cache.store(RepositoryViewState(), for: locations[15])

        #expect(cache.order.count == RepositoryViewStateCache.capacity)
        #expect(cache.state(for: locations[1]) == nil)
        #expect(cache.state(for: locations[0]) != nil)
        #expect(cache.state(for: locations[15]) != nil)
    }
}

// MARK: - Helpers

extension RepositorySessionTests {
    /// 开始写操作 “Fetch”：先输出一行，再一直等闸门，闸门不放行时直到被取消才结束；等它真正开始后返回。
    ///
    /// - Parameters:
    ///   - session: 执行写操作的会话。
    ///   - gate: 写操作等待的闸门。
    private func startBlockingWrite(in session: RepositorySession, gate: AsyncStream<Void>) async {
        let (started, signal) = AsyncStream<Void>.makeStream()

        session.performGit(
            { _, output in
                output(.standardError(Data("transferring\n".utf8)))
                signal.finish()

                for await _ in gate { }
            },
            title: "Fetch"
        )

        for await _ in started { }
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
