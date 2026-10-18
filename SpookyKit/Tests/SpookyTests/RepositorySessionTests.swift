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
        let session = RepositorySession { _ in try await source.read() }
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
        let session = RepositorySession { _ in try await source.read() }
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
        let session = RepositorySession { _ in try snapshot("file") }
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
