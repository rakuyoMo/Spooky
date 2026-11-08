import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - SubmoduleMenuTests

/// 子模块行的右键菜单由 AppKit 生成：项目与分组不变，按住 ⌥ 换成快速获取与快速更新，各项的可用性跟着会话的规则走；
/// Checkout Revision 子菜单的分支与标签缩进一级，选中别的版本即在子模块里检出它。
@MainActor
struct SubmoduleMenuTests {
    /// 已检出、已初始化的子模块：各项都可用；子菜单的组名不缩进，分支缩进一级，当前分支打勾不可选，选中另一个分支即检出。
    /// 去掉初始化的子模块：打开、检出版本、获取与同步不可用，更新、初始化、移动、改名与删除仍可用。
    @Test("已检出与没有初始化的子模块")
    func submoduleStates() async throws {
        let fixture = try await UndoSessionTests.Fixture(allowsFileSubmodules: true)

        defer { fixture.remove() }

        let session = fixture.session
        let added = try await UndoSessionTests.addCommittedSubmodule(in: fixture)

        defer { try? FileManager.default.removeItem(at: added.upstream) }

        _ = try await fixture.runner.run(["-C", "lib", "branch", "特性"])

        await fixture.refresh()
        await until { session.submodules.revisions["lib"]?.count == 2 }

        let revisions = try expectPopulatedMenu(in: session)

        // 菜单项的动作经 NSApp 发出，目标按分支名定位，不依赖当前区域的排序位置
        _ = NSApplication.shared

        let target = try #require(revisions.items.firstIndex { $0.title == "特性" })

        try await fixture.perform { revisions.performActionForItem(at: target) }

        let output = try await fixture.runner.run(["-C", "lib", "branch", "--show-current"])
        let current = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        #expect(current == "特性")

        // 去掉初始化
        _ = try await fixture.runner.run(["submodule", "deinit", "-q", "-f", "--", "lib"])

        await fixture.refresh()
        await until { session.submodules.items.first?.state == .uninitialized }

        let submodule = try #require(session.submodules.items.first)
        let menu = SubmoduleMenu.menu(session: session, submodule: submodule)
        let enabled = menu.items.filter { !$0.isSeparatorItem }.map(\.isEnabled)

        #expect(Self.titles(menu) == Self.expectedTitles)
        #expect(enabled == [false, false, false, false, true, true, true, false, true, true, true])
    }

    /// 已检出的子模块的菜单：项目与分组、⌥ 快速项、各项可用，Checkout Revision 子菜单的缩进、可用性与打勾；返回这个子菜单。
    ///
    /// - Parameter session: 子模块所在仓库的会话。
    private func expectPopulatedMenu(in session: RepositorySession) throws -> NSMenu {
        let submodule = try #require(session.submodules.items.first)
        let menu = SubmoduleMenu.menu(session: session, submodule: submodule)

        #expect(Self.titles(menu) == Self.expectedTitles)

        // 快速获取与快速更新是按住 ⌥ 时代替上一项的快速项
        let alternates = menu.items.filter(\.isAlternate)

        #expect(alternates.map(\.title) == [Self.expectedTitles[5], Self.expectedTitles[7]])
        #expect(alternates.allSatisfy { $0.keyEquivalentModifierMask == .option })
        #expect(menu.items.filter { !$0.isSeparatorItem }.allSatisfy { $0.isEnabled })

        // 子菜单：组名不缩进，分支缩进一级，当前分支打勾不可选
        let revisions = try #require(menu.items[2].submenu)
        let branches = ["main", "特性"].sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        #expect(Self.titles(revisions) == [AppLocalization.text("branch.group")] + branches)
        #expect(revisions.items.map(\.indentationLevel) == [0, 1, 1])
        #expect(revisions.items.map(\.isEnabled) == [false] + branches.map { $0 != "main" })
        #expect(revisions.items.map(\.state) == [.off] + branches.map { $0 == "main" ? .on : .off })

        return revisions
    }
}

// MARK: - Helpers

extension SubmoduleMenuTests {
    /// 路径为 `lib` 的子模块的菜单项标题，分隔线写作 “-”。
    private static let expectedTitles = [
        AppLocalization.text("submodule.open", "lib"),
        "-",
        AppLocalization.text("submodule.checkoutRevision"),
        "-",
        AppLocalization.text("submodule.fetch.menu", "lib"),
        AppLocalization.text("submodule.quickFetch", "lib"),
        AppLocalization.text("submodule.update.menu", "lib"),
        AppLocalization.text("submodule.quickUpdate", "lib"),
        AppLocalization.text("submodule.initialize.menu", "lib"),
        AppLocalization.text("submodule.synchronize.menu", "lib"),
        "-",
        AppLocalization.text("submodule.move.menu", "lib"),
        AppLocalization.text("submodule.rename.menu", "lib"),
        AppLocalization.text("submodule.delete.menu", "lib"),
    ]

    /// 菜单项的标题，分隔线写作 “-”。
    private static func titles(_ menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "-" : $0.title }
    }
}
