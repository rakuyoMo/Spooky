import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Background

/// 撤销遇上不由用户直接发起的写操作：只有自动获取在执行时照样可以撤销，撤销排进来时它停下让路。
extension UndoSessionTests {
    /// 自动获取执行期间撤销菜单可用；撤销排进来后菜单不可用，自动获取停下，记录写明让给了撤销、记为取消，撤销随后执行。
    @Test("只有自动获取在执行时可以撤销")
    func undoDuringBackgroundWrite() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        try await fixture.createBranch("topic")

        // 后台写操作一直执行到被取消
        let (held, continuation) = AsyncStream<Void>.makeStream()
        defer { continuation.finish() }

        let title = AppLocalization.text("sync.autoFetch")

        let accepted = session.performGit(
            { _, _ in
                for await _ in held { }
                try Task.checkCancellation()
            },
            title: title,
            background: true,
            touchesWorkingCopy: false,
            undo: .unrecorded
        )

        // 撤销不可用时后面的撤销不会开始，这里就停下
        #expect(accepted)
        try #require(session.undoMenuState(redo: false) == .available("Branch"))

        // 撤销排在执行中的自动获取后面，排着的时候不能再撤销
        session.undoLastOperation()
        #expect(session.undoMenuState(redo: false) == .blocked("Branch", reason: "undo.reason.busy"))

        await until { RepositoryWriteQueue.shared.isIdle(fixture.location) }
        await fixture.refresh()

        // 自动获取记为取消并写明让给了撤销；撤销删掉了分支
        let record = session.activities.items.first {
            $0.repository == fixture.location && $0.title == title
        }

        let undo = UndoManager().undoMenuTitle(forUndoActionName: "Branch")

        #expect(record?.state == "activity.cancelled")
        #expect(record?.log.contains(AppLocalization.text("sync.autoFetch.yielded", undo)) ?? false)
        #expect(!Self.hasBranch("topic", in: session))
    }
}
