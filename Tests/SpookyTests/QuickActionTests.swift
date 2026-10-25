import AppKit
import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - QuickActionTests

/// 快捷操作：模糊匹配的档次与排序、对象与动作的可用性、提交与文件的查询，以及经窗口执行动作。
@MainActor
struct QuickActionTests {
    /// 完全相同 > 前缀 > 从词首开始的子串 > 其它子串 > 按序散落；不区分大小写与变音符号，空查询匹配一切。
    @Test("匹配的五个档次")
    func matcherTiers() throws {
        let exact = try #require(QuickActionMatcher.score("main", query: "MAIN"))
        let prefix = try #require(QuickActionMatcher.score("mainline", query: "main"))
        let wordStart = try #require(QuickActionMatcher.score("feature/main-fix", query: "main"))
        let substring = try #require(QuickActionMatcher.score("domains", query: "main"))
        let scattered = try #require(QuickActionMatcher.score("my-awesome-inline", query: "main"))

        #expect(exact > prefix)
        #expect(prefix > wordStart)
        #expect(wordStart > substring)
        #expect(substring > scattered)

        #expect(QuickActionMatcher.score("Résumé", query: "resume") == 4000)
        #expect(QuickActionMatcher.score("main", query: "mian") == nil)
        #expect(QuickActionMatcher.score("anything", query: "") == 0)
    }

    /// 对象先按种类排，同一种类按得分；文件名匹配的文件排在只有路径匹配的前面，同分按路径的自然顺序。
    @Test("对象与文件的排序")
    func ranking() {
        let objects: [QuickActionObject] = [
            .remote("main-mirror"),
            .navigation(.history),
            .remote("main"),
            .remote("origin"),
        ]

        let ranked = QuickActionMatcher.rank(objects, query: "mai")
        #expect(ranked.map(\.title) == ["main", "main-mirror"])

        let files = QuickActionMatcher.rankFiles(
            ["docs/readme.md", "src/readme 10.txt", "src/readme 9.txt", "readme/notes.txt"],
            query: "readme"
        )
        #expect(files == ["docs/readme.md", "src/readme 9.txt", "src/readme 10.txt", "readme/notes.txt"])
    }

    /// 当前分支排在分支的最前面；它的动作沿用分支菜单的规则，不能检出自己、不能合并进自己。
    @Test("对象与动作的可用性")
    func catalogActions() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let session = fixture.controller.session
        _ = try await session.runner?.run(["branch", "topic"])
        session.refresh(full: true)
        await session.waitForRefresh()

        // 引用快照在历史读取里另行更新，等它带上新分支
        try await FileViewsTests.wait { session.history.branches.contains { $0.name == "topic" } }

        let catalog = QuickActionCatalog(session: session)
        let objects = catalog.immediateObjects()
        let branches = objects.compactMap { object -> RepositoryReference? in
            guard case .branch(let reference) = object else { return nil }
            return reference
        }

        let destinations = QuickActionDestination.allCases.map(\.title)
        #expect(objects.prefix(destinations.count).map(\.title) == destinations)
        #expect(branches.map(\.name) == ["main", "topic"])

        let head = try #require(branches.first)
        let topic = try #require(branches.last)
        let headActions = catalog.actions(for: .branch(head))
        let topicActions = catalog.actions(for: .branch(topic))

        #expect(headActions.first == catalog.defaultAction(for: .branch(head)))
        #expect(!headActions.contains(.checkout))
        #expect(!headActions.contains(.mergeIntoHead))
        #expect(topicActions.contains(.checkout))
        #expect(topicActions.contains(.mergeIntoHead))

        // 本机仓库的工作区可以在 Finder 中显示
        #expect(catalog.actions(for: .navigation(.workingCopy)).contains(.revealInFinder))
    }

    /// 像哈希的输入只找那一个提交，其余按提交信息搜索；HEAD 树里的文件不含目录。
    @Test("提交与文件的查询")
    func commitAndFileQueries() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let session = fixture.controller.session
        let catalog = QuickActionCatalog(session: session)
        let head = try #require(session.status?.branch.oid)

        let byHash = try await catalog.commits(matching: String(head.prefix(7)))
        let byMessage = try await catalog.commits(matching: "first")
        let none = try await catalog.commits(matching: "nothing like this")

        #expect(byHash.map(\.title).count == 1)
        #expect(byMessage.count == 1)
        #expect(none.isEmpty)

        let files = try #require(try await catalog.headFiles())
        #expect(files.head == head)
        #expect(files.paths == ["a.txt"])
    }

    /// 动作经窗口执行，走菜单的同一个入口：导航切换主视图，文件动作打开文件历史。
    @Test("经窗口执行动作")
    func performActions() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller

        controller.performQuickAction(.show, on: .navigation(.history))
        #expect(controller.session.activeView == .history)

        controller.performQuickAction(.showFileHistory, on: .file("a.txt"))
        #expect(controller.session.activeView == .fileHistory)
        #expect(controller.session.fileHistory.path == "a.txt")

        // 仓库设置同样是导航对象，当前视图引用随之换成它
        controller.performQuickAction(.show, on: .navigation(.settings))
        #expect(controller.session.activeView == .settings)
        #expect(controller.currentReference == .repository(fixture.location, .settings))
    }
}
