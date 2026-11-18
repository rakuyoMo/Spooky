import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryWriteQueueTests

/// 仓库写队列：同一仓库的写操作按提交的先后一次执行一个，全部窗口共用；轮到时按刷新后的状态核对，
/// 等待中可以取消，执行中的失败取消后面排着的。动作只在测试里记下自己，不执行 Git。
@MainActor
struct RepositoryWriteQueueTests {
    /// 空闲时立即执行；正有写操作时，同一会话与同一仓库另一个会话提交的都排进同一条队列，入口不因忙而禁用；
    /// 前一项结束、两个会话刷新完才轮到下一项，核对读到的是写入之后的状态；等待中的记录开始后转为执行中。
    @Test("同一仓库的写操作排队，按先后一次执行一个")
    func queuedInOrder() async throws {
        let disk = StatusSource()
        let after = try Self.snapshot("after.txt")
        let location = RepositoryLocation.local(path: "/temporary/queue-" + UUID().uuidString)
        let activities = RepositoryActivities()
        let first = RepositorySession(loadStatus: { _ in await disk.status }, activities: activities)
        let second = RepositorySession(loadStatus: { _ in await disk.status }, activities: activities)

        defer {
            first.close()
            second.close()
        }

        for session in [first, second] {
            session.display(location)
            session.refresh()
            await session.waitForRefresh()
        }

        // 写操作结束时另一个窗口随之刷新，与窗口协调者的通知相同
        first.onWriteFinished = { _ in second.refresh(full: true) }
        second.onWriteFinished = { _ in first.refresh(full: true) }

        // 空闲时立即执行，动作停在中途
        let order = QueueRecorder()
        let (gate, release) = AsyncStream<Void>.makeStream()
        let (started, signal) = AsyncStream<Void>.makeStream()

        let accepted = first.performGit(
            { _, _ in
                await disk.set(after.entries)
                await order.append("first")
                signal.finish()

                for await _ in gate { }
            },
            title: "First"
        )

        #expect(accepted && first.isWriting)
        for await _ in started { }

        // 正有写操作时两个会话提交的都被接受，排进同一条队列，核对时记下会话读到的状态
        var seen: [[StatusEntry]?] = []

        let again = first.performGit(
            { _, _ in await order.append("again") },
            title: "Again",
            available: {
                seen.append(first.status?.entries)
                return true
            }
        )

        let other = second.performGit(
            { _, _ in await order.append("other") },
            title: "Other",
            available: {
                seen.append(second.status?.entries)
                return true
            }
        )

        #expect(again && other)
        #expect(second.canWrite && !second.isWriting)
        #expect(RepositoryWriteQueue.shared.hasUserWrite(in: location))
        #expect(await order.items == ["first"])

        let waiting = activities.items.filter { $0.state == "activity.waiting" }
        #expect(waiting.map(\.title) == ["Other", "Again"])

        // 放行后按提交的先后执行，都看到第一项写入之后刷新出的状态
        release.finish()
        await until { RepositoryWriteQueue.shared.isIdle(location) }
        await first.waitForRefresh()
        await second.waitForRefresh()

        #expect(await order.items == ["first", "again", "other"])
        #expect(seen == [after.entries, after.entries])
        #expect(waiting.allSatisfy { $0.state == "activity.finished" && $0.ended != nil })
        #expect(!first.isWriting && !second.isWriting)
    }

    /// 服务器仓库没连上时不接受写入：不执行、不排队、不留记录，调用方据此保留参数。
    @Test("服务器仓库没连上时不接受写入")
    func refusedWhileDisconnected() {
        let location = RepositoryLocation.remote(host: "spooky-test", path: "/srv/queue-" + UUID().uuidString)
        let activities = RepositoryActivities()
        let session = RepositorySession(loadStatus: { _ in throw CancellationError() }, activities: activities)

        session.display(location)
        defer { session.close() }

        let accepted = session.performGit({ _, _ in Issue.record("没连上时不执行") }, title: "Push")

        #expect(!session.canWrite && !accepted)
        #expect(RepositoryWriteQueue.shared.isIdle(location))
        #expect(activities.items.isEmpty)
    }

    /// 轮到时核对不通过的跳过并写明原因；等待中取消的不执行、撤回目标状态；停掉执行中的一项不影响后面的；
    /// 执行中的一项失败时后面排着的全部取消，写明是哪个操作失败。
    @Test("跳过、取消与失败后的队列")
    func skippedCancelledAndFailed() async throws {
        let location = RepositoryLocation.local(path: "/temporary/queue-" + UUID().uuidString)
        let activities = RepositoryActivities()
        let status = try Self.snapshot("file.txt")
        let session = RepositorySession(loadStatus: { _ in status }, activities: activities)

        session.display(location)
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        let order = QueueRecorder()

        try await skippedAndCancelled(in: session, activities: activities, order: order)
        try await stopped(in: session, activities: activities, order: order)
        try await failed(in: session, activities: activities, order: order)

        #expect(failures.count == 1)
        #expect(RepositoryWriteQueue.shared.isIdle(location))
    }
}

// MARK: - Ending

/// 断线、换仓库与退出时，排着的写操作取消，不再轮到。
extension RepositoryWriteQueueTests {
    /// 服务器仓库断开：排着的两项都取消，记录写明连接断开；执行中的一项照常结束，重连后排过的都不执行。
    @Test("服务器仓库断开时取消排着的写操作")
    func cancelledOnDisconnect() async throws {
        let location = RepositoryLocation.remote(host: "spooky-test", path: "/srv/queue-" + UUID().uuidString)
        let remote = try #require(RemoteConnection.forLocation(location))
        let activities = RepositoryActivities()
        let status = try Self.snapshot("file.txt")
        let session = RepositorySession(loadStatus: { _ in status }, activities: activities)

        // 连接状态由测试切换，不连服务器；先连上再打开仓库，会话订阅时读到的就是已连上
        await remote.updateState(.connected)
        session.display(location)
        defer { session.close() }

        await until { session.canWrite }

        let order = QueueRecorder()
        let release = await startBlocking(in: session, title: "First", order: order)

        for title in ["Again", "Other"] {
            let accepted = session.performGit({ _, _ in await order.append(title) }, title: title)
            #expect(accepted)
        }

        // 断开：排着的两项随连接状态的变化取消
        await remote.updateState(.reconnecting)
        await until { session.connectionState == .reconnecting }

        let queued = activities.items.filter { ["Again", "Other"].contains($0.title) }
        let reason = AppLocalization.text("queue.cancelledDisconnected")

        #expect(queued.count == 2)
        #expect(queued.allSatisfy { $0.state == "activity.cancelled" && $0.log.contains(reason) })

        // 重连后执行中的一项结束，没有别的轮到
        await remote.updateState(.connected)
        await until { session.canWrite }

        release.finish()
        await until { RepositoryWriteQueue.shared.isIdle(location) }

        #expect(await order.items == ["First"])
    }

    /// 同一仓库开在两个窗口里，各排一项；一个窗口换了仓库，只有它排着的一项取消，另一个窗口排着的照常执行。
    @Test("换仓库只取消本窗口排着的写操作")
    func cancelledOnClose() async throws {
        let location = RepositoryLocation.local(path: "/temporary/queue-" + UUID().uuidString)
        let activities = RepositoryActivities()
        let status = try Self.snapshot("file.txt")
        let first = RepositorySession(loadStatus: { _ in status }, activities: activities)
        let second = RepositorySession(loadStatus: { _ in status }, activities: activities)

        defer {
            first.close()
            second.close()
        }

        for session in [first, second] {
            session.display(location)
            session.refresh()
            await session.waitForRefresh()
        }

        let order = QueueRecorder()
        let release = await startBlocking(in: first, title: "First", order: order)

        let again = first.performGit({ _, _ in await order.append("Again") }, title: "Again")
        let other = second.performGit({ _, _ in await order.append("Other") }, title: "Other")

        #expect(again && other)

        // 换仓库与关窗走同一个收尾：第二个窗口排着的一项随即取消
        second.display(.local(path: "/temporary/queue-" + UUID().uuidString))
        #expect(activities.items.first { $0.title == "Other" }?.state == "activity.cancelled")

        release.finish()
        await until { RepositoryWriteQueue.shared.isIdle(location) }

        #expect(await order.items == ["First", "Again"])
    }

    /// 退出时排着的写操作都取消，撤回先显示的目标状态；执行中的一项结束后不再轮到任何一项。
    @Test("退出时排着的写操作不再执行")
    func cancelledOnQuit() {
        // 退出取消的是全部仓库排着的写操作，用单独的队列，不影响并行的其它测试
        let queue = RepositoryWriteQueue()
        let location = RepositoryLocation.local(path: "/temporary/queue-" + UUID().uuidString)
        let activities = RepositoryActivities()
        var withdrawn = false

        let running = RepositoryWrite(location: location, session: nil, title: "Running")

        let waiting = RepositoryWrite(
            location: location,
            session: nil,
            title: "Waiting",
            withdraw: { withdrawn = true }
        ) { _ in
            Issue.record("退出后不执行")
        }

        let record = RepositoryActivity(repository: location, title: "Waiting", target: nil)
        record.state = "activity.waiting"
        activities.insert(record)
        waiting.waiting = (record, activities)

        #expect(queue.begin(running))
        queue.enqueue(waiting)
        queue.cancelAllPending()

        #expect(withdrawn)
        #expect(record.state == "activity.cancelled")

        queue.finish(running)
        #expect(queue.isIdle(location))
    }
}

// MARK: - Steps

extension RepositoryWriteQueueTests {
    /// 核对不通过的一项记为已跳过，等待中取消的一项记为已取消并撤回；两项都不执行，排在后面的照常轮到。
    private func skippedAndCancelled(
        in session: RepositorySession,
        activities: RepositoryActivities,
        order: QueueRecorder
    ) async throws {
        let location = try #require(session.repository)
        let release = await startBlocking(in: session, title: "Hold", order: order)
        var withdrawn: [String] = []

        session.performGit(
            { _, _ in await order.append("skipped") },
            title: "Skipped",
            available: { false },
            withdrawn: { withdrawn.append("Skipped") }
        )

        session.performGit(
            { _, _ in await order.append("cancelled") },
            title: "Cancelled",
            withdrawn: { withdrawn.append("Cancelled") }
        )

        session.performGit({ _, _ in await order.append("next") }, title: "Next")

        // 在等待中取消：记录立即结束，不记失败
        let cancelled = try #require(activities.items.first { $0.title == "Cancelled" })
        cancelled.cancel?()

        #expect(cancelled.state == "activity.cancelled")
        #expect(withdrawn == ["Cancelled"])

        release.finish()
        await until { RepositoryWriteQueue.shared.isIdle(location) }
        await session.waitForRefresh()

        let skipped = try #require(activities.items.first { $0.title == "Skipped" })

        #expect(await order.items == ["Hold", "next"])
        #expect(skipped.state == "activity.skipped")
        #expect(skipped.log.contains(AppLocalization.text("queue.notRun")))
        #expect(withdrawn == ["Cancelled", "Skipped"])
    }

    /// 停掉执行中的一项只停这一个，排在后面的照常执行。
    private func stopped(in session: RepositorySession, activities: RepositoryActivities, order: QueueRecorder) async throws {
        let location = try #require(session.repository)
        let release = await startBlocking(in: session, title: "Stopped", order: order)
        defer { release.finish() }

        session.performGit({ _, _ in await order.append("after stop") }, title: "After Stop")

        let stopped = try #require(activities.items.first { $0.title == "Stopped" })
        stopped.cancel?()

        await until { RepositoryWriteQueue.shared.isIdle(location) }
        await session.waitForRefresh()

        #expect(await order.items.suffix(2) == ["Stopped", "after stop"])
        #expect(stopped.state == "activity.cancelled")
    }

    /// 执行中的一项失败：排在后面的两项都取消、都不执行，输出写明失败的操作。
    private func failed(in session: RepositorySession, activities: RepositoryActivities, order: QueueRecorder) async throws {
        let location = try #require(session.repository)
        let (gate, release) = AsyncStream<Void>.makeStream()
        let (started, signal) = AsyncStream<Void>.makeStream()

        session.performGit(
            { _, _ in
                signal.finish()

                for await _ in gate { }
                throw CocoaError(.fileWriteUnknown)
            },
            title: "Broken"
        )

        for await _ in started { }

        for title in ["Later 1", "Later 2"] {
            session.performGit({ _, _ in await order.append(title) }, title: title)
        }

        let count = await order.items.count
        release.finish()

        await until { RepositoryWriteQueue.shared.isIdle(location) }
        await session.waitForRefresh()

        let later = activities.items.filter { $0.title.hasPrefix("Later") }
        let reason = AppLocalization.text("queue.cancelledAfterFailure", "Broken")

        #expect(await order.items.count == count)
        #expect(activities.items.first { $0.title == "Broken" }?.state == "activity.failed")
        #expect(later.count == 2)
        #expect(later.allSatisfy { $0.state == "activity.cancelled" && $0.log.contains(reason) })
    }
}

// MARK: - Helpers

extension RepositoryWriteQueueTests {
    /// 测试快照经生产解析器生成，只有一个未跟踪文件。
    private static func snapshot(_ path: String) throws -> WorkingCopyStatus {
        try WorkingCopyStatus(porcelainV2: Data(
            "# branch.oid (initial)\0# branch.head main\0? \(path)\0".utf8
        ))
    }

    /// 开始一个停在中途的写操作，等它的动作开始后返回放行的入口；动作开始时记下标题。
    private func startBlocking(
        in session: RepositorySession,
        title: String,
        order: QueueRecorder
    ) async -> AsyncStream<Void>.Continuation {
        let (gate, release) = AsyncStream<Void>.makeStream()
        let (started, signal) = AsyncStream<Void>.makeStream()

        let accepted = session.performGit(
            { _, _ in
                await order.append(title)
                signal.finish()

                for await _ in gate { }
            },
            title: title
        )

        #expect(accepted)
        for await _ in started { }

        return release
    }
}

// MARK: - QueueRecorder

/// 按执行的先后记下动作。
private actor QueueRecorder {
    /// 已执行的动作。
    private(set) var items: [String] = []

    /// 记下一个动作。
    func append(_ item: String) {
        items.append(item)
    }
}
