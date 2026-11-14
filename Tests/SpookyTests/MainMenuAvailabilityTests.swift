import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - MainMenuAvailabilityTests

/// 主菜单里随仓库状态变化的可用条件：工作区的显示方式、历史的显示偏好、LFS 子菜单与新建请求。
@MainActor
@Suite("主菜单的可用条件")
struct MainMenuAvailabilityTests {
    /// 同一个仓库窗口依次核对：显示方式只有另一种可选，历史偏好在工作区也能改，LFS 只在仓库启用后可用，
    /// 新建请求只在有远端属于已登录账号的托管服务时可用，取不到服务名与项目时不打开对话框。
    @Test("显示方式、历史偏好、LFS 与新建请求的可用条件")
    func availability() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        try Data("one\n".utf8).write(to: directory.appending(path: "a.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "first"])
        _ = try await runner.run(["remote", "add", "origin", "https://github.com/owner/repo.git"])

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let session = RepositorySession(makeRunner: { _ in runner })
        session.pullRequests.accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials())

        let controller = RepositoryWindowController(
            coordinator: SpookyApplicationController(
                bookmarks: RepositoryBookmarks(defaults: defaults),
                recentDocuments: .ignoring
            ),
            session: session
        )
        defer {
            session.close()
            controller.window?.close()
        }

        // 整套测试并行时这个测试可能超过自动获取的首次等待；对 github.com 的获取会占住写入，LFS 等写入项随之不可用
        controller.autoFetch.stop()

        controller.display(location)
        await session.waitForRefresh()

        expectViewModes(of: controller)
        expectHistorySettings(of: controller)
        try await expectLFS(of: controller, runner: runner, directory: directory)
        try await expectPullRequests(of: controller, runner: runner)
    }

    /// 平铺时 View As List 打勾且不可用、View As Tree 可用；树形时反过来。
    private func expectViewModes(of controller: RepositoryWindowController) {
        let list = item(#selector(RepositoryWindowController.viewAsList))
        let tree = item(#selector(RepositoryWindowController.viewAsTree))

        controller.session.setListMode(.list)
        #expect(!controller.validateUserInterfaceItem(list))
        #expect(list.state == .on)
        #expect(controller.validateUserInterfaceItem(tree))
        #expect(tree.state == .off)

        controller.session.setListMode(.tree)
        #expect(controller.validateUserInterfaceItem(list))
        #expect(list.state == .off)
        #expect(!controller.validateUserInterfaceItem(tree))
        #expect(tree.state == .on)

        controller.session.setListMode(.list)
    }

    /// 在工作区里，历史的显示偏好照常可用；变更集的全部展开与收起没有接收者，仍不可用。
    private func expectHistorySettings(of controller: RepositoryWindowController) {
        #expect(controller.session.activeView == .workingCopy)

        let settings = [
            #selector(RepositoryWindowController.toggleHistoryGraph),
            #selector(RepositoryWindowController.toggleFirstParentOnly),
            #selector(RepositoryWindowController.toggleSortByDate),
            #selector(RepositoryWindowController.toggleVerifySignatures),
        ]

        #expect(settings.allSatisfy { controller.validateUserInterfaceItem(item($0)) })
        #expect(!controller.validateUserInterfaceItem(item(#selector(RepositoryWindowController.expandChanges))))
        #expect(!controller.validateUserInterfaceItem(item(#selector(RepositoryWindowController.collapseChanges))))
    }

    /// LFS 各项只在读到仓库自己启用了 Git LFS 后可用：没读过或没有启用时不可用。
    private func expectLFS(of controller: RepositoryWindowController, runner: GitRunner, directory: URL) async throws {
        let update = item(#selector(RepositoryWindowController.updateLFS))
        let track = item(#selector(RepositoryWindowController.trackLFS))

        // 还没打开过子菜单，以及读过但仓库没有启用
        #expect(!controller.validateUserInterfaceItem(update))

        await controller.readLFSAvailability()
        #expect(!controller.validateUserInterfaceItem(update))
        #expect(!controller.validateUserInterfaceItem(track))

        // 仓库本地登记过滤器、pre-push 钩子调用 Git LFS：与 git lfs install --local 相同
        _ = try await runner.run(["config", "--local", "filter.lfs.clean", "git-lfs clean -- %f"])
        _ = try await runner.run(["config", "--local", "filter.lfs.smudge", "git-lfs smudge -- %f"])

        let hooks = directory.appending(path: ".git/hooks")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)

        let hook = hooks.appending(path: "pre-push")
        try Data("#!/bin/sh\ngit lfs pre-push \"$@\"\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)

        await controller.readLFSAvailability()
        #expect(controller.validateUserInterfaceItem(update))
        #expect(controller.validateUserInterfaceItem(track))
    }

    /// 新建请求：没有账号时不可用、不打开对话框；登录 github.com 的账号后可用；远端换成本机路径后又不可用。
    private func expectPullRequests(of controller: RepositoryWindowController, runner: GitRunner) async throws {
        let session = controller.session
        let create = item(#selector(RepositoryWindowController.createPullRequest))

        // 请求视图没读过，仓库读出引用后也读出远端
        await until { !session.pullRequests.remotes.isEmpty }
        #expect(!session.pullRequests.isLoaded)
        #expect(!controller.validateUserInterfaceItem(create))

        controller.presentPullRequestRequest(.create(sourceBranch: nil))
        #expect(controller.window?.attachedSheet == nil)

        _ = try session.pullRequests.accounts.save(
            HostingUser(username: "me", name: nil),
            on: .github,
            authentication: .personalAccessToken,
            token: "t"
        )

        #expect(controller.validateUserInterfaceItem(create))

        // 地址换成本机路径：刷新后远端设置的摘要变了，重新读出远端
        let path = FileManager.default.temporaryDirectory.appending(path: "spooky-no-hosting").path
        _ = try await runner.run(["remote", "set-url", "origin", path])

        session.refresh(full: true)
        await session.waitForRefresh()
        await until { session.pullRequests.remotes.first?.url == path }

        #expect(!controller.validateUserInterfaceItem(create))
    }

    /// 只带动作的菜单项。
    private func item(_ action: Selector) -> NSMenuItem {
        NSMenuItem(title: "", action: action, keyEquivalent: "")
    }
}
