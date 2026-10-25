import AppKit
import os
import SpookyKit
import SwiftUI

// MARK: - SpookyApplicationController

/// 管理窗口身份、打开请求和应用级菜单；Git 参数只在核心库中构造。
@MainActor
final class SpookyApplicationController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// 退出时等待任务结束的上限，取消确认最长需要远端的宽限期与通道关闭时间。
    private static let terminationGrace = Duration.seconds(10)

    /// 退出收尾的日志：宽限期先到时说明仍有任务未结束。
    private nonisolated static let logger = Logger(subsystem: "com.rakuyo.spooky", category: "SpookyApplicationController")

    /// 跨窗口共享的最近仓库记录。
    let recent: RecentRepositories

    /// 应用持有的主窗口控制器。
    private(set) var windows: [RepositoryWindowController] = []

    /// 单例设置窗口。
    private var settingsWindow: SettingsWindowController?

    /// 跨仓库共用的 Activity 窗口。
    private var activityWindow: ActivityWindowController?

    /// Dock 与 ⌘Tab 中的 App 图标：跟随 “图标与小组件样式”，连着服务器时指示灯亮起。
    private let appIconController = AppIconController()

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

        // 主题目录缺少 Default 或 Default (Dark)、或它们的文件无法加载时从资源写入；写不进去时文本区用资源里的版本。
        try? ThemeStore.shared.installDefaultThemes()

        // 窗口创建前应用保存的外观，第一帧就使用所选的浅色或深色。
        AppAppearance.current.apply()

        // 打开仓库前交出所选的 Git 程序、自定义变量与 SSH agent；登录 shell 的变量在后台读取。
        LocalExecutionPreferences.shared.start()

        configureMenu()
        appIconController.start()

        // 系统恢复了仓库窗口时不另开窗口；否则按偏好显示启动窗口或仓库管理
        openInitialWindow()
        NSApp.activate(ignoringOtherApps: true)

        // 窗口与菜单就绪后启动更新器，按计划检查与手动检查都由它负责
        UpdateController.shared.start()
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

    /// 新窗口始终独立，不并进已有的标签组；普通打开仍优先复用发起窗口。
    @objc
    func newWindow() {
        let controller = makeWindow()

        showSeparately(controller) {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
        }
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
            await withTaskGroup(of: Bool.self) { group in
                group.addTask {
                    await withTaskGroup(of: Void.self) { shutdown in
                        for session in sessions {
                            shutdown.addTask { await session.shutdown() }
                        }

                        for task in pending {
                            shutdown.addTask { await task.value }
                        }
                    }

                    return true
                }

                group.addTask {
                    try? await Task.sleep(for: Self.terminationGrace)
                    return false
                }

                // 宽限期先到时照常退出，留下记录便于排查未结束的读取、写入或子进程
                if let finished = await group.next(), !finished {
                    Self.logger.error("退出等待超过宽限期，仍有任务未结束")
                }

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

        // 关掉的窗口可能是最后一个连着服务器的窗口。
        connectionStateChanged()
    }

    /// 窗口的连接状态变化或窗口关闭后，按是否还有连着的服务器仓库点亮或熄灭 App 图标上的指示灯。
    func connectionStateChanged() {
        appIconController.isConnected = windows.contains { $0.session.connectionState == .connected }
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
    ///
    /// - Parameters:
    ///   - destination: 打开后切到的视图；nil 时显示仓库保存的视图状态。
    ///   - staysInSource: 后退、前进与窗口恢复在发起窗口里打开，不改用已显示这个仓库的其它窗口。
    func openRepository(
        at location: RepositoryLocation,
        from source: RepositoryWindowController?,
        inNewWindow: Bool,
        showing destination: RepositoryDestination? = nil,
        staysInSource: Bool = false
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

                displayRepository(
                    repository,
                    from: source,
                    inNewWindow: inNewWindow,
                    showing: destination,
                    staysInSource: staysInSource
                )
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

    /// 已验证的本机和远端仓库共用窗口去重规则；显式新窗口不并进已有的标签组。
    ///
    /// - Parameters:
    ///   - view: 显示后切到的视图；nil 时显示仓库保存的视图状态。
    ///   - staysInSource: 在发起窗口里显示，不改用已显示这个仓库的其它窗口。
    func displayRepository(
        _ repository: RepositoryLocation,
        from source: RepositoryWindowController?,
        inNewWindow: Bool,
        showing view: RepositoryDestination? = nil,
        staysInSource: Bool = false
    ) {
        let sourceIsOpen = source.map { source in windows.contains { $0 === source } } ?? false

        let destination: RepositoryWindowController =
            if staysInSource, sourceIsOpen, let source {
                source
            } else if
                !inNewWindow,
                let existing = windows.first(where: {
                    !$0.showsManager && $0.session.repository == repository
                })
            {
                existing
            } else if !inNewWindow, sourceIsOpen, let source {
                source
            } else {
                makeWindow()
            }

        recent.remember(repository)
        let previous = destination.session.repository

        showSeparately(destination, when: inNewWindow) {
            if let view {
                destination.display(repository, showing: view)
            } else {
                destination.display(repository)
            }
        }

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
    func makeWindow() -> RepositoryWindowController {
        let controller = RepositoryWindowController(coordinator: self)
        windows.append(controller)
        return controller
    }
}
