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
    /// 已有父分支时只显示它（打勾、不可点）与移除，移除后回到建议。
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
    /// HEAD 分支没有检出一组；其它本地分支以 Check Out “X” 开头，没有普通推送与合并，安全强推在发布之前；
    /// 远端分支以 Pull “X”… 开头，没有合并；三者末尾都是导出、比较、在历史中显示与复制名字；多选的删除写出个数。
    private func checkBranchMenuGroups(_ sidebar: RepositorySidebarView, in fixture: Fixture) throws {
        let (main, side, upstream) = try fixture.branches()
        let text = { (key: String, name: String) in AppLocalization.text(key, name) }

        // HEAD 分支
        let head = HostedMenu(sidebar.branchMenu(main)).titles

        #expect(!head.contains(text("branch.checkoutNamed", "main")))
        #expect(!head.contains(text("worktree.checkoutBranch", "main")))
        #expect(head.contains(AppLocalization.text("sync.forcePushMenu")))
        #expect(head.contains(text("branch.pushToMenu", "main")))
        #expect(Array(head.suffix(5)) == Self.trailingTitles("main", copy: "branch.copyName"))

        // 其它本地分支
        let local = HostedMenu(sidebar.branchMenu(side)).titles
        let forcePush = local.firstIndex(of: AppLocalization.text("sync.forcePushMenu"))
        let publish = local.firstIndex(of: text("branch.publishMenu", "side"))

        #expect(local.first == text("branch.checkoutNamed", "side"))
        #expect(!local.contains(AppLocalization.text("workspace.pushMenu")))
        #expect(!local.contains(AppLocalization.text("sync.merge")))
        #expect(local.contains(text("reference.deleteMenu", "side")))
        #expect(try #require(forcePush) < #require(publish))
        #expect(Array(local.suffix(5)) == Self.trailingTitles("side", copy: "branch.copyName"))

        // 远端分支
        let remote = HostedMenu(sidebar.branchMenu(upstream)).titles

        #expect(remote.first == text("branch.pullMenu", "origin/main"))
        #expect(remote.contains(text("branch.trackMenu", "origin/main")))
        #expect(!remote.contains(AppLocalization.text("sync.merge")))
        #expect(Array(remote.suffix(5)) == Self.trailingTitles("origin/main", copy: "branch.copyRemoteNameMenu"))

        // 多选两个本地分支：删除写出个数，含当前分支时不可用
        fixture.session.history.selectedReferences = [main.id, side.id]
        defer { fixture.session.history.selectedReferences = [] }

        let multiple = HostedMenu(sidebar.branchMenu(side))

        #expect(multiple.titles.last == AppLocalization.text("branch.deleteMenu.multiple", 2))
        #expect(multiple.enabled.suffix(1) == [false])
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

        // 仓库正在写入时不删除
        let location = try #require(session.repository)
        #expect(RepositoryWriteLocks.shared.acquire(location))
        defer { RepositoryWriteLocks.shared.release(location) }

        #expect(press(["refs/heads/side"]) == nil)
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
