import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - List Drop

extension OperationWiringTests {
    /// 在看 HEAD 分支时，提交落在另一个提交上是压缩、按住 ⌥ 是 fixup，落在两行之间是移到那里；
    /// 未拉取的提交、提交自己、位置不变与日期分组行都不接受；不在看 HEAD 分支时列表内拖放不生效。
    @Test("列表内拖放：压缩、fixup 与移动")
    func listDrop() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        _ = try await fixture.select("refs/heads/main", subjects: ["D"])

        try checkSquash(in: fixture)
        try checkMove(in: fixture)
        try checkAcrossGroups(in: fixture)

        // 不在看 HEAD 分支时列表内拖放不生效
        let d = fixture.ids["D"] ?? ""
        let s = fixture.ids["S"] ?? ""
        _ = try await fixture.select("refs/heads/side", subjects: ["S"])

        #expect(fixture.listDrop([d], row: try #require(fixture.session.history.row(of: s))) == nil)
    }

    /// 在看 HEAD 分支、最近的提交里有能找到目标的 fixup! 提交时出现横幅；看别的分支时不出现。
    @Test("Autosquash 横幅")
    func autosquashBanner() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let session = fixture.session
        let history = session.history
        let banner = HistoryAutosquashBanner(session: session)

        _ = try await fixture.select("refs/heads/main", subjects: ["D"])
        #expect(!banner.isVisible)

        // 在 main 上提交一个 fixup! D，刷新后引用变化，列表随之重读
        try Data("D2\n".utf8).write(to: fixture.directory.appending(path: "D.txt"))
        _ = try await fixture.runner.run(["commit", "-q", "-a", "-m", "fixup! D"])

        session.refresh(full: true)
        await session.waitForRefresh()
        await untilFinished { history.activeTasks }
        try #require(history.commits.contains { $0.subject == "fixup! D" })

        #expect(banner.isVisible)

        // 看别的分支时不出现
        history.selectedReferences = ["refs/heads/side"]
        await untilFinished { history.activeTasks }

        #expect(!banner.isVisible)
    }

    /// 提交落在另一个提交上是压缩、按住 ⌥ 是 fixup；未拉取的提交与提交自己都不是落点。
    private func checkSquash(in fixture: Fixture) throws {
        let (b, c, d) = (fixture.ids["B"] ?? "", fixture.ids["C"] ?? "", fixture.ids["D"] ?? "")
        let history = fixture.session.history

        let onB = try #require(history.row(of: b))
        #expect(fixture.listDrop([d], row: onB) == .squash([d], into: b))
        #expect(fixture.listDrop([d], row: onB, alternate: true) == .fixup([d], into: b))

        // 未拉取的提交不在 HEAD 的历史里，拖它或落在它上面都不接受
        let onC = try #require(history.row(of: c))
        #expect(fixture.listDrop([d], row: onC) == nil)
        #expect(fixture.listDrop([c], row: onB) == nil)

        // 落在自己身上不接受
        #expect(fixture.listDrop([d], row: try #require(history.row(of: d))) == nil)
    }

    /// 落在两行之间是移到那里：缝隙下面最近的提交的上方；缝隙在末尾时是最后一个提交的下方；位置不变时不接受。
    private func checkMove(in fixture: Fixture) throws {
        let (b, d) = (fixture.ids["B"] ?? "", fixture.ids["D"] ?? "")
        let history = fixture.session.history

        // B 移到 D 上方
        let aboveD = try #require(history.row(of: d))
        #expect(fixture.listDrop([b], row: aboveD, between: true) == .move([b], to: d, position: .above))

        // D 已经紧挨在 B 上方，移到 B 上方位置不变
        let aboveB = try #require(history.row(of: b))
        #expect(fixture.listDrop([d], row: aboveB, between: true) == nil)

        // 缝隙在列表末尾：最后一个提交的下方
        let last = try #require(history.rows.last?.commit)
        let end = fixture.listDrop([d], row: history.rows.count, between: true)

        #expect(end == .move([d], to: last.id, position: .below))
    }

    /// 日期分组行不是提交：落在分组行上不接受，落在分组行上方等于落在它下面最近的提交上方。
    private func checkAcrossGroups(in fixture: Fixture) throws {
        let (a, b, d) = (fixture.ids["A"] ?? "", fixture.ids["B"] ?? "", fixture.ids["D"] ?? "")
        let history = fixture.session.history

        // 在 B 前面插一个分组行，模拟 B 与 D 分属两天
        let group = HistoryRow.group(Date(timeIntervalSince1970: 0))
        let index = try #require(history.row(of: b))
        history.rows.insert(group, at: index)

        #expect(fixture.listDrop([d], row: index) == nil)
        #expect(fixture.listDrop([d], row: index + 1) == .squash([d], into: b))

        // 分组行上方的缝隙：落在 B 上方，D 本来就在那里
        #expect(fixture.listDrop([d], row: index, between: true) == nil)

        // 把 A 拖到分组行上方：移到 B 上方
        #expect(fixture.listDrop([a], row: index, between: true) == .move([a], to: b, position: .above))
    }
}

// MARK: - Helpers

extension OperationWiringTests.Fixture {
    /// 把这些提交拖到历史列表的这一行时算出的交互式变基动作。
    @MainActor
    func listDrop(
        _ dragged: [String],
        row: Int,
        between: Bool = false,
        alternate: Bool = false
    ) -> RewriteAction? {
        HistoryListDrop.action(
            dragged: dragged,
            row: row,
            between: between,
            alternate: alternate,
            session: session
        )
    }
}
