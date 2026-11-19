import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - QueuedCheckout

extension SidebarSessionTests {
    /// 仓库正被占用时：各入口的规则照常可用；检出的确认在点的时候出现一次，确认后排队，轮到时有已跟踪的修改才询问储藏，
    /// 中止询问后记为取消、后面的接着执行；轮到时已进入合并的检出跳过，不执行 Git。
    ///
    /// 接在双击的核对之后：HEAD 在 other 上，a.txt 有已跟踪的修改。
    ///
    /// - Parameters:
    ///   - session: 显示这个仓库的会话。
    ///   - runner: 仓库的 Git。
    ///   - directory: 仓库的工作区。
    func checkQueuedCheckout(in session: RepositorySession, runner: GitRunner, directory: URL) async throws {
        let location = RepositoryLocation.local(path: directory.path)

        try checkBusyRules(in: session, location: location)
        try await checkStashAtTurn(in: session, runner: runner, location: location)
        try await checkSkippedAtTurn(in: session, runner: runner, location: location, directory: directory)
    }
}

// MARK: - Private

extension SidebarSessionTests {
    /// 另一个写操作占着仓库时，检出、合并、拉取、推送、新建分支、删除分支与储藏的入口都可用。
    private func checkBusyRules(in session: RepositorySession, location: RepositoryLocation) throws {
        let holder = RepositoryWrite(location: location, session: nil, title: "Hold")
        #expect(RepositoryWriteQueue.shared.begin(holder))
        defer { RepositoryWriteQueue.shared.finish(holder) }

        let branches = session.history.branches
        let main = try #require(branches.first { $0.id == "refs/heads/main" })
        let blocked = try #require(branches.first { $0.id == "refs/heads/blocked" })

        #expect(session.canCheckout(main))
        #expect(session.canMerge(main))
        #expect(session.canPull)
        #expect(session.canPush)
        #expect(session.canCreateBranch)
        #expect(session.canDelete([blocked]))
        #expect(session.canStash(session.status?.entries ?? []))
    }

    /// 检出远端分支到不跟踪它的同名本地分支：确认在点的时候出现，确认后排队，点的时候不询问储藏；
    /// 轮到时因为有已跟踪的修改，带着轮次询问，询问期间不算执行中，后面排着的不开始；中止后检出记为取消，后面的接着执行，确认不再出现。
    private func checkStashAtTurn(
        in session: RepositorySession,
        runner: GitRunner,
        location: RepositoryLocation
    ) async throws {
        _ = try await runner.run(["branch", "solo", "main"])
        _ = try await runner.run(["update-ref", "refs/remotes/origin/solo", "main"])
        session.refresh(full: true)
        await settle(session)

        var confirmations: [ConfirmationRequest] = []
        var requests: [AutoStashRequest] = []
        session.onConfirm = { confirmations.append($0) }

        session.onStashRequest = {
            if case .autoStash(let request) = $0 { requests.append(request) }
        }

        let holder = RepositoryWrite(location: location, session: nil, title: "Hold")
        #expect(RepositoryWriteQueue.shared.begin(holder))

        // 确认在点的时候出现，确认后排进队列
        let remote = try #require(session.history.snapshot?.references.first { $0.id == "refs/remotes/origin/solo" })
        session.doubleClick(remote, in: .currentWindow) { Issue.record("正在写入时不响铃") }

        try #require(confirmations.count == 1)
        confirmations[0].action()

        let checkout = try #require(session.activities.items.first { $0.state == "activity.waiting" })
        #expect(requests.isEmpty)

        session.performGit({ _, _ in }, title: "After", touchesWorkingCopy: false)
        let after = try #require(session.activities.items.first { $0.title == "After" })

        // 轮到时询问储藏，占着轮次
        RepositoryWriteQueue.shared.finish(holder)
        await until { !requests.isEmpty }
        let turn = try #require(requests.first?.turn)

        #expect(RepositoryWriteQueue.shared.executing(in: location) == nil)
        #expect(checkout.state == "activity.waiting")
        #expect(after.state == "activity.waiting")

        // 中止询问：检出取消，后面的接着执行
        RepositoryWriteQueue.shared.cancel(turn)
        #expect(checkout.state == "activity.cancelled")

        await until { after.state == "activity.finished" }
        await settle(session)

        #expect(confirmations.count == 1)
        #expect(session.status?.branch.head == "other")
    }

    /// 排着的检出在等待期间仓库进入了合并：轮到时核对不通过，记为已跳过并写明原因，不询问储藏，HEAD 不变。
    private func checkSkippedAtTurn(
        in session: RepositorySession,
        runner: GitRunner,
        location: RepositoryLocation,
        directory: URL
    ) async throws {
        session.onStashRequest = { _ in Issue.record("跳过的检出不询问储藏") }

        let holder = RepositoryWrite(location: location, session: nil, title: "Hold")
        #expect(RepositoryWriteQueue.shared.begin(holder))

        let main = try #require(session.history.branches.first { $0.id == "refs/heads/main" })
        session.doubleClick(main, in: .currentWindow) { Issue.record("正在写入时不响铃") }

        let checkout = try #require(session.activities.items.first { $0.state == "activity.waiting" })

        // 等待期间进入合并，写操作结束时的刷新读出它
        let head = try await runner.run(["rev-parse", "HEAD"])
        let mergeHead = directory.appending(path: ".git/MERGE_HEAD")
        try head.write(to: mergeHead)
        defer { try? FileManager.default.removeItem(at: mergeHead) }

        session.refresh(full: true)
        RepositoryWriteQueue.shared.finish(holder)
        await until { checkout.state != "activity.waiting" }

        #expect(checkout.state == "activity.skipped")
        #expect(checkout.log.contains(AppLocalization.text("queue.notRun")))
        #expect(session.context?.operation != nil)
        #expect(session.status?.branch.head == "other")
    }
}
