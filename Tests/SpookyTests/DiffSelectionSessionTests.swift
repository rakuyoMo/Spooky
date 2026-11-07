import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 经过真实会话加载和写队列验证选择的生命周期，不创建窗口或 sheet。
@MainActor
@Suite(.serialized)
struct DiffSelectionSessionTests {
    /// 外部只改另一块时保留第一块；自动换侧和关闭则退役旧模型。
    @Test("会话刷新保留未变块并隔离侧与关闭")
    func refreshing() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        try await prepare(fixture)
        let session = fixture.session
        let first = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        let second = try #require(session.diffSelections.selection(file: 0, hunk: 1))
        first.activate(at: try #require(first.rows.firstIndex { $0 != nil }))
        second.activate(at: try #require(second.rows.firstIndex { $0 != nil }))
        let chosen = first.selected
        let anchor = first.anchor
        let fingerprint = session.diffSnapshot?.fingerprint
        try fixture.write(try fixture.read().replacingOccurrences(of: "changed 180", with: "changed again 180"))
        await fixture.refresh()
        try await FileViewsTests.wait { !session.isLoadingDiff && session.diffSnapshot?.fingerprint != fingerprint }
        #expect(session.diffSelections.selection(file: 0, hunk: 0) === first)
        #expect(first.selected == chosen && first.anchor == anchor)
        #expect(!second.isActive)

        _ = try await fixture.runner.run(["add", "--all"])
        await fixture.refresh()
        try await FileViewsTests.wait { !session.isLoadingDiff && session.diffSnapshot?.side == .staged }
        #expect(session.diffSide == .staged && !first.isActive)
        let staged = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        staged.activate(at: try #require(staged.rows.firstIndex { $0 != nil }))
        session.close()
        #expect(!staged.isActive && staged.selected.isEmpty)
        #expect(session.diffSelections.scope == nil)
        session.display(fixture.location)
        await fixture.refresh()
        #expect(!staged.isActive)
    }

    /// 当前有效主题变化仅在着色开启时重置；阈值重读不收回用户的 Show Diff 放行。
    @Test("会话主题与阈值重置选择")
    func settings() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        try await prepare(fixture)
        let session = fixture.session
        let initial = TextTheme.builtin[0]
        var edited = initial
        edited.fontSize += 1
        session.diffAppearanceChanged(DiffSelectionAppearance(theme: initial, colorsSyntax: false))
        let old = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        old.activate(at: try #require(old.rows.firstIndex { $0 != nil }))
        session.diffAppearanceChanged(DiffSelectionAppearance(theme: edited, colorsSyntax: false))
        session.diffAppearanceChanged(DiffSelectionAppearance(theme: edited, colorsSyntax: true))
        #expect(!old.selected.isEmpty && old.isActive)
        session.diffAppearanceChanged(DiffSelectionAppearance(theme: initial, colorsSyntax: true))
        #expect(!old.isActive && old.selected.isEmpty)
        let current = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        current.activate(at: try #require(current.rows.firstIndex { $0 != nil }))
        session.showsLargeDiff = true
        session.diffWarningThresholdChanged()
        #expect(session.showsLargeDiff && !current.isActive)
        try await FileViewsTests.wait { !session.isLoadingDiff }
        #expect(session.diffSnapshot?.diff != nil)
        #expect(session.diffSelections.selection(file: 0, hunk: 0)?.selected.isEmpty ?? false)
    }

    /// 动作入队后立即清空发起块，未变的另一块保持；核心仍核对旧快照。
    @Test("会话接受按行操作只清发起块", arguments: ["stage", "unstage", "discard", "stale"])
    func accepted(action: String) async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        try await prepare(fixture, staged: action == "unstage")
        let session = fixture.session
        session.onConfirm = { $0.action() }
        var failures = 0
        session.onFailure = { _ in failures += 1 }
        let first = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        let second = try #require(session.diffSelections.selection(file: 0, hunk: 1))
        first.activate(at: try #require(first.rows.firstIndex { $0 != nil }))
        second.activate(at: try #require(second.rows.firstIndex { $0 != nil }))
        let other = second.selected

        // 配对增删不移动后块头的行号，后块原文才能保持完全相同。
        for (index, id) in first.rows.enumerated() {
            if let id, !first.selected.contains(id) { first.activate(at: index) }
        }
        let lines = first.selected
        if action == "stale" { try fixture.write("externally changed\n") }
        session.apply(file: 0, hunk: 0, lines: lines, discard: action == "discard")
        #expect(first.selected.isEmpty && first.anchor == nil)
        #expect(second.selected == other)
        await session.writeTask?.value
        await session.waitForRefresh()
        try await FileViewsTests.wait { !session.isLoadingDiff }
        #expect(failures == (action == "stale" ? 1 : 0))
        if action == "stale" {
            #expect(try fixture.read() == "externally changed\n")
        } else {
            #expect(session.diffSelections.selection(file: 0, hunk: 0) === second)
            #expect(second.selected == other)
        }
    }

    /// 延迟确认期间取消、写锁拒绝或切走再切回，都不能清掉当前范围。
    @Test("确认取消与拒绝保留选择且旧确认不误清新范围")
    func confirmations() async throws {
        let defaults = UserDefaults.standard
        let saved = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        var arguments = saved
        arguments[ServerConfirmation.discardChunks.key] = true
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(saved, forName: UserDefaults.argumentDomain) }
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }
        try await prepare(fixture)
        let session = fixture.session
        var request: ConfirmationRequest? = nil
        session.onConfirm = { request = $0 }
        let selection = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        selection.activate(at: try #require(selection.rows.firstIndex { $0 != nil }))
        let selected = selection.selected
        session.apply(file: 0, hunk: 0, lines: selected, discard: true)
        let confirmation = try #require(request)
        #expect(selection.selected == selected && !session.isWriting)
        #expect(RepositoryWriteLocks.shared.acquire(fixture.location))
        confirmation.action()
        #expect(selection.selected == selected && !session.isWriting)
        RepositoryWriteLocks.shared.release(fixture.location)
        let row = session.selectedID
        session.selectedID = nil
        session.selectedID = row
        try await FileViewsTests.wait { !session.isLoadingDiff }
        let current = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        current.activate(at: try #require(current.rows.firstIndex { $0 != nil }))
        let chosen = current.selected
        confirmation.action()
        #expect(current.selected == chosen)
        await session.writeTask?.value
        await session.waitForRefresh()
    }

    /// 在隔离仓库生成两个相距足够远的修改块，再通过会话选择文件。
    func prepare(_ fixture: UndoSessionTests.Fixture, staged: Bool = false) async throws {
        let base = (1 ... 200).map { "line \($0)\n" }.joined()
        try fixture.write(base)
        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-qm", "two blocks"])
        try fixture.write(
            base.replacingOccurrences(of: "line 10\n", with: "changed 10\n")
                .replacingOccurrences(of: "line 180\n", with: "changed 180\n")
        )
        if staged { _ = try await fixture.runner.run(["add", "--all"]) }
        await fixture.refresh()
        let session = fixture.session
        let entry = try #require(session.status?.entries.first { $0.path == "a b.txt" })
        session.selectedID = StatusRowID(path: entry.path, kind: entry.kind)
        session.showsLargeDiff = true
        session.loadDiff()
        try await FileViewsTests.wait { !session.isLoadingDiff && session.diffSnapshot?.diff != nil }
        #expect(session.diffSnapshot?.diff?.files.first?.hunks.count == 2)
    }
}
