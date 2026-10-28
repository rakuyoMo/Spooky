import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SidebarSettingsTests

/// 视图设置菜单与 View › Sidebar 是同一张菜单，选择后直接写偏好；分支行的标记与提示随设置变化。
@MainActor
struct SidebarSettingsTests {
    /// 菜单按显示、分组、徽标、数量四组排列，勾选状态取偏好，依赖项随前一项启用。
    @Test("视图设置菜单的结构与依赖")
    func menuItems() throws {
        let (defaults, directory) = try temporaryDefaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let builder = SidebarViewSettingsMenu(defaults: defaults)
        let menu = NSMenu()
        builder.menuNeedsUpdate(menu)

        let titles = menu.items.map { $0.isSeparatorItem ? "|" : $0.title }
        let expected = [
            "sidebar.showReflog", "sidebar.showStashCount", "|", "sidebar.groupRefs", "sidebar.groupedRefsOnTop", "|",
            "sidebar.showStaleInfo", "sidebar.staleInterval", "sidebar.autoArchive", "|",
            "sidebar.remoteFilter", "sidebar.tagsFilter",
        ]
        .map { $0 == "|" ? "|" : AppLocalization.text($0) }
        #expect(titles == expected)
        #expect(!menu.autoenablesItems)

        // 默认：分组开启、Reflog 与自动归档关闭，陈旧阈值 3 个月
        let groupRefs = try item(SidebarPreferences.groupRefsKey, in: menu)
        let reflog = try item(SidebarPreferences.showReflogKey, in: menu)
        let autoArchive = try item(SidebarPreferences.autoArchiveKey, in: menu)
        #expect(groupRefs.state == .on)
        #expect(reflog.state == .off && autoArchive.state == .off)

        let interval = try #require(titled("sidebar.staleInterval", in: menu).submenu)
        #expect(interval.items.map(\.tag) == SidebarPreferences.staleIntervals)
        #expect(interval.items.first { $0.state == .on }?.tag == 3)
        #expect(interval.items.first?.title == AppLocalization.text("sidebar.month"))
        #expect(interval.items.last?.title == AppLocalization.text("sidebar.months", 24))

        // 关闭分组后 “文件夹置前” 不可用；关闭陈旧信息后阈值不可用
        builder.toggleSetting(groupRefs)
        builder.toggleSetting(try item(SidebarPreferences.showStaleInfoKey, in: menu))
        #expect(!SidebarPreferences.isOn(SidebarPreferences.groupRefsKey, in: defaults))

        builder.menuNeedsUpdate(menu)
        #expect(!(try item(SidebarPreferences.groupedRefsOnTopKey, in: menu).isEnabled))
        #expect(!(try titled("sidebar.staleInterval", in: menu).isEnabled))
    }

    /// 数量与排序子菜单：小标题不可点，选中的档位写进偏好，下次打开时打勾。
    @Test("数量与排序子菜单")
    func filterSubmenus() throws {
        let (defaults, directory) = try temporaryDefaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let builder = SidebarViewSettingsMenu(defaults: defaults)
        let menu = NSMenu()
        builder.menuNeedsUpdate(menu)

        let remote = try #require(titled("sidebar.remoteFilter", in: menu).submenu)
        #expect(!(remote.items.first?.isEnabled ?? true))
        #expect(remote.items.dropFirst().map(\.tag) == SidebarPreferences.newestChoices)
        #expect(remote.items[1].title == AppLocalization.text("sidebar.all"))
        #expect(remote.items[1].state == .on)

        builder.selectNumber(try #require(remote.items.first { $0.tag == 25 }))
        #expect(SidebarPreferences.integer(SidebarPreferences.newestRemoteBranchesKey, in: defaults) == 25)

        let tags = try #require(titled("sidebar.tagsFilter", in: menu).submenu)
        let tagTitles = tags.items.map { $0.isSeparatorItem ? "|" : $0.title }
        #expect(
            Array(tagTitles.prefix(5)) == [
                AppLocalization.text("sidebar.sortBy"),
                AppLocalization.text("sidebar.nameAscending"),
                AppLocalization.text("sidebar.nameDescending"),
                "|",
                AppLocalization.text("sidebar.showNewest"),
            ]
        )

        builder.selectNumber(tags.items[2])
        builder.selectNumber(try #require(tags.items.last))
        #expect(SidebarPreferences.integer(SidebarPreferences.tagOrderKey, in: defaults) == 2)
        #expect(SidebarPreferences.integer(SidebarPreferences.newestTagsKey, in: defaults) == 500)

        // 记录了范围外的值时按默认值处理
        defaults.set(7, forKey: SidebarPreferences.staleIntervalKey)
        #expect(SidebarPreferences.integer(SidebarPreferences.staleIntervalKey, in: defaults) == 3)

        builder.menuNeedsUpdate(menu)
        let reopened = try #require(titled("sidebar.remoteFilter", in: menu).submenu)
        #expect(reopened.items.first { $0.state == .on }?.tag == 25)
    }

    /// 主菜单 View › Sidebar 由同一个生成者填充。
    @Test("主菜单的 Sidebar 子菜单")
    func mainMenu() throws {
        let (defaults, directory) = try temporaryDefaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let controller = SpookyApplicationController(bookmarks: RepositoryBookmarks(defaults: defaults))
        _ = NSApplication.shared
        controller.configureMenu()

        let items = NSApp.mainMenu?.items.compactMap(\.submenu).flatMap(\.items) ?? []
        let sidebar = try #require(items.first { $0.title == AppLocalization.text("sidebar.menu") }?.submenu)
        #expect(sidebar.delegate === SidebarViewSettingsMenu.shared)
    }

    /// 陈旧的分支名称变灰，关闭陈旧信息后既不显示也不变灰；跟踪错误总是显示。
    @Test("分支行的标记随设置变化")
    func branchStatus() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = try #require(Calendar.current.date(byAdding: .month, value: -7, to: now))
        let condition = BranchCondition(
            reference: "refs/heads/topic",
            lastUpdated: old,
            missingUpstream: "refs/remotes/origin/topic",
            isBase: false
        )

        let shown = SidebarBranchStatus(condition: condition, staleMonths: 6, now: now)
        #expect(shown.isDimmed)
        #expect(shown.staleDuration == SidebarTooltip.duration(since: old, now: now))
        #expect(shown.missingUpstream == "refs/remotes/origin/topic")

        let hidden = SidebarBranchStatus(condition: condition, staleMonths: nil, now: now)
        #expect(!hidden.isDimmed)
        #expect(hidden.staleDuration == nil)
        #expect(hidden.missingUpstream != nil)

        let fresher = SidebarBranchStatus(condition: condition, staleMonths: 9, now: now)
        #expect(fresher.staleDuration == nil)
    }

    /// 悬停提示逐行写出分支名、跟踪关系、计数、归档、陈旧与跟踪错误，服务器仓库带主机前缀。
    @Test("悬停提示")
    func tooltips() throws {
        let branch = RepositoryReference(
            id: "refs/heads/feature/登录",
            objectID: String(repeating: "c", count: 40),
            objectType: "commit",
            upstream: "refs/remotes/origin/feature/登录",
            upstreamRemote: "origin",
            upstreamBranch: "refs/heads/feature/登录",
            symbolicTarget: nil
        )
        var status = SidebarBranchStatus(condition: nil, staleMonths: nil)
        status.staleDuration = "3 months"

        let text = SidebarTooltip.branch(
            branch,
            host: "b",
            divergence: ReferenceDivergence(ahead: 2, behind: 1),
            metadata: BranchMetadata(isArchived: true),
            status: status
        )
        #expect(
            text.components(separatedBy: "\n") == [
                "b: " + AppLocalization.text("branch.tooltip.local", "feature/登录"),
                AppLocalization.text("branch.tooltip.tracksRemote", "origin/feature/登录"),
                AppLocalization.text("branch.tooltip.divergence", 2, 1, "origin/feature/登录"),
                AppLocalization.text("branch.tooltip.archived"),
                AppLocalization.text("branch.tooltip.stale", "3 months"),
            ]
        )

        // 计数为零时不写计数行；跟踪错误单独一行
        status = SidebarBranchStatus(condition: nil, staleMonths: nil)
        status.missingUpstream = "refs/remotes/origin/feature/登录"
        let gone = SidebarTooltip.branch(
            branch,
            host: nil,
            divergence: ReferenceDivergence(ahead: 0, behind: 0),
            metadata: BranchMetadata(),
            status: status
        )
        #expect(gone.components(separatedBy: "\n").count == 3)
        #expect(gone.hasSuffix(AppLocalization.text("branch.tooltip.missingUpstream", "origin/feature/登录")))

        let detached = SidebarTooltip.head(branch: BranchStatus(head: nil, oid: String(repeating: "d", count: 64)), host: nil)
        #expect(detached == AppLocalization.text("branch.tooltip.detached", "dddddddd"))

        let tag = RepositoryReference(
            id: "refs/tags/v1.0",
            objectID: String(repeating: "e", count: 64),
            objectType: "commit",
            upstream: nil,
            upstreamRemote: nil,
            upstreamBranch: nil,
            symbolicTarget: nil,
            message: "Release “1.0”"
        )
        #expect(
            SidebarTooltip.tag(tag, host: nil)
                == AppLocalization.text("tag.tooltip.revision", "eeeeeeee") + "\n"
                + AppLocalization.text("tag.tooltip.message", "Release “1.0”")
        )
    }
}

// MARK: - Helpers

extension SidebarSettingsTests {
    /// 菜单里代表某个开关的项。
    private func item(_ key: String, in menu: NSMenu) throws -> NSMenuItem {
        try #require(menu.items.first { $0.representedObject as? String == key })
    }

    /// 菜单里标题为某个资源键译文的项。
    private func titled(_ key: String, in menu: NSMenu) throws -> NSMenuItem {
        try #require(menu.items.first { $0.title == AppLocalization.text(key) })
    }

    /// 每个测试独占的偏好域与它所在的临时目录。
    private func temporaryDefaults() throws -> (UserDefaults, URL) {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-sidebar-" + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        return (defaults, directory)
    }
}
