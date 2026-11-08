import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

extension UndoSessionTests {
    /// 会话按行入口的撤销采样只写对象库，成功与拒绝都保留旧路径的新占用者。
    @Test("会话补丁与撤销采样保护独立旧文件", arguments: ["unstage", "discard", "stale"])
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

        // 改名后的文件暂存一处改动、工作区再改一处，旧路径上另放一个未跟踪的二进制文件
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

        // 选中改名的文件，按操作切到对应的一侧，等 Diff 读完
        let row = StatusRowID(path: entry.path, kind: entry.kind)
        session.selectedID = row
        session.selectedIDs = [row]
        session.diffSide = action == "unstage" ? .staged : .unstaged
        session.diffSideChanged()
        await until { !session.isLoadingDiff }

        let snapshot = try #require(session.diffSnapshot)
        let hunk = try #require(snapshot.diff?.files.first?.hunks.first)
        #expect(snapshot.side == session.diffSide)

        var failures = 0
        session.onFailure = { _ in failures += 1 }
        session.onConfirm = { $0.action() }

        // 直接核对撤销采样的原文，再经过会话实际登记路径执行补丁。
        let capture = try await RepositoryUndo(runner: fixture.runner).capture()

        #expect(capture.index != capture.worktree)
        #expect(try Data(contentsOf: independent) == protected)

        let changedProtected = protected + Data([1, 2, 3])
        try changedProtected.write(to: independent)

        if action == "stale" {
            try Data("external target\n".utf8).write(to: target)
        }

        try await fixture.perform {
            session.apply(file: 0, hunk: hunk.id, lines: [], discard: action == "discard")
        }

        // 旧路径上的文件逐字节不变，索引与工作区按操作的结果变化
        let expectedIndex = action == "unstage" ? base : staged
        let expectedWorking =
            switch action {
            case "discard": staged
            case "stale": "external target\n"
            default: working
            }

        let status = try await fixture.runner.status()

        #expect(failures == (action == "stale" ? 1 : 0))
        #expect(try Data(contentsOf: independent) == changedProtected)
        #expect(status.entries.contains { $0.path == "a b.txt" && $0.kind == .untracked })
        #expect(try await fixture.runner.run(["show", ":new.txt"]) == Data(expectedIndex.utf8))
        #expect(try Data(contentsOf: target) == Data(expectedWorking.utf8))
    }
}
