import AppKit
import SpookyKit
import SwiftUI

// MARK: - SpookyApplicationController

/// 管理窗口身份、打开请求和应用级菜单；Git 参数只在核心库中构造。
@MainActor
final class SpookyApplicationController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// 退出时等待任务结束的上限，取消确认最长需要远端的宽限期与通道关闭时间。
    private static let terminationGrace = Duration.seconds(10)

    /// 跨窗口共享的最近仓库记录。
    let recent: RecentRepositories

    /// 应用持有的主窗口控制器。
    private(set) var windows: [RepositoryWindowController] = []

    /// 单例设置窗口。
    private var settingsWindow: SettingsWindowController?

    /// 跨仓库共用的 Activity 窗口。
    private var activityWindow: ActivityWindowController?

    /// 正在退出时先回收自己的 SSH 主连接。
    private var isTerminating = false

    /// 每个打开动作独立取消，避免旧目录的检查覆盖新选择。
    private var openingTasks: [UUID: Task<Void, Never>] = [:]

    /// 仓库管理的拖入验证任务。
    private var addingTasks: [UUID: Task<Void, Never>] = [:]

    /// 当前响应菜单动作的仓库窗口。
    private var activeWindow: RepositoryWindowController? {
        (NSApp.keyWindow?.windowController as? RepositoryWindowController)
            ?? (NSApp.mainWindow?.windowController as? RepositoryWindowController)
    }

    /// 注入持久化记录，测试与应用使用同一打开规则。
    init(recent: RecentRepositories = RecentRepositories()) {
        self.recent = recent
        super.init()
    }

    /// 启动总是进入仓库管理，不以 shell 当前目录作为仓库。
    func applicationDidFinishLaunching(_: Notification) {
        UserDefaults.standard.register(defaults: [
            "workingCopyViewMode": 0,
            "diffWarningKilobytes": WorkingCopyOperations.defaultWarningKilobytes,
            "historyShowGraph": true,
            "historyPageSize": 100,
            "historyAutoExpand": 0,
            "cleanRefNames": true,
            "checkoutCreatedBranch": true,
        ])
        configureMenu()
        newWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 关闭仓库或最后一个窗口都不退出应用。
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    /// 点击 Dock 图标时恢复一个可用的管理窗口。
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            newWindow()
        }

        return true
    }

    /// 新窗口始终独立，普通打开仍优先复用发起窗口。
    @objc
    func newWindow() {
        let controller = makeWindow()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    /// 应用级 ⌘O 在没有主窗口时也能选择仓库。
    @objc
    func openRepositoryPanel() {
        chooseRepository(in: activeWindow ?? makeWindow())
    }

    /// 仓库管理始终可进入，没有可用窗口时创建一个管理窗口。
    @objc
    func showRepositoryManager() {
        let controller = activeWindow ?? makeWindow()
        controller.showRepositories()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    /// 添加服务器仓库是管理页与 File 菜单共用的 sheet。
    @objc
    func addRemoteRepository() {
        let controller = activeWindow ?? makeWindow()
        controller.showWindow(nil)
        controller.addRemoteRepository()
    }

    /// ⌘, 始终打开同一个设置窗口。
    @objc
    func showSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController() }
        settingsWindow?.showWindow(nil)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
    }

    /// Activity 保持单例，关闭仓库后仍能查看完成日志。
    @objc
    func showActivity() {
        if activityWindow == nil { activityWindow = ActivityWindowController() }
        activityWindow?.showWindow(nil)
        activityWindow?.window?.makeKeyAndOrderFront(nil)
    }

    /// 退出等待自己创建的进程和中继清理完成，不影响用户 SSH 会话。
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else { return .terminateNow }
        isTerminating = true
        let pending = Array(openingTasks.values) + Array(addingTasks.values)
            + [recent.stopValidation()].compactMap { $0 }
        let sessions = windows.map(\.session)
        TerminalLauncher.cleanup()

        for task in pending {
            task.cancel()
        }

        Task {
            // 先取消并等待各窗口的读取、写入和子进程结束，再关闭专属主连接；超过宽限期也会退出。
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await withTaskGroup(of: Void.self) { shutdown in
                        for session in sessions {
                            shutdown.addTask { await session.shutdown() }
                        }

                        for task in pending {
                            shutdown.addTask { await task.value }
                        }
                    }
                }
                group.addTask { try? await Task.sleep(for: Self.terminationGrace) }
                await group.next()
                group.cancelAll()
            }

            await RemoteConnection.closeAll()
            sender.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }

    /// 应用重新激活立即刷新显示仓库的主窗口。
    func applicationDidBecomeActive(_: Notification) {
        for controller in windows {
            controller.session.setActive((controller.window?.isKeyWindow ?? false) && !controller.showsManager)
        }
    }

    /// 应用退到后台统一降低远端轮询频率。
    func applicationDidResignActive(_: Notification) {
        for controller in windows { controller.session.setActive(false) }
    }

    /// 删除关闭窗口的强引用，不影响其它窗口。
    func removeWindow(_ controller: RepositoryWindowController) {
        windows.removeAll { $0 === controller }
    }

    /// 一个窗口完成写入后，显示同一仓库的其它窗口完整刷新，避免各窗口状态不一致。
    func repositoryChanged(_ location: RepositoryLocation, by source: RepositoryWindowController) {
        for controller in windows where controller !== source && controller.session.repository == location {
            controller.session.refresh(full: true)
        }
    }

    /// 最后一个持有仓库的窗口关闭后，回收专属主连接和会话临时目录。
    func releaseConnection(_ location: RepositoryLocation) {
        guard
            location.host != nil,
            !windows.contains(where: { $0.session.repository == location }),
            let remote = GitRunner(location: location).remote
        else { return }

        Task { await remote.close() }
    }

    /// 最近菜单每次展开时反映当前记录，失效记录仍可选择重试。
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        for path in recent.locations {
            let item = NSMenuItem(title: path.displayPath, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = path
            item.toolTip = recent.unavailable.contains(path)
                ? AppLocalization.text("repositories.unavailable")
                : path.displayPath
            menu.addItem(item)
        }
    }
}

// MARK: - Repository Opening

extension SpookyApplicationController {
    /// 使用系统目录选择 sheet；取消不改变当前仓库。
    func chooseRepository(in source: RepositoryWindowController) {
        guard let window = source.window, window.attachedSheet == nil else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = AppLocalization.text("action.open")
        panel.message = AppLocalization.text("repositories.panel.message")
        panel.title = AppLocalization.text("action.openLocal")
        source.showWindow(nil)

        panel.beginSheetModal(for: window) { [weak self, weak source] response in
            guard response == .OK, let path = panel.url?.path, let source else {
                return
            }

            self?.openRepository(at: .local(path: path), from: source, inNewWindow: false)
        }
    }

    /// 验证后按规范根路径去重；显式新窗口打开跳过去重。
    func openRepository(
        at location: RepositoryLocation,
        from source: RepositoryWindowController?,
        inNewWindow: Bool
    ) {
        if let source {
            cancelOpening(in: source)
        }

        let request = UUID()
        source?.openingRequest = request
        source?.session.isOpening = true

        openingTasks[request] = Task { [weak self, weak source] in
            guard let self else {
                return
            }

            defer {
                self.openingTasks[request] = nil

                if source?.openingRequest == request {
                    source?.openingRequest = nil
                    source?.session.isOpening = false
                }
            }

            do {
                let repository = try await Self.verifiedLocation(of: location)
                try Task.checkCancellation()

                displayRepository(repository, from: source, inNewWindow: inNewWindow)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                recent.markUnavailable(location)
                let destination = source ?? makeWindow()
                destination.showWindow(nil)
                destination.showFailure(AppFailure(error: error, opening: true, location: location))
            }
        }
    }

    /// 已验证的本机和远端仓库共用窗口去重规则。
    func displayRepository(
        _ repository: RepositoryLocation,
        from source: RepositoryWindowController?,
        inNewWindow: Bool
    ) {
        let destination: RepositoryWindowController =
            if
                !inNewWindow,
                let existing = windows.first(where: {
                    !$0.showsManager && $0.session.repository == repository
                })
            {
                existing
            } else if !inNewWindow, let source, windows.contains(where: { $0 === source }) {
                source
            } else {
                makeWindow()
            }

        recent.remember(repository)
        let previous = destination.session.repository
        destination.display(repository)

        if let previous, previous != repository { releaseConnection(previous) }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 拖入文件夹只添加已验证的本机仓库，多个目录依次检查。
    func addRepositories(_ urls: [URL], from source: RepositoryWindowController) {
        let request = UUID()

        addingTasks[request] = Task { [weak self, weak source] in
            guard let self else {
                return
            }

            defer { self.addingTasks[request] = nil }

            for url in urls {
                do {
                    let repository = try await GitRunner(location: .local(path: url.path)).openLocalRepository()
                    try Task.checkCancellation()
                    recent.remember(repository.location)
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }

                    source?.showFailure(
                        AppFailure(error: error, opening: true, location: .local(path: url.path))
                    )
                    return
                }
            }
        }
    }

    /// 关闭或改选时废弃上一条打开请求。
    func cancelOpening(in source: RepositoryWindowController) {
        if let request = source.openingRequest {
            openingTasks[request]?.cancel()
            openingTasks[request] = nil
        }

        source.openingRequest = nil
        source.session.isOpening = false
    }
}

// MARK: - Private

extension SpookyApplicationController {
    /// 经核心库验证所选位置，返回规范化后的仓库位置。
    private static func verifiedLocation(of location: RepositoryLocation) async throws -> RepositoryLocation {
        let runner = GitRunner(location: location)

        // 服务器仓库在连接建立前接入界面回调，再完成 SSH、Git、路径与工作区检查。
        if let remote = runner.remote {
            await remote.setCallbackHandler { request in
                await RemoteCallbackPresenter.shared.respond(to: request)
            }

            return try await remote.open().location
        }

        // 本机仓库先校验 Git 版本，再把子目录和符号链接统一到工作区根目录。
        return try await runner.openLocalRepository().location
    }

    /// 最近菜单直接走窗口复用与版本检查流程。
    @objc
    private func openRecent(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? RepositoryLocation else {
            return
        }

        openRepository(at: path, from: activeWindow, inNewWindow: false)
    }

    /// 创建控制器并纳入应用生命周期。
    private func makeWindow() -> RepositoryWindowController {
        let controller = RepositoryWindowController(coordinator: self)
        windows.append(controller)
        return controller
    }

    /// 主菜单只提供已有功能及必要的系统窗口、文本动作。
    private func configureMenu() {
        let menu = NSMenu()
        NSApp.mainMenu = menu

        configureApplicationMenu(in: menu)
        configureFileMenu(in: menu)
        configureEditMenu(in: menu)
        configureViewMenu(in: menu)
        configureRepositoryMenu(in: menu)
        configureWorkingCopyMenu(in: menu)
        configureWindowMenu(in: menu)
    }

    /// 应用菜单：设置、隐藏与退出。
    private func configureApplicationMenu(in menu: NSMenu) {
        let application = addMenu("app.name", to: menu)
        addItem("settings.title", action: #selector(showSettings), key: ",", target: self, to: application)

        application.addItem(.separator())
        addItem("menu.hide", action: #selector(NSApplication.hide(_:)), key: "h", to: application)
        addItem(
            "menu.hideOthers",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            key: "h",
            modifiers: [.command, .option],
            to: application
        )
        addItem("menu.showAll", action: #selector(NSApplication.unhideAllApplications(_:)), to: application)

        application.addItem(.separator())
        addItem("menu.quit", action: #selector(NSApplication.terminate(_:)), key: "q", to: application)
    }

    /// File 菜单：新窗口、打开本机或服务器仓库、最近仓库，以及仓库位置与关闭动作。
    private func configureFileMenu(in menu: NSMenu) {
        let file = addMenu("menu.file", to: menu)
        addItem("menu.newWindow", action: #selector(newWindow), key: "n", target: self, to: file)
        addItem("action.openLocal", action: #selector(openRepositoryPanel), key: "o", target: self, to: file)

        addItem("action.addRemote", action: #selector(addRemoteRepository), target: self, to: file)
        let recentMenu = addMenu("menu.openRecent", to: file)
        recentMenu.delegate = self

        file.addItem(.separator())
        addItem("action.openTerminal", action: #selector(RepositoryWindowController.openInTerminal), to: file)
        addItem("action.revealFinder", action: #selector(RepositoryWindowController.revealInFinder), to: file)

        file.addItem(.separator())
        addItem("action.closeRepository", action: #selector(RepositoryWindowController.closeRepository), to: file)
        addItem("menu.closeWindow", action: #selector(NSWindow.performClose(_:)), key: "w", to: file)
    }

    /// Edit 菜单只放系统文本动作。
    private func configureEditMenu(in menu: NSMenu) {
        let edit = addMenu("menu.edit", to: menu)
        addItem("menu.cut", action: #selector(NSText.cut(_:)), key: "x", to: edit)
        addItem("menu.copy", action: #selector(NSText.copy(_:)), key: "c", to: edit)
        addItem("menu.paste", action: #selector(NSText.paste(_:)), key: "v", to: edit)
        addItem("menu.selectAll", action: #selector(NSText.selectAll(_:)), key: "a", to: edit)
    }

    /// View 菜单：仓库管理、工作区与历史视图，历史的显示选项，以及文件列表样式、刷新与全屏。
    private func configureViewMenu(in menu: NSMenu) {
        let view = addMenu("menu.view", to: menu)
        addItem(
            "menu.showRepositories",
            action: #selector(showRepositoryManager),
            key: "r",
            modifiers: [.control, .command],
            target: self,
            to: view
        )
        addItem("menu.showWorkingCopy", action: #selector(RepositoryWindowController.showWorkingCopy), key: "1", to: view)
        addItem("menu.showHistory", action: #selector(RepositoryWindowController.showHistory), key: "2", to: view)
        addItem(
            "history.showHead",
            action: #selector(RepositoryWindowController.showHeadBranch),
            key: "0",
            to: view
        )

        configureHistoryMenu(in: view)
        configureHistoryDiffsMenu(in: view)

        view.addItem(.separator())
        addItem(
            "working.list", action: #selector(RepositoryWindowController.viewAsList),
            key: "l", modifiers: [.control, .command], to: view
        )
        addItem(
            "working.tree", action: #selector(RepositoryWindowController.viewAsTree),
            key: "t", modifiers: [.control, .command], to: view
        )
        addItem("action.refresh", action: #selector(RepositoryWindowController.refreshRepository), key: "r", to: view)
        addItem(
            "menu.fullscreen",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            key: "f",
            modifiers: [.control, .command],
            to: view
        )
    }

    /// 历史子菜单：提交图开关与行高。
    private func configureHistoryMenu(in view: NSMenu) {
        let history = addMenu("history.title", to: view)
        addItem(
            "history.showGraph",
            action: #selector(RepositoryWindowController.toggleHistoryGraph),
            key: "g",
            modifiers: [.control, .command],
            to: history
        )
        addItem(
            "history.medium",
            action: #selector(RepositoryWindowController.mediumHistoryRows),
            to: history
        )
        addItem("history.small", action: #selector(RepositoryWindowController.smallHistoryRows), to: history)
    }

    /// 变更集子菜单：全部展开、全部收起与自动展开阈值。
    private func configureHistoryDiffsMenu(in view: NSMenu) {
        let changes = addMenu("history.diffs", to: view)
        addItem(
            "history.expandAll",
            action: #selector(RepositoryWindowController.expandChanges),
            key: "\u{f703}",
            modifiers: [.control, .command],
            to: changes
        )
        addItem(
            "history.collapseAll",
            action: #selector(RepositoryWindowController.collapseChanges),
            key: "\u{f702}",
            modifiers: [.control, .command],
            to: changes
        )

        changes.addItem(.separator())

        for threshold in [0, 5, 10, 15, 20, 25, 50, Int.max] {
            let title =
                threshold == 0
                    ? AppLocalization.text("history.autoExpand.never")
                    : (
                        threshold == Int.max
                            ? AppLocalization.text("history.autoExpand.always")
                            : AppLocalization.text("history.autoExpand.items", threshold)
                    )

            let item = NSMenuItem(
                title: title,
                action: #selector(RepositoryWindowController.setAutoExpand(_:)),
                keyEquivalent: ""
            )
            item.tag = threshold
            changes.addItem(item)
        }
    }

    /// Repository 菜单：获取、拉取、推送、发布与新建分支。
    private func configureRepositoryMenu(in menu: NSMenu) {
        let repository = addMenu("menu.repository", to: menu)
        addItem(
            "sync.fetch",
            action: #selector(RepositoryWindowController.fetch),
            key: "f",
            modifiers: [.shift, .command],
            to: repository
        )
        addItem("sync.fetchAll", action: #selector(RepositoryWindowController.fetchAll), to: repository)
        addItem(
            "sync.pull",
            action: #selector(RepositoryWindowController.pull),
            key: "p",
            modifiers: [.shift, .command],
            to: repository
        )
        addItem(
            "sync.push",
            action: #selector(RepositoryWindowController.push),
            key: "u",
            modifiers: [.shift, .command],
            to: repository
        )
        addItem("sync.publish", action: #selector(RepositoryWindowController.publishBranch), to: repository)

        repository.addItem(.separator())
        addItem(
            "branch.create",
            action: #selector(RepositoryWindowController.createBranch),
            key: "b",
            to: repository
        )
    }

    /// Working Copy 菜单：检出与合并、提交与暂存，以及丢弃改动。
    private func configureWorkingCopyMenu(in menu: NSMenu) {
        let working = addMenu("workspace.title", to: menu)
        addItem(
            "branch.checkout",
            action: #selector(RepositoryWindowController.checkoutBranch),
            key: "b",
            modifiers: [.shift, .command],
            to: working
        )
        addItem(
            "sync.merge",
            action: #selector(RepositoryWindowController.merge),
            key: "m",
            modifiers: [.shift, .command],
            to: working
        )

        working.addItem(.separator())
        addItem(
            "working.commit", action: #selector(RepositoryWindowController.composeCommit),
            key: "c", modifiers: [.shift, .command], to: working
        )
        addItem("working.stage", action: #selector(RepositoryWindowController.stageSelected), to: working)
        addItem("working.unstage", action: #selector(RepositoryWindowController.unstageSelected), to: working)
        addItem(
            "working.stageAll", action: #selector(RepositoryWindowController.stageAll),
            key: "e", modifiers: [.shift, .command], to: working
        )
        addItem(
            "working.unstageAll", action: #selector(RepositoryWindowController.unstageAll),
            key: "e", modifiers: [.option, .shift, .command], to: working
        )

        working.addItem(.separator())
        addItem(
            "working.discard", action: #selector(RepositoryWindowController.discardSelected),
            key: "\u{8}", modifiers: [.shift, .command], to: working
        )
        addItem("working.discardAll", action: #selector(RepositoryWindowController.discardAll), to: working)
    }

    /// Window 菜单：Activity 与系统窗口动作，并登记为应用的窗口菜单。
    private func configureWindowMenu(in menu: NSMenu) {
        let window = addMenu("menu.window", to: menu)
        NSApp.windowsMenu = window

        addItem(
            "activity.title",
            action: #selector(showActivity),
            key: "0",
            modifiers: [.control, .command],
            target: self,
            to: window
        )
        addItem("menu.minimize", action: #selector(NSWindow.performMiniaturize(_:)), key: "m", to: window)
        addItem("menu.zoom", action: #selector(NSWindow.performZoom(_:)), to: window)
        addItem("menu.bringAll", action: #selector(NSApplication.arrangeInFront(_:)), to: window)
    }

    /// 创建带本地化标题的子菜单。
    private func addMenu(_ key: String, to parent: NSMenu) -> NSMenu {
        let item = NSMenuItem(title: AppLocalization.text(key), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: item.title)
        item.submenu = submenu
        parent.addItem(item)
        return submenu
    }

    /// 统一菜单文案、快捷键和响应链目标。
    private func addItem(
        _ key: String,
        action: Selector,
        key shortcut: String = "",
        modifiers: NSEvent.ModifierFlags = .command,
        target: AnyObject? = nil,
        to menu: NSMenu
    ) {
        let item = NSMenuItem(title: AppLocalization.text(key), action: action, keyEquivalent: shortcut)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        menu.addItem(item)
    }
}
