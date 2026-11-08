import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - DiffSelectionSessionTests

/// 经过真实会话加载和写队列验证选择的生命周期，不创建窗口或 sheet。
@MainActor
@Suite(.serialized)
struct DiffSelectionSessionTests {
    /// 有效主题只在着色开启时重置选择，阈值重读不收回 Show Diff 放行；外部只改另一块时保留第一块，自动换侧和关闭则退役旧模型。
    @Test("会话主题、阈值与刷新对选择的保留")
    func refreshing() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        try await prepare(fixture)
        let session = fixture.session
        try await expectSettings(session)

        // 外部只改第二块
        let first = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        let second = try #require(session.diffSelections.selection(file: 0, hunk: 1))
        try activateFirstRow(first)
        try activateFirstRow(second)
        let chosen = first.selected
        let anchor = first.anchor
        let fingerprint = session.diffSnapshot?.fingerprint

        try fixture.write(try fixture.read().replacingOccurrences(of: "changed 180", with: "changed again 180"))
        await fixture.refresh()
        await until { !session.isLoadingDiff && session.diffSnapshot?.fingerprint != fingerprint }
        #expect(session.diffSelections.selection(file: 0, hunk: 0) === first)
        #expect(first.selected == chosen && first.anchor == anchor)
        #expect(!second.isActive)

        // 全部暂存后自动换到已暂存一侧
        _ = try await fixture.runner.run(["add", "--all"])
        await fixture.refresh()
        await until { !session.isLoadingDiff && session.diffSnapshot?.side == .staged }
        #expect(session.diffSide == .staged && !first.isActive)

        // 关闭后重新打开不复活旧模型
        let staged = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        try activateFirstRow(staged)
        session.close()
        #expect(!staged.isActive && staged.selected.isEmpty)
        #expect(session.diffSelections.scope == nil)

        session.display(fixture.location)
        await fixture.refresh()
        #expect(!staged.isActive)
    }

    /// 动作入队后立即清空发起块，未变的另一块保持；核心仍核对旧快照。
    @Test("会话接受按行操作只清发起块", arguments: ["stage", "discard", "stale"])
    func accepted(action: String) async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        try await prepare(fixture)
        let session = fixture.session
        session.onConfirm = { $0.action() }

        var failures = 0
        session.onFailure = { _ in failures += 1 }

        let first = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        let second = try #require(session.diffSelections.selection(file: 0, hunk: 1))
        try activateFirstRow(first)
        try activateFirstRow(second)
        let other = second.selected

        // 配对增删不移动后块头的行号，后块原文才能保持完全相同
        for (index, id) in first.rows.enumerated() {
            if let id, !first.selected.contains(id) {
                first.activate(at: index)
            }
        }

        if action == "stale" {
            try fixture.write("externally changed\n")
        }

        session.apply(file: 0, hunk: 0, lines: first.selected, discard: action == "discard")
        #expect(first.selected.isEmpty && first.anchor == nil)
        #expect(second.selected == other)

        await session.writeTask?.value
        await session.waitForRefresh()
        await until { !session.isLoadingDiff }
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
        // 丢弃确认只读标准偏好，本测试打开它，结束时还原
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
        try activateFirstRow(selection)
        let selected = selection.selected
        session.apply(file: 0, hunk: 0, lines: selected, discard: true)

        let confirmation = try #require(request)
        #expect(selection.selected == selected && !session.isWriting)

        // 写锁被占用时确认被拒绝
        #expect(RepositoryWriteLocks.shared.acquire(fixture.location))
        confirmation.action()
        #expect(selection.selected == selected && !session.isWriting)
        RepositoryWriteLocks.shared.release(fixture.location)

        // 切走再切回后，旧确认不能清掉新范围
        let row = session.selectedID
        session.selectedID = nil
        session.selectedID = row
        await until { !session.isLoadingDiff }

        let current = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        try activateFirstRow(current)
        let chosen = current.selected
        confirmation.action()
        #expect(current.selected == chosen)

        await session.writeTask?.value
        await session.waitForRefresh()
    }

    /// 在隔离仓库生成两个相距足够远的修改块，再通过会话选择文件。
    func prepare(_ fixture: UndoSessionTests.Fixture) async throws {
        let base = (1 ... 200).map { "line \($0)\n" }.joined()
        try fixture.write(base)
        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-qm", "two blocks"])

        try fixture.write(
            base.replacingOccurrences(of: "line 10\n", with: "changed 10\n")
                .replacingOccurrences(of: "line 180\n", with: "changed 180\n")
        )

        await fixture.refresh()
        let session = fixture.session
        let entry = try #require(session.status?.entries.first { $0.path == "a b.txt" })
        session.selectedID = StatusRowID(path: entry.path, kind: entry.kind)
        session.showsLargeDiff = true
        session.loadDiff()

        await until { !session.isLoadingDiff && session.diffSnapshot?.diff != nil }
        #expect(session.diffSnapshot?.diff?.files.first?.hunks.count == 2)
    }

    /// 选中块里第一个可选的显示行。
    func activateFirstRow(_ selection: DiffLineSelection) throws {
        selection.activate(at: try #require(selection.rows.firstIndex { $0 != nil }))
    }
}

// MARK: - Private

extension DiffSelectionSessionTests {
    /// 着色关闭时只改字号、或只打开着色都不重置；着色开启后换主题重置；阈值重读后选择清空，放行保持。
    private func expectSettings(_ session: RepositorySession) async throws {
        let initial = TextTheme.builtin[0]
        var edited = initial
        edited.fontSize += 1
        session.diffAppearanceChanged(DiffSelectionAppearance(theme: initial, colorsSyntax: false))

        let old = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        try activateFirstRow(old)
        session.diffAppearanceChanged(DiffSelectionAppearance(theme: edited, colorsSyntax: false))
        session.diffAppearanceChanged(DiffSelectionAppearance(theme: edited, colorsSyntax: true))
        #expect(!old.selected.isEmpty && old.isActive)

        session.diffAppearanceChanged(DiffSelectionAppearance(theme: initial, colorsSyntax: true))
        #expect(!old.isActive && old.selected.isEmpty)

        // 阈值重读
        let current = try #require(session.diffSelections.selection(file: 0, hunk: 0))
        try activateFirstRow(current)
        session.showsLargeDiff = true
        session.diffWarningThresholdChanged()
        #expect(session.showsLargeDiff && !current.isActive)

        await until { !session.isLoadingDiff }
        #expect(session.diffSnapshot?.diff != nil)
        #expect(session.diffSelections.selection(file: 0, hunk: 0)?.selected.isEmpty ?? false)
    }
}
