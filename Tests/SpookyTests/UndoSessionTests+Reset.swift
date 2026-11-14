import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Reset

extension UndoSessionTests {
    /// 撤销重置时工作区有改动，先询问是否储藏：Abort 不撤销，记录留在栈里；Do Not Stash 直接回到重置前；
    /// Stash Changes 先储藏再回到重置前，储藏留在列表里，此后不能重做。
    @Test("撤销重置前询问储藏的三个选项")
    func resetUndoAsksToStash() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let runner = fixture.runner
        let root = try await fixture.head()
        let reset = AppLocalization.text("rewrite.reset")

        var requests: [StashRequest] = []
        session.onStashRequest = { requests.append($0) }

        // 第二个提交改了文件；soft 重置回 root 后改动留在暂存区
        try fixture.write("second\n")
        _ = try await runner.run(["commit", "-q", "-am", "second"])
        await fixture.refresh()

        let second = try await fixture.head()

        try await fixture.perform { session.reset(to: root, mode: .soft) }

        #expect(try await fixture.head() == root)

        // Abort：询问时还没有撤销，关掉询问后记录仍在栈顶
        session.undoLastOperation()

        let declined = try #require(Self.autoStash(requests.last))

        #expect(declined.error == nil && declined.keepsStash)
        #expect(!session.isWriting)
        #expect(try await Self.settledState(of: session, redo: false) == .available(reset))

        // Do Not Stash：直接回到重置前
        try await fixture.perform { session.declineAutoStash(declined) }

        #expect(try await fixture.head() == second)
        #expect(try fixture.read() == "second\n")
        #expect(try await Self.settledState(of: session, redo: true) == .available(reset))

        // 重做后再撤销，Stash Changes：先储藏再回到重置前，储藏留在列表里
        try await fixture.perform { session.redoLastOperation() }
        session.undoLastOperation()

        let accepted = try #require(Self.autoStash(requests.last))

        #expect(requests.count == 2)

        try await fixture.perform { session.performAutoStash(accepted, message: "auto", reapply: false) }

        let stashes = try await runner.run(["stash", "list"])

        #expect(try await fixture.head() == second)
        #expect(session.status?.entries.isEmpty ?? false)
        #expect(String(decoding: stashes, as: UTF8.self).split(separator: "\n").count == 1)

        // 储藏列表比撤销时记下的多出一项，重做不能回到重置后
        let redo = try await Self.settledState(of: session, redo: true)

        #expect(redo == .blocked(reset, reason: "undo.reason.changed"))
    }
}

// MARK: - Helpers

extension UndoSessionTests {
    /// 储藏请求里的自动储藏询问；不是自动储藏时为 nil。
    private static func autoStash(_ request: StashRequest?) -> AutoStashRequest? {
        guard case .autoStash(let pending) = request else {
            return nil
        }

        return pending
    }
}
