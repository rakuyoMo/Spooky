import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

/// 主菜单与直接动作只改变可见变更集，不改隐藏的提交、储藏与比较。
@MainActor
struct ChangesetCommandTests {
    /// 六个入口各有独立接收者；历史多选发起比较时仍能展开比较。
    @Test("变更集命令按可见详情路由", arguments: 0 ... 5)
    func routes(target: Int) async throws {
        let fixture = try await ChangesetFixture.make()
        defer { fixture.close() }
        try await fixture.load()
        fixture.showWindow()
        let session = fixture.session

        if target == 5 { try await fixture.loadRequest() }
        if target == 0 { session.comparison.close() }
        if target == 1 { session.history.selectedIDs = Set(fixture.commits.prefix(2).map(\.id)) }
        session.activeView = [.history, .history, .stashes, .reflog, .branchesReview, .pullRequests][target]
        fixture.seedExpansions()
        let before = fixture.expansions
        let window = try #require(fixture.window)
        let item = NSMenuItem(title: "Expand", action: #selector(window.expandChanges), keyEquivalent: "")
        #expect(window.validateUserInterfaceItem(item))
        window.expandChanges()

        let expected = target == 2 ? Set(session.stashes.changes.map(\.id)) : ["a.txt", "b.txt"]
        #expect(fixture.expansions[target] == expected)
        assertHidden(fixture, before: before, target: target)
        item.action = #selector(window.collapseChanges)
        #expect(window.validateUserInterfaceItem(item))
        window.collapseChanges()
        #expect(fixture.expansions[target].isEmpty)
        assertHidden(fixture, before: before, target: target)
    }

    /// 每个禁用条件都经过窗口菜单验证和两个真实动作，缓存与展开集合同时保持不变。
    @Test("不可见变更集的菜单与直接动作都无副作用")
    func unavailable() async throws {
        let fixture = try await ChangesetFixture.make()
        defer { fixture.close() }
        try await fixture.load()
        fixture.showWindow()
        let session = fixture.session
        let window = try #require(fixture.window)
        session.activeView = .history
        session.comparison.showsChangeset = false
        assertUnavailable(fixture)
        session.comparison.close()
        session.history.showsTree = true
        assertUnavailable(fixture)
        session.history.showsTree = false
        session.history.showsCommitPage = true
        assertUnavailable(fixture)
        session.history.showsCommitPage = false
        session.history.selectedIDs = []
        assertUnavailable(fixture)
        session.history.selectedIDs = Set(fixture.commits.prefix(2).map(\.id))
        assertUnavailable(fixture)
        session.history.show(fixture.commits[2], runner: fixture.runner)
        #expect(session.history.isLoadingChanges)
        assertUnavailable(fixture)
        try await fixture.waitForChanges()

        session.activeView = .reflog
        session.reflog.detail.showsTree = true
        assertUnavailable(fixture)
        session.reflog.detail.showsTree = false
        session.reflog.selectedID = nil
        assertUnavailable(fixture)
        session.activeView = .stashes
        session.stashes.selectedIDs = Set(session.stashes.entries.map(\.id))
        assertUnavailable(fixture)
        session.stashes.selectedIDs = []
        assertUnavailable(fixture)
        session.activeView = .branchesReview
        session.branchesReview.comparison.showsChangeset = false
        assertUnavailable(fixture)
        session.branchesReview.selectedIDs = ["refs/heads/missing"]
        assertUnavailable(fixture)
        session.branchesReview.selectedIDs = ["refs/heads/main", "refs/heads/missing"]
        assertUnavailable(fixture)
        session.activeView = .workingCopy
        assertUnavailable(fixture)
        session.activeView = .pullRequests
        assertUnavailable(fixture)

        session.activeView = .history
        window.showRepositories()
        #expect(window.showsManager)
        assertUnavailable(fixture)
    }

    /// 空比较与读取失败没有可操作文件，读取中的比较不能回退到背后的提交。
    @Test("空结果、失败和读取中不接收变更集命令")
    func comparisonBoundaries() async throws {
        let fixture = try await ChangesetFixture.make()
        defer { fixture.close() }
        try await fixture.load()
        fixture.showWindow()
        let session = fixture.session
        session.activeView = .history
        fixture.open(session.comparison, target: 0)
        assertUnavailable(fixture)
        try await fixture.waitForChanges()
        #expect(session.comparison.changes.isEmpty && session.comparison.failure == nil)
        assertUnavailable(fixture)

        session.comparison.open(
            base: .init(id: String(repeating: "f", count: 40), title: "missing"),
            target: .init(id: fixture.commits[2].id, title: "target"),
            runner: fixture.runner
        )
        try await fixture.waitForChanges()
        #expect(session.comparison.failure != nil && session.comparison.changes.isEmpty)
        assertUnavailable(fixture)
        session.comparison.close()
        #expect(session.canExpandChanges)
    }

    /// 历史比较留在后台时，Reflog 的实际视图和菜单都使用自身提交，选择变化不关闭历史比较。
    @Test("Reflog 不显示或关闭历史比较")
    func reflogContent() async throws {
        let fixture = try await ChangesetFixture.make()
        defer { fixture.close() }
        try await fixture.load()
        let session = fixture.session
        session.activeView = .reflog
        let view = NSHostingView(rootView: CommitDetailView(history: session.reflog.detail, session: session))
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        view.layoutSubtreeIfNeeded()
        let before = session.comparison.target
        session.reflog.selectedID = try #require(session.reflog.entries.first { $0.commit.id == fixture.commits[1].id }).id
        try await fixture.waitForChanges()
        view.layoutSubtreeIfNeeded()

        guard case .commit(let commit) = session.commitDetailContent(for: session.reflog.detail) else {
            Issue.record("Reflog 应显示自己的提交")
            return
        }

        #expect(commit.id == fixture.commits[1].id)
        #expect(session.comparison.target == before)
        #expect(session.canExpandChanges)
        session.expandChanges(true)
        #expect(session.reflog.detail.expandedPaths == ["a.txt", "b.txt"])
        #expect(session.comparison.expandedPaths.isEmpty)
    }

    /// 请求的 Conversation、Commits 与需要获取状态均不操作缓存的比较。
    @Test("请求详情只在已加载的 Changeset 接收命令")
    func requestBoundaries() async throws {
        let fixture = try await ChangesetFixture.make()
        defer { fixture.close() }
        try await fixture.load()
        fixture.showWindow()
        try await fixture.loadRequest()
        let session = fixture.session
        session.activeView = .pullRequests
        session.pullRequests.page = .conversation
        assertUnavailable(fixture)
        session.pullRequests.page = .commits
        assertUnavailable(fixture)
        session.pullRequests.page = .changeset
        session.pullRequests.comparison.showsChangeset = false
        assertUnavailable(fixture)
        try await fixture.loadRequest(needsFetch: true)
        fixture.open(session.pullRequests.comparison)
        try await fixture.waitForChanges()
        #expect(session.pullRequests.needsFetch)
        assertUnavailable(fixture)
    }

    /// 检查其它五份详情的展开集合没有串改。
    private func assertHidden(_ fixture: ChangesetFixture, before: [Set<String>], target: Int) {
        for index in before.indices where index != target {
            #expect(fixture.expansions[index] == before[index])
        }
    }

    /// 两个命令都须禁用；直接调用也不能改变任何展开集合或补丁缓存。
    private func assertUnavailable(_ fixture: ChangesetFixture) {
        fixture.seedExpansions()
        let expansions = fixture.expansions
        let caches = fixture.cachedPaths
        guard let window = fixture.window else { return }

        for action in [#selector(window.expandChanges), #selector(window.collapseChanges)] {
            let item = NSMenuItem(title: "Changeset", action: action, keyEquivalent: "")
            #expect(!window.validateUserInterfaceItem(item))
        }

        window.expandChanges()
        window.collapseChanges()
        #expect(fixture.expansions == expansions)
        #expect(fixture.cachedPaths == caches)
    }
}
