import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Sidebar Menus

extension OperationWiringTests {
    /// HEAD 分支的推送、拉取与同步各带以跟踪分支为对象的 ⌥ 快速版本；其它本地分支是推送与 Push To；远端分支的快速拉取把它并入 HEAD。
    @Test("分支右键菜单的推送与拉取一组")
    func branchSyncMenu() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let (main, side, upstream) = try fixture.branches()
        let session = fixture.session

        let head = HostedMenu(BranchSyncMenu(session: session, reference: main) { _ in })
        #expect(head.titles == [
            AppLocalization.text("sync.push"),
            AppLocalization.text("sync.quickPushNamed", "main", "origin/main"),
            AppLocalization.text("sync.pull"),
            AppLocalization.text("sync.quickPullInto", "origin/main", "main"),
            AppLocalization.text("sync.syncMenu"),
            AppLocalization.text("sync.quickSyncNamed", "main", "origin/main"),
        ])
        #expect(head.alternates == [false, true, false, true, false, true])

        let local = HostedMenu(BranchSyncMenu(session: session, reference: side) { _ in })
        #expect(local.titles == [
            AppLocalization.text("sync.push"),
            AppLocalization.text("branch.pushToMenu", "side"),
        ])
        #expect(!local.alternates.contains(true))

        let remote = HostedMenu(BranchSyncMenu(session: session, reference: upstream) { _ in })
        #expect(remote.titles == [
            AppLocalization.text("sync.pull"),
            AppLocalization.text("sync.quickPullNamed", "origin/main"),
        ])
        #expect(remote.alternates == [false, true])
        #expect(remote.enabled == [true, true])

        // Push To 打开推送任意版本的对话框，预选这个分支
        var requests: [SyncDialogRequest] = []
        session.onSyncRequest = { requests.append($0) }
        local.perform(AppLocalization.text("branch.pushToMenu", "side"))
        try await FileViewsTests.wait { !requests.isEmpty }

        #expect(requests.first?.kind == .pushRevision)
        #expect(requests.first?.preselection == "side")
    }

    /// HEAD 分支的合并与变基以跟踪分支为对象，另有 Rebase Onto；其它分支只有把它并入 HEAD 的合并，变基到它上面经拖放或变基对话框。
    @Test("分支右键菜单的合并与变基一组")
    func branchIntegrationMenu() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let (main, side, _) = try fixture.branches()
        let session = fixture.session

        let head = HostedMenu(BranchIntegrationMenu(session: session, reference: main) { _ in })
        #expect(head.titles == [
            AppLocalization.text("sync.merge"),
            AppLocalization.text("sync.quickMergeInto", "origin/main", "main"),
            AppLocalization.text("sync.rebaseMenu"),
            AppLocalization.text("sync.quickRebaseOn", "main", "origin/main"),
            AppLocalization.text("rewrite.rebaseOnto.menu"),
        ])
        #expect(head.alternates == [false, true, false, true, false])

        let other = HostedMenu(BranchIntegrationMenu(session: session, reference: side) { _ in })
        #expect(other.titles == [AppLocalization.text("sync.merge")])
        #expect(other.alternates == [false])
        #expect(!other.enabled.contains(false))

        // 变基对话框按请求预选目标分支；没有预选时用 HEAD 的跟踪分支
        var requests: [SyncDialogRequest] = []
        session.onSyncRequest = { requests.append($0) }
        session.requestSyncDialog(.rebase, preselecting: side.id)
        try await FileViewsTests.wait { !requests.isEmpty }

        let request = try #require(requests.first)
        #expect(request.kind == .rebase)
        #expect(SyncDialog.rebaseTarget(preselection: request.preselection, in: session) == "refs/heads/side")
        #expect(SyncDialog.rebaseTarget(preselection: nil, in: session) == "refs/remotes/origin/main")
    }

    /// HEAD 没有跟踪分支时，HEAD 分支一组没有快速版本。
    @Test("没有跟踪分支时没有快速操作")
    func noUpstream() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        _ = try await fixture.runner.run(["branch", "--unset-upstream"])
        fixture.session.refresh(full: true)
        await fixture.session.refreshTask?.value
        try await FileViewsTests.wait {
            fixture.session.headBranch?.upstream == nil && !fixture.session.history.isLoading
        }

        let (main, _, _) = try fixture.branches()
        let sync = HostedMenu(BranchSyncMenu(session: fixture.session, reference: main) { _ in })
        let integration = HostedMenu(BranchIntegrationMenu(session: fixture.session, reference: main) { _ in })

        #expect(!sync.alternates.contains(true))
        #expect(!integration.alternates.contains(true))
    }

    /// 推送任意版本的预选：分支推到它跟踪的分支或同名分支，标签推到同名标签，远端取跟踪的远端。
    @Test("Push To 对话框的预选")
    func pushRevisionDefaults() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let session = fixture.session

        let head = SyncDialog.pushRevisionDefaults(preselection: nil, in: session)
        #expect([head.source, head.remote, head.destination] == ["main", "origin", "main"])

        let side = SyncDialog.pushRevisionDefaults(preselection: "side", in: session)
        #expect([side.source, side.remote, side.destination] == ["side", "origin", "side"])

        let tag = SyncDialog.pushRevisionDefaults(preselection: "v1", in: session)
        #expect([tag.source, tag.remote, tag.destination] == ["v1", "origin", "refs/tags/v1"])
    }

    /// 标签菜单的管理项：发布与推送一组，新建分支与删除一组；Push To 交给推送对话框。
    @Test("标签右键菜单的管理项")
    func tagManagementMenu() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let tag = try #require(fixture.session.tags.first { $0.name == "v1" })
        var pushed: [String] = []

        let menu = HostedMenu(
            TagManagementMenu(
                session: fixture.session,
                reference: tag,
                pushTo: { pushed.append($0.name) },
                createBranch: { _ in }
            )
        )

        #expect(menu.titles == [
            AppLocalization.text("tag.publishMenu", "v1"),
            AppLocalization.text("tag.pushToMenu", "v1"),
            "",
            AppLocalization.text("tag.createBranch", "v1"),
            AppLocalization.text("reference.deleteMenu", "v1"),
        ])

        menu.perform(AppLocalization.text("tag.pushToMenu", "v1"))
        try await FileViewsTests.wait { !pushed.isEmpty }
        #expect(pushed == ["v1"])
    }
}

// MARK: - HostedMenu

/// SwiftUI 菜单内容转成的 AppKit 菜单，按标题、⌥ 备选与可用状态检查。
@MainActor
struct HostedMenu {
    /// 转成的菜单。
    let menu: NSMenu

    /// 各项标题；分隔线为空字符串。
    var titles: [String] {
        menu.items.map { $0.isSeparatorItem ? "" : $0.title }
    }

    /// 各项是否为按住 ⌥ 时替换上一项的备选项。
    var alternates: [Bool] {
        menu.items.filter { !$0.isSeparatorItem }.map { $0.isAlternate && $0.keyEquivalentModifierMask == .option }
    }

    /// 各项是否可用。
    var enabled: [Bool] {
        menu.items.filter { !$0.isSeparatorItem }.map(\.isEnabled)
    }

    /// 由菜单内容生成。
    init(_ content: some View) {
        menu = NSHostingMenu(rootView: content)
        menu.update()
    }

    /// 选中标题相同的一项；直接调用菜单项的动作，不经过菜单的跟踪。
    func perform(_ title: String) {
        guard let index = menu.items.firstIndex(where: { $0.title == title }) else {
            Issue.record("找不到菜单项：\(title)")
            return
        }

        let item = menu.items[index]

        if let action = item.action, let target = item.target as AnyObject? {
            _ = target.perform(action, with: item)
        }
    }
}

// MARK: - Fixture Branches

extension OperationWiringTests.Fixture {
    /// 当前分支 main、本地分支 side 与 main 跟踪的 origin/main。
    @MainActor
    func branches() throws -> (main: RepositoryReference, side: RepositoryReference, upstream: RepositoryReference) {
        let branches = session.history.branches

        return (
            try #require(branches.first { $0.id == "refs/heads/main" }),
            try #require(branches.first { $0.id == "refs/heads/side" }),
            try #require(branches.first { $0.id == "refs/remotes/origin/main" })
        )
    }
}
