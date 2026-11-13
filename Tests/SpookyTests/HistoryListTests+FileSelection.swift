import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - FileSelection

extension HistoryListTests {
    /// 变更文件行的选区：单击、⇧ 单击、⌘ 单击、↑ ↓ 与 ⇧ ↑ ↓ 各自从哪一行开始、选到哪一行，变更集重读后去掉不在的文件。
    @Test("变更文件行的点选与方向键")
    func fileSelection() {
        let order = ["a", "b", "c", "d", "e"]

        // 还没有点过时，↓ 从第一行开始，↑ 从最后一行开始
        var down = ChangesetFileSelection()
        down.move(by: 1, extending: false, order: order)
        #expect(down.paths == ["a"])

        var up = ChangesetFileSelection()
        up.move(by: -1, extending: true, order: order)
        #expect(up.paths == ["e"])

        // 单击选中一行；⇧ 单击从这一行连续选到点中的行，再按 ⇧ 单击时从同一个锚点重新算
        var selection = ChangesetFileSelection()
        selection.click("b", extending: false, toggling: false, order: order)
        #expect(selection.paths == ["b"])

        selection.click("d", extending: true, toggling: false, order: order)
        #expect(selection.paths == ["b", "c", "d"])

        selection.click("a", extending: true, toggling: false, order: order)
        #expect(selection.paths == ["a", "b"])

        // ⌘ 单击只切换点中的那一行
        selection.click("d", extending: false, toggling: true, order: order)
        #expect(selection.paths == ["a", "b", "d"])

        selection.click("a", extending: false, toggling: true, order: order)
        #expect(selection.paths == ["b", "d"])

        // ↓ 从最近点中的行移到下一行，只选中它；⇧ ↓ ⇧ ↑ 从这一行连续选到移到的行
        selection.move(by: 1, extending: false, order: order)
        #expect(selection.paths == ["b"])

        selection.move(by: 1, extending: true, order: order)
        selection.move(by: 1, extending: true, order: order)
        #expect(selection.paths == ["b", "c", "d"])

        selection.move(by: -1, extending: true, order: order)
        selection.move(by: -1, extending: true, order: order)
        selection.move(by: -1, extending: true, order: order)
        #expect(selection.paths == ["a", "b"])

        // 到了第一行或最后一行就停在那里
        selection.move(by: -1, extending: false, order: order)
        #expect(selection.paths == ["a"])

        selection.click("e", extending: false, toggling: false, order: order)
        selection.move(by: 1, extending: false, order: order)
        #expect(selection.paths == ["e"])

        // 重读后锚点不在了：只留下仍在的文件，⇧ ↓ 按不带 ⇧ 从第一行开始
        selection.click("c", extending: false, toggling: true, order: order)
        #expect(selection.paths == ["c", "e"])

        var retained = selection.retaining(["a", "b", "e"])
        #expect(retained.paths == ["e"])

        retained.move(by: 1, extending: true, order: ["a", "b", "e"])
        #expect(retained.paths == ["a"])
    }

    /// 选中文件行不展开它，展开与 Expand All 不改选区，换选提交时选区清空。
    @Test("变更文件行的选区与展开分开")
    func fileSelectionLifecycle() async throws {
        let fixture = try await Self.makeSession(commits: ["a", "b", "c"])
        defer { fixture.close() }

        let history = fixture.session.history
        let commits = history.commits

        history.selectedIDs = [commits[1].id]
        await untilFinished { history.activeTasks }

        let order = history.changes.map(\.path)
        #expect(order == ["file.txt"])

        // 选中不展开
        history.fileSelection.click("file.txt", extending: false, toggling: false, order: order)
        #expect(history.fileSelection.paths == ["file.txt"])
        #expect(history.expandedPaths.isEmpty)

        // Expand All 展开与收起都不改选区
        history.expandAll(true)
        #expect(history.expandedPaths == ["file.txt"])
        #expect(history.fileSelection.paths == ["file.txt"])

        history.expandAll(false)
        #expect(history.fileSelection.paths == ["file.txt"])

        // 换选提交时清空
        history.selectedIDs = [commits[2].id]
        #expect(history.fileSelection == ChangesetFileSelection())

        await untilFinished { history.activeTasks }
    }
}
