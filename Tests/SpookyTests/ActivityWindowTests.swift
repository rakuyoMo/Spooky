import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ActivityWindowTests

/// Activity 窗口的工具栏：清除、分页与搜索都只作用于当前页。
///
/// 每个测试使用自己的 `RepositoryActivities` 实例，不碰共享的活动列表。
@MainActor
struct ActivityWindowTests {
    /// 工具栏自左向右是 Clear All、分段、搜索框；分段的标题与提示对应三页，第一次打开是 Remote。
    @Test("工具栏的排布、分段与第一次打开的页")
    func toolbarItems() throws {
        let controller = ActivityWindowController(activities: RepositoryActivities())
        defer { controller.close() }

        let toolbar = try #require(controller.window?.toolbar)
        #expect(!toolbar.allowsUserCustomization)
        #expect(
            toolbar.items.map(\.itemIdentifier) == [
                ActivityToolbar.clearAll,
                .flexibleSpace,
                ActivityToolbar.kinds,
                .space,
                .flexibleSpace,
                ActivityToolbar.search,
            ]
        )

        // Clear All 是只显示文字的按钮，标签、面板标签与提示都是按钮文字
        let clear = try #require(toolbar.items.first)
        let button = try #require(clear.view as? NSButton)
        let title = AppLocalization.text("activity.clear")
        #expect(button.title == title && button.bezelStyle == .toolbar)
        #expect(clear.label == title && clear.paletteLabel == title && clear.toolTip == title)

        // 三段依次是 Remote、Repository、Service，单选，第一次打开选中 Remote
        let group = try #require(toolbar.items[2] as? NSToolbarItemGroup)
        let keys = ["activity.remote", "activity.repository", "activity.service"]
        #expect(group.selectionMode == .selectOne)
        #expect(group.subitems.map(\.label) == keys.map { AppLocalization.text($0) })
        #expect(group.subitems.map(\.toolTip) == keys.map { AppLocalization.text($0 + ".help") })
        #expect(group.selectedIndex == 0)
        #expect(controller.state.kind == .remote)

        // 英文的标题与提示
        let english = try #require(
            AppLocalization.bundle.url(forResource: "en", withExtension: "lproj").flatMap(Bundle.init(url:))
        )
        let englishTexts = keys.flatMap { [$0, $0 + ".help"] }.map {
            english.localizedString(forKey: $0, value: nil, table: nil)
        }
        #expect(
            englishTexts == [
                "Remote", "Shows Remote Activities",
                "Repository", "Shows Repository Activities",
                "Service", "Shows Service Activities",
            ]
        )
        #expect(english.localizedString(forKey: "activity.clear", value: nil, table: nil) == "Clear All")

        // 搜索框的标签与提示相同，文字写进窗口状态
        let search = try #require(toolbar.items.last as? NSSearchToolbarItem)
        #expect(search.label == AppLocalization.text("action.search") && search.toolTip == search.label)
        #expect(search.searchField.placeholderString == AppLocalization.text("activity.search"))

        search.searchField.stringValue = "origin"
        controller.searchChanged(search.searchField)
        #expect(controller.state.query == "origin")

        // 每个按钮与分段的动作都由窗口响应
        for item in [clear] + group.subitems {
            let action = try #require(item.action)
            #expect(controller.responds(to: action))
        }
    }

    /// 列表只列当前页；搜索按仓库名与日志内容匹配，忽略大小写，路径的其它部分不算；没有仓库的记录只按日志匹配。
    @Test("当前页的过滤")
    func filter() {
        let fetch = activity(.remote, path: "/tmp/项目 Projects/Alpha", log: "From origin\n")
        let branch = activity(.repository, path: "/tmp/项目 Projects/Beta", log: "Switched to branch 'main'\n")
        let request = activity(
            .service,
            location: .remote(host: "spooky-test", path: "/Users/wgy/spooky-test/Gamma"),
            log: ""
        )
        let verify = activity(.service, location: nil, log: "Gamma account\n")
        let items = [verify, request, branch, fetch]
        let state = ActivityWindowState()

        // 不搜索时各页只列自己的记录
        #expect(state.visibleItems(in: items).map(\.id) == [fetch.id])

        state.kind = .repository
        #expect(state.visibleItems(in: items).map(\.id) == [branch.id])

        state.kind = .service
        #expect(state.visibleItems(in: items).map(\.id) == [verify.id, request.id])

        // 服务器仓库的仓库名带主机前缀；没有仓库的记录不按仓库名命中
        state.query = "SPOOKY-TEST:gamma"
        #expect(state.visibleItems(in: items).map(\.id) == [request.id])

        // 没有仓库的记录按日志命中
        state.query = "ACCOUNT"
        #expect(state.visibleItems(in: items).map(\.id) == [verify.id])

        // 仓库名与日志内容都能命中，忽略大小写
        state.kind = .remote
        state.query = "ALPHA"
        #expect(state.visibleItems(in: items).map(\.id) == [fetch.id])

        state.query = "ORIGIN"
        #expect(state.visibleItems(in: items).map(\.id) == [fetch.id])

        // 路径里仓库名以外的部分不算
        state.query = "Projects"
        #expect(state.visibleItems(in: items).isEmpty)

        // 别的页里的记录即使命中也不列出
        state.query = "beta"
        #expect(state.visibleItems(in: items).isEmpty)
    }

    /// Clear All 只清当前页已结束的记录：进行中的与别的页都不动。
    @Test("Clear All 只清当前页已结束的记录")
    func clearAll() throws {
        let activities = RepositoryActivities()
        let endedFetch = activity(.remote, path: "/tmp/Alpha", log: "")
        let runningPush = activity(.remote, path: "/tmp/Alpha", log: "", ended: false)
        let endedBranch = activity(.repository, path: "/tmp/Beta", log: "")
        let runningMerge = activity(.repository, path: "/tmp/Beta", log: "", ended: false)
        let endedRequest = activity(.service, path: "/tmp/Gamma", log: "")

        for item in [endedFetch, runningPush, endedBranch, runningMerge, endedRequest] {
            activities.insert(item)
        }

        let controller = ActivityWindowController(activities: activities)
        defer { controller.close() }

        let group = try #require(
            controller.window?.toolbar?.items.first { $0.itemIdentifier == ActivityToolbar.kinds } as? NSToolbarItemGroup
        )

        // 分段依次换到对应的页
        for (segment, kind) in zip(group.subitems, ActivityKind.allCases) {
            controller.selectKind(segment)
            #expect(controller.state.kind == kind)
        }

        // 在 Repository 页清除：只删这一页已结束的记录
        controller.selectKind(group.subitems[1])
        controller.clearAll(nil)
        #expect(activities.items.map(\.id) == [endedRequest.id, runningMerge.id, runningPush.id, endedFetch.id])

        // 再到 Remote 页清除
        controller.selectKind(group.subitems[0])
        controller.clearAll(nil)
        #expect(activities.items.map(\.id) == [endedRequest.id, runningMerge.id, runningPush.id])
    }

    /// 一条本机仓库的记录。
    private func activity(_ kind: ActivityKind, path: String, log: String, ended: Bool = true) -> RepositoryActivity {
        activity(kind, location: .local(path: path), log: log, ended: ended)
    }

    /// 一条带日志的记录；`location` 为 nil 时不属于任何仓库，`ended` 为真时记为已完成。
    private func activity(
        _ kind: ActivityKind,
        location: RepositoryLocation?,
        log: String,
        ended: Bool = true
    ) -> RepositoryActivity {
        let activity = RepositoryActivity(kind: kind, repository: location, title: "Activity")
        activity.append(.standardOutput(Data(log.utf8)))

        if ended {
            activity.state = "activity.finished"
        }

        return activity
    }
}
