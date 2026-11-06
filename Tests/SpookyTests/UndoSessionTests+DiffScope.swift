import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

extension UndoSessionTests {
    /// 会话按行入口的撤销采样只写对象库，成功与拒绝都保留旧路径的新占用者。
    @Test("会话补丁与撤销采样保护独立旧文件", arguments: ["stage", "unstage", "discard", "invalid", "stale"])
    func independentRenamePath(action: String) async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let base = (1 ... 12).map { "line \($0)\n" }.joined()
        let staged = base.replacingOccurrences(of: "line 2\n", with: "changed 2\n")
        let working = staged.replacingOccurrences(of: "line 10\n", with: "changed 10\n")
        try fixture.write(base)
        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-qm", "base lines"])
        let target = fixture.directory.appending(path: "new.txt")
        try FileManager.default.moveItem(at: fixture.directory.appending(path: "a b.txt"), to: target)
        try Data(staged.utf8).write(to: target)
        _ = try await fixture.runner.run(["add", "--all"])
        try Data(working.utf8).write(to: target)
        let protected = Data([0, 0xFE, 0xFF, 10])
        let independent = fixture.directory.appending(path: "a b.txt")
        try protected.write(to: independent)
        await fixture.refresh()
        let entry = try #require(session.status?.entries.first { $0.path == "new.txt" })
        #expect(entry.originalPath == "a b.txt")
        let row = StatusRowID(path: entry.path, kind: entry.kind)
        session.selectedID = row
        session.selectedIDs = [row]
        session.diffSide = action == "unstage" ? .staged : .unstaged
        session.diffSideChanged()
        try await FileViewsTests.wait { session.diffSnapshot?.side == session.diffSide }
        let snapshot = try #require(session.diffSnapshot)
        let hunk = try #require(snapshot.diff?.files.first?.hunks.first)
        var failures = 0
        session.onFailure = { _ in failures += 1 }
        session.onConfirm = { $0.action() }

        // 直接核对撤销采样的原文，再经过会话实际登记路径执行补丁。
        let capture = try await RepositoryUndo(runner: fixture.runner).capture()
        #expect(capture.index != capture.worktree)
        #expect(try Data(contentsOf: independent) == protected)
        let changedProtected = protected + Data([1, 2, 3])
        try changedProtected.write(to: independent)
        if action == "stale" { try Data("external target\n".utf8).write(to: target) }

        try await fixture.perform {
            session.apply(
                file: 0,
                hunk: hunk.id,
                lines: action == "invalid" ? [999] : [],
                discard: action == "discard"
            )
        }

        let rejected = action == "invalid" || action == "stale"
        #expect(failures == (rejected ? 1 : 0))
        #expect(try Data(contentsOf: independent) == changedProtected)
        #expect(try await fixture.runner.status().entries.contains { $0.path == "a b.txt" && $0.kind == .untracked })
        let expectedIndex = action == "stage" ? working : (action == "unstage" ? base : staged)
        let expectedWorking = action == "discard" ? staged : (action == "stale" ? "external target\n" : working)
        #expect(try await fixture.runner.run(["show", ":new.txt"]) == Data(expectedIndex.utf8))
        #expect(try Data(contentsOf: target) == Data(expectedWorking.utf8))
    }
}
