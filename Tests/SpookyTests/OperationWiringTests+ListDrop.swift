import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - List Drop

extension OperationWiringTests {
    /// 在看 HEAD 分支时，提交落在另一个提交上是压缩、按住 ⌥ 是 fixup；未拉取的提交与提交自己都不是落点。
    @Test("列表内拖放：压缩与 fixup")
    func listDropSquash() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        _ = try await fixture.select("refs/heads/main", subjects: ["D"])
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

        // 不在看 HEAD 分支时列表内拖放不生效
        _ = try await fixture.select("refs/heads/side", subjects: ["S"])
        #expect(fixture.listDrop([d], row: try #require(history.row(of: fixture.ids["S"] ?? ""))) == nil)
    }

    /// 落在两行之间是移到那里：缝隙下面最近的提交的上方；缝隙在末尾时是最后一个提交的下方；位置不变时不接受。
    @Test("列表内拖放：移到两行之间")
    func listDropMove() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        _ = try await fixture.select("refs/heads/main", subjects: ["D"])
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
    @Test("列表内拖放跨过日期分组行")
    func listDropAcrossGroups() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        _ = try await fixture.select("refs/heads/main", subjects: ["D"])
        let (b, d) = (fixture.ids["B"] ?? "", fixture.ids["D"] ?? "")
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
        let a = fixture.ids["A"] ?? ""
        #expect(fixture.listDrop([a], row: index, between: true) == .move([a], to: b, position: .above))
    }

    /// 在看 HEAD 分支、最近的提交里有能找到目标的 fixup! 提交时出现横幅；看别的分支或搜索时不出现。
    @Test("Autosquash 横幅")
    func autosquashBanner() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let banner = HistoryAutosquashBanner(session: fixture.session)

        _ = try await fixture.select("refs/heads/main", subjects: ["D"])
        #expect(!banner.isVisible)

        // 在 main 上提交一个 fixup! D
        try Data("D2\n".utf8).write(to: fixture.directory.appending(path: "D.txt"))
        _ = try await fixture.runner.run(["commit", "-q", "-a", "-m", "fixup! D"])
        fixture.session.refresh(full: true)
        await fixture.session.waitForRefresh()

        let history = fixture.session.history
        try await FileViewsTests.wait {
            !history.isLoading && history.commits.contains { $0.subject == "fixup! D" }
        }

        #expect(banner.isVisible)

        history.selectedReferences = ["refs/heads/side"]
        try await FileViewsTests.wait { !history.isLoading }
        #expect(!banner.isVisible)
    }
}

// MARK: - Helpers

extension OperationWiringTests.Fixture {
    /// 把这些提交拖到历史列表的这一行时算出的交互式变基动作。
    @MainActor
    func listDrop(_ dragged: [String], row: Int, between: Bool = false, alternate: Bool = false) -> RewriteAction? {
        HistoryListDrop.action(dragged: dragged, row: row, between: between, alternate: alternate, session: session)
    }
}
