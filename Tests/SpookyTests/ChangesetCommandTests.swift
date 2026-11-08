import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

/// 主菜单与直接动作只改变可见变更集，不改隐藏的提交、储藏与比较。
@MainActor
struct ChangesetCommandTests {
    /// 六个入口各有独立接收者；历史多选发起比较时仍能展开比较；Reflog 不显示或关闭历史比较。
    @Test("变更集命令按可见详情路由")
    func routes() async throws {
        let fixture = try await ChangesetFixture.make()
        defer { fixture.close() }

        try await fixture.load()
        fixture.showWindow()
        let session = fixture.session

        // 历史比较关闭时作用于提交详情
        session.comparison.close()
        try expandAndCollapse(fixture, target: 0, view: .history)

        // 历史多选发起比较时作用于比较
        fixture.open(session.comparison)
        try await fixture.waitForChanges()
        session.history.selectedIDs = Set(fixture.commits.prefix(2).map(\.id))
        try expandAndCollapse(fixture, target: 1, view: .history)

        // 储藏
        try expandAndCollapse(fixture, target: 2, view: .stashes)

        // Reflog 换选择后视图与命令都用自己的提交，留在后台的历史比较保持原样
        try await selectReflog(fixture)
        try expandAndCollapse(fixture, target: 3, view: .reflog)

        // 分支整理与请求
        try expandAndCollapse(fixture, target: 4, view: .branchesReview)
        try await fixture.loadRequest()
        try expandAndCollapse(fixture, target: 5, view: .pullRequests)
    }

    /// 每个禁用条件都经过窗口菜单验证和两个真实动作，缓存与展开集合同时保持不变。
    @Test("不可见、空结果、失败与读取中的变更集都不接收命令")
    func unavailable() async throws {
        let fixture = try await ChangesetFixture.make()
        defer { fixture.close() }

        try await fixture.load()
        fixture.showWindow()
        let session = fixture.session
        let window = try #require(fixture.window)

        try await historyBoundaries(fixture)
        try await comparisonBoundaries(fixture)
        detailBoundaries(fixture)
        try await requestBoundaries(fixture)

        // 仓库管理遮住详情时同样禁用
        session.activeView = .history
        window.showRepositories()
        #expect(window.showsManager)
        assertUnavailable(fixture)
    }

    /// 切到视图后经菜单验证展开再收起，只有目标详情的展开集合变化。
    private func expandAndCollapse(_ fixture: ChangesetFixture, target: Int, view: RepositoryView) throws {
        let session = fixture.session
        let window = try #require(fixture.window)
        session.activeView = view
        fixture.seedExpansions()
        let before = fixture.expansions

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

    /// 在实际的提交详情视图里换 Reflog 选择，内容取 Reflog 自己的提交，历史比较的目标不变。
    private func selectReflog(_ fixture: ChangesetFixture) async throws {
        let session = fixture.session
        session.activeView = .reflog

        let view = NSHostingView(rootView: CommitDetailView(history: session.reflog.detail, session: session))
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        view.layoutSubtreeIfNeeded()

        let before = session.comparison.target
        let entry = try #require(session.reflog.entries.first { $0.commit.id == fixture.commits[1].id })
        session.reflog.selectedID = entry.id
        try await fixture.waitForChanges()
        view.layoutSubtreeIfNeeded()

        guard case .commit(let commit) = session.commitDetailContent(for: session.reflog.detail) else {
            Issue.record("Reflog 应显示自己的提交")
            return
        }

        #expect(commit.id == fixture.commits[1].id)
        #expect(session.comparison.target == before)
    }

    /// 历史的比较未显示变更集、树视图、整页详情、空选、多选与读取中都禁用。
    private func historyBoundaries(_ fixture: ChangesetFixture) async throws {
        let session = fixture.session
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
    }

    /// 空比较与读取失败没有可操作文件，读取中的比较不能回退到背后的提交。
    private func comparisonBoundaries(_ fixture: ChangesetFixture) async throws {
        let session = fixture.session
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

        // 关闭比较后回到提交详情
        session.comparison.close()
        #expect(session.canExpandChanges)
    }

    /// Reflog、储藏、分支整理、工作区与未加载的请求在各自的禁用条件下都不接收命令。
    private func detailBoundaries(_ fixture: ChangesetFixture) {
        let session = fixture.session
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

        for view in [RepositoryView.workingCopy, .pullRequests] {
            session.activeView = view
            assertUnavailable(fixture)
        }
    }

    /// 请求的 Conversation、Commits 与需要获取状态均不操作缓存的比较。
    private func requestBoundaries(_ fixture: ChangesetFixture) async throws {
        let session = fixture.session
        try await fixture.loadRequest()
        session.activeView = .pullRequests

        for page in [RepositoryPullRequestState.Page.conversation, .commits] {
            session.pullRequests.page = page
            assertUnavailable(fixture)
        }

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
