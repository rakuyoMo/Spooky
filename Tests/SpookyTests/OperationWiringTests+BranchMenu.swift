import AppKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Branch Menu

extension OperationWiringTests {
    /// 分支菜单按 HEAD、其它本地分支与远端分支区分，各项作用于被点击的分支；文件夹右键预填文件夹路径；
    /// ⌘⌫ 按所选对象打开各自的删除确认，没有可删除的选择时不可用。
    @Test("分支与文件夹菜单的项与目标，⌘⌫ 的路由")
    func branchMenus() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        var requests: [RepositoryActionRequest] = []
        let sidebar = RepositorySidebarView(
            session: fixture.session,
            selectionChanged: { },
            openTerminal: { },
            revealFinder: { },
            copyPath: { },
            request: { requests.append($0) },
            showActivity: { }
        )

        try checkBranchMenuGroups(sidebar, in: fixture)
        try await checkBranchMenuTargets(sidebar, requests: { requests }, in: fixture)
        try await checkFolderMenus(sidebar, requests: { requests }, in: fixture)
        try await checkUpstreamStates(sidebar, in: fixture)
        try await checkMultipleSelection(sidebar, in: fixture)
        try checkDeleteCommand(sidebar, in: fixture)
    }

    /// 非 HEAD 分支的安全强推以被点击的分支与它的跟踪分支为默认值，推的是这个分支而不是 HEAD；
    /// 远端分支在核对之后被别处改动时 Git 按租约拒绝，远端保持别处推上去的版本，获取之后以新的期望值才能推上去。
    @Test("非 HEAD 分支的安全强推绑定被点击的分支，远端变化后按租约拒绝")
    func forcePushOtherBranch() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let runner = fixture.runner
        let session = fixture.session
        let remote = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: remote) }

        // origin 换成单独的裸仓库，推上 main 与 side，side 跟踪 origin/side
        _ = try await runner.run(["init", "--bare", "-q", remote.path])
        _ = try await runner.run(["config", "--local", "remote.origin.url", remote.path])
        _ = try await runner.run(["push", "-q", "origin", "main", "side"])
        _ = try await runner.run(["branch", "-q", "--set-upstream-to=origin/side", "side"])
        await Self.reload(session)

        // 默认值：被点击的分支与它的跟踪分支；没有预选时是 HEAD 分支
        let defaults = SyncDialog.forcePushDefaults(preselection: "refs/heads/side", in: session)
        let head = SyncDialog.forcePushDefaults(preselection: nil, in: session)

        #expect([defaults.source, defaults.destination] == ["refs/heads/side", "refs/remotes/origin/side"])
        #expect([head.source, head.destination] == ["refs/heads/main", "refs/remotes/origin/main"])

        // 本地 side 退回 A，需要强推；别处把远端的 side 改成 B，本地的 origin/side 仍是 S
        let a = try #require(fixture.ids["A"])
        let b = try #require(fixture.ids["B"])
        let main = try await RepositoryReferences(runner: runner).resolve("refs/heads/main")

        _ = try await runner.run(["branch", "-q", "-f", "side", a])
        _ = try await runner.run(["push", "-q", "--force", remote.path, b + ":refs/heads/side"])
        await Self.reload(session)

        let rejection = try await forcePushSide(in: fixture)

        #expect(rejection?.details.contains("stale info") ?? false)
        #expect(try await Self.remoteTip("side", in: remote, runner: runner) == b)
        #expect(try await Self.remoteTip("main", in: remote, runner: runner) == main)
        #expect(session.status?.branch.head == "main")

        // 获取之后期望值是 B，强推成功，远端的 main 不动
        _ = try await runner.run(["fetch", "-q", "origin"])
        await Self.reload(session)

        #expect(try await forcePushSide(in: fixture) == nil)
        #expect(try await Self.remoteTip("side", in: remote, runner: runner) == a)
        #expect(try await Self.remoteTip("main", in: remote, runner: runner) == main)
    }

    /// 没有父分支时，父分支子菜单列出不含分支自己的基准分支作为建议，选中即设为父分支，另一项打开设置父分支对话框；
    /// 已有父分支时只显示它（打勾、不可点）与移除，移除后回到建议；落后父分支时跟踪一组另有 Update Branch 的两项，
    /// Update Branch 对话框只列设了父分支的分支，落后一个提交时说明用单数。
    @Test("父分支子菜单的建议、当前值与移除")
    func parentBranchMenu() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        let session = fixture.session
        let (main, side, _) = try fixture.branches()
        let other = AppLocalization.text("branch.parent.setMenu")
        let remove = AppLocalization.text("branch.parent.remove")

        var references: [String] = []
        session.onReferenceRequest = { request in
            if case .setParent(let branch) = request {
                references.append(branch.id)
            }
        }

        // 没有父分支：基准分支 main 是 side 的建议，main 自己没有建议
        let suggestions = HostedMenu(BranchParentMenu(session: session, branch: side))

        #expect(suggestions.titles == ["main", "", other])
        #expect(HostedMenu(BranchParentMenu(session: session, branch: main)).titles == [other])

        suggestions.perform(other)
        await until { !references.isEmpty }

        #expect(references == ["refs/heads/side"])

        // 选中建议即设为父分支
        suggestions.perform("main")
        await session.writeTask?.value
        await Self.reload(session)

        #expect(session.history.snapshot?.metadata(for: side.id).parent == "refs/heads/main")

        // 设了父分支、且落后父分支：跟踪一组多出 Update “side”… 与按住 ⌥ 换上的 Quick Update “side”，两项都可用；
        // 没有父分支的 main 没有这两项
        let tracking = HostedMenu(BranchUpstreamMenus(session: session, reference: side))

        #expect(tracking.titles.suffix(2) == [
            AppLocalization.text("branch.updateNamed", "side"),
            AppLocalization.text("branch.quickUpdateNamed", "side"),
        ])

        #expect(tracking.alternates.suffix(2) == [false, true])
        #expect(tracking.enabled.suffix(2) == [true, true])
        #expect(HostedMenu(BranchUpstreamMenus(session: session, reference: main)).titles.count == 2)
        #expect(UpdateBranchDialog(session: session, branch: side) { }.candidates.map(\.id) == [side.id])

        #expect(
            UpdateBranchDialog.summary(behind: 1, parent: "main")
                == AppLocalization.text("review.update.integrates.one", "main")
        )

        // 已有父分支：当前值打勾且不可点，另有移除
        let current = HostedMenu(BranchParentMenu(session: session, branch: side))

        #expect(current.titles == ["main", "", remove])
        #expect(current.enabled == [false, true])
        #expect(current.menu.items.first?.state == .on)

        current.perform(remove)
        await session.writeTask?.value
        await Self.reload(session)

        #expect(session.history.snapshot?.metadata(for: side.id).parent == nil)
        #expect(HostedMenu(BranchParentMenu(session: session, branch: side)).titles == ["main", "", other])
    }
}

// MARK: - Checks

extension OperationWiringTests {
    /// 本地分支菜单的分组：HEAD 分支从置顶开始，依次是同步、发布、跟踪、合并与变基、归档、重命名与删除、新建、导出与比较、
    /// 在历史中显示与复制；其它本地分支以检出一组开头，同步一组只有安全强推，没有合并与变基；
    /// 远端分支以 Pull “X”… 开头，没有合并；三者末尾都是导出、比较、在历史中显示与复制名字。
    private func checkBranchMenuGroups(_ sidebar: RepositorySidebarView, in fixture: Fixture) throws {
        let (main, side, upstream) = try fixture.branches()
        let text = { (key: String, name: String) in AppLocalization.text(key, name) }
        let session = fixture.session

        // HEAD 分支
        #expect(HostedMenu(sidebar.branchMenu(main)).titles == [
            text("branch.pinNamed", "main"),
            "",
            AppLocalization.text("sync.pullMenu"),
            AppLocalization.text("sync.quickPullInto", "origin/main", "main"),
            AppLocalization.text("workspace.pushMenu"),
            AppLocalization.text("sync.quickPushNamed", "main", "origin/main"),
            AppLocalization.text("sync.forcePushMenu"),
            AppLocalization.text("sync.syncMenu"),
            AppLocalization.text("sync.quickSyncNamed", "main", "origin/main"),
            "",
            text("branch.publishMenu", "main"),
            text("branch.pushToMenu", "main"),
            "",
            AppLocalization.text("branch.tracking"),
            AppLocalization.text("branch.parent"),
            "",
            AppLocalization.text("workspace.mergeMenu"),
            AppLocalization.text("sync.quickMergeInto", "origin/main", "main"),
            AppLocalization.text("workspace.rebaseMenu"),
            AppLocalization.text("sync.quickRebaseOn", "main", "origin/main"),
            AppLocalization.text("branch.rebaseOntoMenu"),
            "",
            text("branch.archiveNamed", "main"),
            AppLocalization.text("review.skipAutoArchive"),
            "",
            text("reference.renameMenu", "main"),
            text("reference.deleteMenu", "main"),
            "",
            text("branch.createFromMenu", "main"),
            text("tag.createFrom", "main"),
            session.pullRequestText("forBranch.create", "main"),
            "",
        ] + Self.trailingTitles("main", copy: "branch.copyName"))

        // 其它本地分支
        #expect(HostedMenu(sidebar.branchMenu(side)).titles == [
            text("branch.checkoutNamed", "side"),
            text("worktree.checkoutBranch", "side"),
            "",
            text("branch.pinNamed", "side"),
            "",
            AppLocalization.text("sync.forcePushMenu"),
            "",
            text("branch.publishMenu", "side"),
            text("branch.pushToMenu", "side"),
            "",
            AppLocalization.text("branch.tracking"),
            AppLocalization.text("branch.parent"),
            "",
            text("branch.archiveNamed", "side"),
            AppLocalization.text("review.skipAutoArchive"),
            "",
            text("reference.renameMenu", "side"),
            text("reference.deleteMenu", "side"),
            "",
            text("branch.createFromMenu", "side"),
            text("tag.createFrom", "side"),
            session.pullRequestText("forBranch.create", "side"),
            "",
        ] + Self.trailingTitles("side", copy: "branch.copyName"))

        // 分支整理的行菜单与侧边栏同一分支的菜单相同
        let item = BranchesReviewItem(reference: side, comparison: nil, condition: nil, pullRequest: nil)
        let review = BranchesReviewMenu(session: session, item: item, items: [item]) { _ in }
        #expect(HostedMenu(review).titles == HostedMenu(sidebar.branchMenu(side)).titles)

        // 远端分支
        let remote = HostedMenu(sidebar.branchMenu(upstream)).titles

        #expect(remote.first == text("branch.pullMenu", "origin/main"))
        #expect(remote.contains(text("branch.trackMenu", "origin/main")))
        #expect(!remote.contains(AppLocalization.text("sync.merge")))
        #expect(Array(remote.suffix(5)) == Self.trailingTitles("origin/main", copy: "branch.copyRemoteNameMenu"))
    }

    /// 导出、比较与新建分支作用于被点击的分支，不借用 HEAD。
    private func checkBranchMenuTargets(
        _ sidebar: RepositorySidebarView,
        requests: @escaping () -> [RepositoryActionRequest],
        in fixture: Fixture
    ) async throws {
        let (_, side, _) = try fixture.branches()
        let session = fixture.session
        let menu = HostedMenu(sidebar.branchMenu(side))

        var revisions: [String] = []
        session.onRevisionRequest = { request in
            switch request {
            case .export(let revision, _, _): revisions.append("export:" + (revision ?? ""))
            case .compare(let base): revisions.append("compare:" + (base ?? ""))
            case .savePatch: revisions.append("savePatch")
            }
        }

        menu.perform(AppLocalization.text("export.menuFrom", "side"))
        menu.perform(AppLocalization.text("branch.compareMenu", "side"))
        menu.perform(AppLocalization.text("branch.createFromMenu", "side"))
        await until { revisions.count == 2 && !requests().isEmpty }

        #expect(revisions == ["export:side", "compare:side"])
        #expect(requests().last?.kind == .create)
        #expect(requests().last?.reference == "refs/heads/side")
    }

    /// 分支文件夹从 HEAD 新建分支、标签文件夹在 HEAD 上新建标签，名称都预填文件夹路径与结尾的 “/”；远端分支的文件夹没有菜单。
    private func checkFolderMenus(
        _ sidebar: RepositorySidebarView,
        requests: @escaping () -> [RepositoryActionRequest],
        in fixture: Fixture
    ) async throws {
        let session = fixture.session
        let count = requests().count

        var references: [String] = []
        session.onReferenceRequest = { references.append(Self.describe($0)) }

        let branch = HostedMenu(sidebar.folderMenu(.branchFolder("feature/ui")))
        let tag = HostedMenu(sidebar.folderMenu(.tagFolder("release")))

        #expect(branch.titles == [AppLocalization.text("branch.createMenu")])
        #expect(tag.titles == [AppLocalization.text("tag.createMenu")])
        #expect(HostedMenu(sidebar.folderMenu(.remoteBranchFolder("origin", "feature"))).titles.isEmpty)

        branch.perform(AppLocalization.text("branch.createMenu"))
        tag.perform(AppLocalization.text("tag.createMenu"))
        await until { requests().count > count && !references.isEmpty }

        let created = try #require(requests().last)

        #expect(created.kind == .create)
        #expect(created.reference == nil)
        #expect(created.name == "feature/ui/")
        #expect(references == ["createTag:HEAD:release/"])
    }

    /// 安全强推与 Remove Tracking 随上游的三种状态变化：上游仍在时都可用，配置的上游已不存在时安全强推不可用、
    /// Remove Tracking 打勾，没有上游时两者都不可用；跟踪子菜单两组按版本候选的顺序排列，当前上游打勾且不可点，不列分支自己。
    private func checkUpstreamStates(_ sidebar: RepositorySidebarView, in fixture: Fixture) async throws {
        let runner = fixture.runner
        let session = fixture.session

        // 另加几个远端分支；side 跟踪已不存在的 origin/gone，solo 没有上游
        for reference in ["refs/remotes/origin/a-feature", "refs/remotes/upstream/main", "refs/remotes/extra/main"] {
            _ = try await runner.run(["update-ref", reference, "HEAD"])
        }

        _ = try await runner.run(["config", "--local", "branch.side.remote", "origin"])
        _ = try await runner.run(["config", "--local", "branch.side.merge", "refs/heads/gone"])
        _ = try await runner.run(["branch", "-q", "solo"])
        await Self.reload(session)

        let (main, side, _) = try fixture.branches()
        let solo = try #require(session.history.branches.first { $0.id == "refs/heads/solo" })
        let forcePush = AppLocalization.text("sync.forcePushMenu")
        let remove = AppLocalization.text("branch.tracking.remove")

        // 一项的 [是否打勾, 是否可用]
        let flags = { (menu: HostedMenu, title: String) in
            menu.item(title).map { [$0.state == .on, $0.isEnabled] }
        }

        // 上游仍在：origin 内 main 在前，远端之间 origin 在前、其余按名字；当前上游打勾且不可点
        let tracking = HostedMenu(BranchTrackingMenu(session: session, branch: main))

        #expect(tracking.titles == [
            AppLocalization.text("branch.tracking.remoteBranches"),
            "origin/main",
            "origin/a-feature",
            "extra/main",
            "upstream/main",
            "",
            AppLocalization.text("branch.tracking.localBranches"),
            "side",
            "solo",
            "",
            remove,
        ])

        #expect(flags(tracking, "origin/main") == [true, false])
        #expect(flags(tracking, "origin/a-feature") == [false, true])
        #expect(flags(tracking, remove) == [false, true])
        #expect(flags(HostedMenu(sidebar.branchMenu(main)), forcePush) == [false, true])

        // 配置的上游已不存在
        let gone = HostedMenu(BranchTrackingMenu(session: session, branch: side))

        #expect(flags(gone, remove) == [true, true])
        #expect(flags(HostedMenu(sidebar.branchMenu(side)), forcePush) == [false, false])

        // 没有上游
        let untracked = HostedMenu(BranchTrackingMenu(session: session, branch: solo))

        #expect(flags(untracked, remove) == [false, false])
        #expect(flags(HostedMenu(sidebar.branchMenu(solo)), forcePush) == [false, false])
    }

    /// 多选引用的菜单按四种组合给出：本地分支有置顶、归档与删除，标签与远端分支只有删除，分支加标签只有比较；
    /// 选中两项时最后比较两者，按版本候选的顺序取基准。选中移到 Working Copy 后，右键原来选过的分支只作用于它自己。
    private func checkMultipleSelection(_ sidebar: RepositorySidebarView, in fixture: Fixture) async throws {
        let session = fixture.session
        let history = session.history

        _ = try await fixture.runner.run(["tag", "v2"])
        await Self.reload(session)

        let (main, side, upstream) = try fixture.branches()
        let feature = try #require(history.branches.first { $0.id == "refs/remotes/origin/a-feature" })
        let compare = { (lhs: String, rhs: String) in AppLocalization.text("reference.compareMenuPair", lhs, rhs) }

        // 在 History 里选中这几项后，右键其中一项
        let menu = { (selection: [RepositoryReference], clicked: RepositoryReference) -> HostedMenu in
            session.activeView = .history
            history.selectedReferences = Set(selection.map(\.id))
            return HostedMenu(sidebar.branchMenu(clicked))
        }

        defer { history.selectedReferences = [] }

        // 两个本地分支：删除写出个数，含当前分支时不可用；比较以 main 为基准
        let locals = menu([side, main], side)

        #expect(Array(locals.titles.suffix(3)) == [
            AppLocalization.text("branch.deleteMenu.multiple", 2),
            "",
            compare("main", "side"),
        ])
        #expect(Array(locals.enabled.suffix(2)) == [false, true])

        // 两个标签、两个远端分支各只有删除与比较；分支加标签只有比较
        let tags = history.snapshot?.references.filter(\.isTag) ?? []
        let v1 = try #require(tags.first)

        #expect(menu(tags, v1).titles == [
            AppLocalization.text("tag.deleteMenu.multiple", 2),
            "",
            compare("v1", "v2"),
        ])
        #expect(menu([feature, upstream], upstream).titles == [
            AppLocalization.text("branch.deleteRemoteMenu.multiple", 2),
            "",
            compare("origin/main", "origin/a-feature"),
        ])

        let mixed = menu([v1, side], v1)

        #expect(mixed.titles == [compare("side", "v1")])

        // 比较打开两者的比较，基准是排在前面的 side
        mixed.perform(compare("side", "v1"))
        await until { session.comparison.target != nil }

        #expect(session.comparison.base?.title == "side")
        #expect(session.comparison.target?.id == v1.objectID)

        // 选中移到 Working Copy：保留的旧选区不算，右键 side 是它自己的菜单
        history.selectedReferences = [main.id, side.id]
        session.activeView = .workingCopy

        #expect(HostedMenu(sidebar.branchMenu(side)).titles.first == AppLocalization.text("branch.checkoutNamed", "side"))
    }

    /// ⌘⌫ 按所选对象打开本地分支、远端分支、标签或远端的删除确认；当前分支、几种引用混选、
    /// 没有可删除的选择或仓库正在写入时不可用。
    private func checkDeleteCommand(_ sidebar: RepositorySidebarView, in fixture: Fixture) throws {
        let session = fixture.session
        let history = session.history

        var references: [String] = []
        session.onReferenceRequest = { references.append(Self.describe($0)) }

        // 依次选中并按一下，记下打开的确认；不可用时记 nil
        let press = { (selection: Set<String>) -> String? in
            session.activeView = .history
            history.selectedReferences = selection

            guard let command = sidebar.deleteCommand else {
                return nil
            }

            command()
            return references.last
        }

        #expect(press(["refs/heads/side"]) == "deleteBranches:side")
        #expect(press(["refs/heads/main"]) == nil)
        #expect(press(["refs/heads/main", "refs/heads/side"]) == nil)
        #expect(press(["refs/remotes/origin/main"]) == "deleteRemoteBranches:origin/main")
        #expect(press(["refs/tags/v1"]) == "deleteTags:v1")
        #expect(press(["refs/heads/side", "refs/tags/v1"]) == nil)
        #expect(press([]) == nil)

        // 远端行与已不存在的子模块
        session.showRemote("origin")
        sidebar.deleteCommand?()

        #expect(references.last == "deleteRemotes:origin")

        session.showSubmodule("missing")
        #expect(sidebar.deleteCommand == nil)

        // 仓库正在写入时照样可以删除，确认后排进队列
        let location = try #require(session.repository)
        let holder = RepositoryWrite(location: location, session: nil, title: "Hold")
        #expect(RepositoryWriteQueue.shared.begin(holder))
        defer { RepositoryWriteQueue.shared.finish(holder) }

        #expect(press(["refs/heads/side"]) == "deleteBranches:side")
    }

    /// 以本地 origin/side 为期望值强推本地的 side，等写入结束；返回这次写入报告的失败，失败里保留 Git 的原文。
    private func forcePushSide(in fixture: Fixture) async throws -> AppFailure? {
        let session = fixture.session
        let branches = session.history.branches
        let side = try #require(branches.first { $0.id == "refs/heads/side" })
        let target = try #require(branches.first { $0.id == "refs/remotes/origin/side" })

        var failure: AppFailure? = nil
        session.onFailure = { failure = $0 }
        defer { session.onFailure = nil }

        #expect(session.forcePush(side, to: target, lease: target.objectID, skipHooks: false))
        await session.writeTask?.value

        return failure
    }
}

// MARK: - Helpers

extension OperationWiringTests {
    /// 分支菜单末尾两组：导出与比较，分隔线，在历史中显示与复制名字。
    private static func trailingTitles(_ name: String, copy: String) -> [String] {
        [
            AppLocalization.text("export.menuFrom", name),
            AppLocalization.text("branch.compareMenu", name),
            "",
            AppLocalization.text("tag.reveal"),
            AppLocalization.text(copy),
        ]
    }

    /// 引用管理请求写成便于比较的文字。
    private static func describe(_ request: ReferenceRequest) -> String {
        switch request {
        case .deleteBranches(let branches): "deleteBranches:" + branches.map(\.name).joined(separator: ",")
        case .deleteRemoteBranches(let branches): "deleteRemoteBranches:" + branches.map(\.name).joined(separator: ",")
        case .deleteTags(let names): "deleteTags:" + names.joined(separator: ",")
        case .deleteRemotes(let names): "deleteRemotes:" + names.joined(separator: ",")
        case .createTag(let revision, let name): "createTag:" + (revision ?? "HEAD") + ":" + name
        default: "other"
        }
    }

    /// 外部改动仓库之后重新读取，等引用与列表读完。
    private static func reload(_ session: RepositorySession) async {
        session.refresh(full: true)
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
    }

    /// 裸仓库里分支指向的提交。
    private static func remoteTip(_ branch: String, in remote: URL, runner: GitRunner) async throws -> String {
        let output = try await runner.run(["ls-remote", remote.path, "refs/heads/" + branch])
        return String(String(decoding: output, as: UTF8.self).prefix { !$0.isWhitespace })
    }
}
