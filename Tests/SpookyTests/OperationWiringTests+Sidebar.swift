import AppKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Sidebar Menus

extension OperationWiringTests {
    /// 分支右键菜单的推送、拉取、合并与变基两组随分支是否为 HEAD、是否有跟踪分支变化；
    /// Push To 与变基对话框的预选；标签菜单的管理项；Working Copy 右键菜单的分组、快速版本与发布的去向。
    @Test("分支、标签与 Working Copy 右键菜单的项与预选")
    func referenceMenus() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        try await checkBranchSyncMenu(in: fixture)
        try checkBranchIntegrationMenu(in: fixture)
        checkPushRevisionDefaults(in: fixture)
        try await checkTagManagementMenu(in: fixture)
        try await checkWorkingCopyMenu(in: fixture)
        try await checkWithoutUpstream(in: fixture)
    }

    /// HEAD 分支的拉取、推送与同步各带以跟踪分支为对象的 ⌥ 快速版本，另有安全强推；其它本地分支只有安全强推；
    /// 本地分支随后另起一组发布与 Push To；远端分支的快速拉取把它并入 HEAD。
    /// 安全强推与 Push To 打开的对话框预选被点击的分支。
    private func checkBranchSyncMenu(in fixture: Fixture) async throws {
        let (main, side, upstream) = try fixture.branches()
        let session = fixture.session

        // HEAD 分支
        let head = HostedMenu(BranchSyncMenu(session: session, reference: main) { _ in })

        #expect(head.titles == [
            AppLocalization.text("sync.pullMenu"),
            AppLocalization.text("sync.quickPullInto", "origin/main", "main"),
            AppLocalization.text("workspace.pushMenu"),
            AppLocalization.text("sync.quickPushNamed", "main", "origin/main"),
            AppLocalization.text("sync.forcePushMenu"),
            AppLocalization.text("sync.syncMenu"),
            AppLocalization.text("sync.quickSyncNamed", "main", "origin/main"),
            "",
            AppLocalization.text("branch.publishMenu", "main"),
            AppLocalization.text("branch.pushToMenu", "main"),
        ])

        #expect(head.alternates == [false, true, false, true, false, false, true, false, false])

        // 其它本地分支没有普通推送
        let local = HostedMenu(BranchSyncMenu(session: session, reference: side) { _ in })

        #expect(local.titles == [
            AppLocalization.text("sync.forcePushMenu"),
            "",
            AppLocalization.text("branch.publishMenu", "side"),
            AppLocalization.text("branch.pushToMenu", "side"),
        ])

        #expect(!local.alternates.contains(true))

        // 远端分支
        let remote = HostedMenu(BranchSyncMenu(session: session, reference: upstream) { _ in })

        #expect(remote.titles == [
            AppLocalization.text("branch.pullMenu", "origin/main"),
            AppLocalization.text("sync.quickPullNamed", "origin/main"),
        ])

        #expect(remote.alternates == [false, true])
        #expect(remote.enabled == [true, true])

        // 菜单项的动作经 SwiftUI 转发，等请求到达
        var requests: [SyncDialogRequest] = []
        session.onSyncRequest = { requests.append($0) }
        local.perform(AppLocalization.text("branch.pushToMenu", "side"))
        local.perform(AppLocalization.text("sync.forcePushMenu"))
        await until { requests.count == 2 }

        #expect(requests.map(\.kind) == [.pushRevision, .forcePush])
        #expect(requests.map(\.preselection) == ["side", "refs/heads/side"])
    }

    /// 只有 HEAD 分支有合并与变基，以跟踪分支为对象，另有 Rebase Onto Revision…；其它分支没有这一组，
    /// 把它并入 HEAD 经拖放或 HEAD 分支的菜单；变基对话框按请求预选目标分支，没有预选时用 HEAD 的跟踪分支。
    private func checkBranchIntegrationMenu(in fixture: Fixture) throws {
        let (main, side, upstream) = try fixture.branches()
        let session = fixture.session

        let head = HostedMenu(BranchIntegrationMenu(session: session, reference: main) { _ in })

        #expect(head.titles == [
            AppLocalization.text("workspace.mergeMenu"),
            AppLocalization.text("sync.quickMergeInto", "origin/main", "main"),
            AppLocalization.text("workspace.rebaseMenu"),
            AppLocalization.text("sync.quickRebaseOn", "main", "origin/main"),
            AppLocalization.text("branch.rebaseOntoMenu"),
        ])

        #expect(head.alternates == [false, true, false, true, false])

        for other in [side, upstream] {
            #expect(HostedMenu(BranchIntegrationMenu(session: session, reference: other) { _ in }).titles.isEmpty)
        }

        // 请求同步交给回调
        var requests: [SyncDialogRequest] = []
        session.onSyncRequest = { requests.append($0) }
        session.requestSyncDialog(.rebase, preselecting: side.id)

        let request = try #require(requests.first)
        let preselected = SyncDialog.rebaseTarget(preselection: request.preselection, in: session)

        #expect(request.kind == .rebase)
        #expect(preselected == "refs/heads/side")
        #expect(SyncDialog.rebaseTarget(preselection: nil, in: session) == "refs/remotes/origin/main")
    }

    /// 推送任意版本的预选：分支推到它跟踪的分支或同名分支，标签推到同名标签，远端取跟踪的远端。
    private func checkPushRevisionDefaults(in fixture: Fixture) {
        let session = fixture.session

        let head = SyncDialog.pushRevisionDefaults(preselection: nil, in: session)
        #expect([head.source, head.remote, head.destination] == ["main", "origin", "main"])

        let side = SyncDialog.pushRevisionDefaults(preselection: "side", in: session)
        #expect([side.source, side.remote, side.destination] == ["side", "origin", "side"])

        let tag = SyncDialog.pushRevisionDefaults(preselection: "v1", in: session)
        #expect([tag.source, tag.remote, tag.destination] == ["v1", "origin", "refs/tags/v1"])
    }

    /// 标签菜单的管理项：发布与推送一组，新建分支与删除一组；Push To 交给推送对话框。
    private func checkTagManagementMenu(in fixture: Fixture) async throws {
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

        // 菜单项的动作经 SwiftUI 转发，等回调到达
        menu.perform(AppLocalization.text("tag.pushToMenu", "v1"))
        await until { !pushed.isEmpty }

        #expect(pushed == ["v1"])
    }

    /// Working Copy 的右键菜单分七组；推送、拉取、合并与变基的 ⌥ 快速版本写出 HEAD 与它的跟踪分支，快照另有快速版本。
    /// Check Out 子菜单按公共顺序列出本地分支，HEAD 分支打勾；Publish… 打开发布仓库。
    private func checkWorkingCopyMenu(in fixture: Fixture) async throws {
        let session = fixture.session
        let (_, side, _) = try fixture.branches()

        // 发布仓库要求有登录的账号
        let defaults = try #require(UserDefaults(suiteName: fixture.directory.appending(path: "defaults").path))
        let accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials())

        _ = try accounts.save(
            HostingUser(username: "me", name: nil),
            on: .github,
            authentication: .personalAccessToken,
            token: "t"
        )

        session.pullRequests.accounts = accounts

        let menu = HostedMenu(
            WorkingCopyMenu(
                session: session,
                request: { _ in },
                copyPath: { },
                revealFinder: { },
                openTerminal: { }
            )
        )

        let text = { (key: String) in AppLocalization.text(key) }

        #expect(menu.titles == [
            text("workspace.checkoutMenu"),
            "",
            text("stash.snapshotMenu"),
            text("stash.quickSnapshotMenu"),
            "",
            text("workspace.pushMenu"),
            AppLocalization.text("sync.quickPushNamed", "main", "origin/main"),
            text("workspace.pushRevisionMenu"),
            text("sync.pullMenu"),
            AppLocalization.text("sync.quickPullInto", "origin/main", "main"),
            text("workspace.publishMenu"),
            "",
            text("working.discardAllMenu"),
            text("workspace.resetMenu"),
            "",
            text("workspace.mergeMenu"),
            AppLocalization.text("sync.quickMergeInto", "origin/main", "main"),
            text("workspace.rebaseMenu"),
            AppLocalization.text("sync.quickRebaseOn", "main", "origin/main"),
            text("files.applyPatch.menu"),
            "",
            text("externalTool.compare"),
            "",
            text("workspace.copyPathMenu"),
            text("action.revealFinder"),
            text("action.openTerminal"),
        ])

        #expect(menu.alternates == [
            false, false, true, false, true, false, false, true, false,
            false, false, false, true, false, true, false, false, false, false, false,
        ])

        // Check Out 子菜单：main 在前并打勾，分隔线后是检出任意版本
        let checkout = try #require(menu.menu.items.first?.submenu)

        #expect(checkout.items.map { $0.isSeparatorItem ? "" : $0.title } == [
            "main", "side", "", text("workspace.checkoutRevisionMenu"),
        ])
        #expect(checkout.items.first?.state == .on)

        // Publish… 打开发布仓库的对话框
        var publications: [PullRequestRequest] = []
        session.pullRequests.onRequest = { publications.append($0) }

        let publish = menu.menu.items.first { $0.title == text("workspace.publishMenu") }
        #expect(publish?.isEnabled ?? false)

        menu.perform(text("workspace.publishMenu"))
        await until { !publications.isEmpty }

        guard case .publish = publications.first else {
            Issue.record("Publish… 应当打开发布仓库的对话框")
            return
        }

        await checkBranchPublish(side, in: session)
    }

    /// 本地分支菜单的 Publish 仍打开发布这一个分支的对话框，不随 Working Copy 的 Publish… 改为发布仓库。
    private func checkBranchPublish(_ side: RepositoryReference, in session: RepositorySession) async {
        var requests: [RepositoryActionRequest] = []
        let sidebar = RepositorySidebarView(
            session: session,
            selectionChanged: { },
            openTerminal: { },
            revealFinder: { },
            copyPath: { },
            request: { requests.append($0) },
            showActivity: { }
        )

        HostedMenu(sidebar.branchMenu(side)).perform(AppLocalization.text("branch.publishMenu", "side"))
        await until { !requests.isEmpty }

        #expect(requests.first?.kind == .publish)
        #expect(requests.first?.localBranch == "side")
    }

    /// HEAD 没有跟踪分支时，HEAD 分支一组没有快速版本。
    private func checkWithoutUpstream(in fixture: Fixture) async throws {
        let session = fixture.session

        // 刷新期间同步开始读引用，一起等完
        _ = try await fixture.runner.run(["branch", "--unset-upstream"])
        session.refresh(full: true)
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
        try #require(session.headBranch?.upstream == nil)

        let (main, _, _) = try fixture.branches()
        let sync = HostedMenu(BranchSyncMenu(session: session, reference: main) { _ in })
        let integration = HostedMenu(BranchIntegrationMenu(session: session, reference: main) { _ in })

        #expect(!sync.alternates.contains(true))
        #expect(!integration.alternates.contains(true))
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
        menu.items
            .filter { !$0.isSeparatorItem }
            .map { $0.isAlternate && $0.keyEquivalentModifierMask == .option }
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
    func branches() throws -> (
        main: RepositoryReference,
        side: RepositoryReference,
        upstream: RepositoryReference
    ) {
        let branches = session.history.branches

        return (
            try #require(branches.first { $0.id == "refs/heads/main" }),
            try #require(branches.first { $0.id == "refs/heads/side" }),
            try #require(branches.first { $0.id == "refs/remotes/origin/main" })
        )
    }
}
