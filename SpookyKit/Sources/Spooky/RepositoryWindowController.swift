import AppKit
import SpookyKit
import SwiftUI

/// 仓库窗口的 AppKit 外壳，负责两层分栏、工具栏与错误 sheet。
@MainActor
final class RepositoryWindowController: NSWindowController, NSWindowDelegate,
    NSToolbarDelegate, NSUserInterfaceValidations {
    /// 每个窗口独立拥有读取任务与选区。
    let session: RepositorySession

    /// 窗口是否正在显示仓库管理。
    private(set) var showsManager = true

    /// 当前打开请求，关闭窗口或改选目录时取消。
    var openingRequest: UUID?

    /// 跨窗口的打开与记录管理。
    private weak var coordinator: SpookyApplicationController?

    /// 外层侧边栏分栏。
    private var outerSplit: NSSplitViewController?

    /// 工作区的列表与详情分栏。
    private var workingCopySplit: NSSplitViewController?

    /// 历史与整页提交详情拥有各自保存宽度的内层分栏。
    private var historySplit: NSSplitViewController?

    /// 窗口级快捷键跨越 AppKit 文件列表与 SwiftUI 信息框。
    private var keyMonitor: Any?

    /// 创建原生窗口；标签合并被关闭，显式新窗口始终独立。
    init(coordinator: SpookyApplicationController, session: RepositorySession = RepositorySession()) {
        self.coordinator = coordinator
        self.session = session

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.fullScreenPrimary]
        super.init(window: window)

        window.delegate = self
        configureWorkingCopyKeys()
        session.onFailure = { [weak self] in self?.showFailure($0) }
        session.history.onFailure = { [weak self] error in
            if error is RemoteConnectionError {
                self?.session.reconnect()
            } else {
                self?.showFailure(AppFailure(error: error, opening: false))
            }
        }
        session.onConfirm = { [weak self] title, message, action, abort in
            guard let window = self?.window, window.attachedSheet == nil else { return }
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: title)
            alert.addButton(withTitle: AppLocalization.text(abort == nil ? "action.cancel" : "working.abort"))

            // Sheet 已结束后才开始写入，错误与进度由仓库视图承接。
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn { action() }
                else if response == .alertSecondButtonReturn { abort?() }
            }
        }
        showRepositories()

        // 内容控制器装入后再设初始尺寸，避免 SwiftUI 的理想尺寸覆盖窗口默认值。
        window.setContentSize(NSSize(width: 1000, height: 540))

        if !window.setFrameUsingName("Spooky.RepositoryWindow") {
            window.center()
        }

        window.setFrameAutosaveName("Spooky.RepositoryWindow")
    }

    /// 窗口由代码构建，不从归档恢复控制器。
    required init?(coder: NSCoder) {
        return nil
    }

    /// 显示已验证的仓库，并立即开始读取工作区。
    func display(_ repository: RepositoryLocation) {
        let sameRepositoryView = session.repository == repository && !showsManager
        session.display(repository)
        showsManager = false
        window?.title = repository.name
        window?.subtitle = repository.displayPath
        window?.representedURL = repository.localURL

        if !sameRepositoryView {
            configureRepositoryView()
        }

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        session.refresh()
    }

    /// 在同一个窗口显示仓库管理，保留当前仓库会话供再次打开。
    @objc func showRepositories() {
        guard let coordinator else {
            return
        }

        showsManager = true
        window?.title = AppLocalization.text("repositories.title")
        window?.subtitle = ""
        window?.representedURL = nil
        workingCopySplit = nil
        historySplit = nil

        let choose: () -> Void = { [weak self] in
            guard let self else {
                return
            }

            self.coordinator?.chooseRepository(in: self)
        }
        let open: (RepositoryLocation, Bool) -> Void = { [weak self] path, newWindow in
            guard let self else {
                return
            }

            self.coordinator?.openRepository(at: path, from: self, inNewWindow: newWindow)
        }
        let add: ([URL]) -> Void = { [weak self] in
            guard let self else {
                return
            }

            self.coordinator?.addRepositories($0, from: self)
        }

        let sidebar = NSHostingController(rootView: RecentRepositoryListView(
            session: session,
            recent: coordinator.recent,
            open: open,
            choose: choose,
            addRemote: { [weak self] in self?.addRemoteRepository() },
            openTerminal: { [weak self] in self?.openLocationInTerminal($0) },
            addFolders: add
        ))
        sidebar.sizingOptions = [.minSize]

        let detail = NSHostingController(rootView: RepositoryManagerView(
            session: session,
            recent: coordinator.recent,
            choose: choose,
            open: open,
            addRemote: { [weak self] in self?.addRemoteRepository() },
            addFolders: add
        ))
        detail.sizingOptions = [.minSize]

        installOuterSplit(sidebar: sidebar, detail: detail, name: "Spooky.Repositories")
        coordinator.recent.validate()
    }

    /// 体检在表单内部进行，只有成功的工作区才进入可用列表。
    @objc func addRemoteRepository() {
        guard let window, window.attachedSheet == nil else { return }
        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed
        let view = AddRemoteRepositoryView(
            opened: { [weak self, weak sheet] repository in
                guard let self, let sheet else { return }
                window.endSheet(sheet)
                self.coordinator?.displayRepository(repository, from: self, inNewWindow: false)
            },
            cancelled: { [weak sheet] in
                guard let sheet else { return }
                window.endSheet(sheet)
            }
        )
        sheet.contentViewController = NSHostingController(rootView: view)
        window.beginSheet(sheet)
    }

    /// 主菜单和工具栏使用当前仓库，管理页使用当前选中的记录。
    @objc func openInTerminal() {
        guard let location = showsManager ? session.selectedRecentLocation : session.repository else { return }
        openLocationInTerminal(location)
    }

    /// 右键菜单可直接指定记录，错误显示在发起操作的窗口。
    func openLocationInTerminal(_ location: RepositoryLocation) {
        Task { [weak self] in
            do { try await TerminalLauncher.open(location) }
            catch { self?.showFailure(AppFailure(error: error, opening: false)) }
        }
    }

    /// Finder 只能显示本机路径。
    @objc func revealInFinder() {
        guard let location = showsManager ? session.selectedRecentLocation : session.repository,
              let url = location.localURL
        else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 服务器路径带主机前缀，避免复制后误认为本机目录。
    @objc func copyPath() {
        guard let location = showsManager ? session.selectedRecentLocation : session.repository else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(location.displayPath, forType: .string)
    }

    /// 窗口激活会立即刷新服务器状态。
    func windowDidBecomeKey(_ notification: Notification) {
        session.setActive(true)
    }

    /// 后台窗口降为十秒轮询。
    func windowDidResignKey(_ notification: Notification) {
        session.setActive(false)
    }

    /// 关闭仓库只回到管理界面，不关闭窗口或结束 App。
    @objc func closeRepository() {
        coordinator?.cancelOpening(in: self)
        let location = session.repository
        session.close()
        if let location { coordinator?.releaseConnection(location) }
        showRepositories()
    }

    /// 菜单和工具栏共用刷新入口。
    @objc func refreshRepository() {
        guard !showsManager else {
            return
        }

        session.refresh()
        session.history.reloadCommits()
    }

    /// 提交菜单与工具栏聚焦已有的工作区标题框。
    @objc func composeCommit() {
        if session.activeView != .workingCopy { showWorkingCopy() }
        session.commitFocusRequest += 1
    }

    /// 全部暂存的工具栏入口支持 ⌥ 切换到全部取消暂存。
    @objc func stageAll() {
        let unstage = NSEvent.modifierFlags.contains(.option)
            && session.status?.entries.contains(where: \.hasStagedChanges) == true
        session.stageAll(staged: !unstage)
    }

    /// 主菜单的独立取消暂存动作。
    @objc func unstageAll() { session.stageAll(staged: false) }

    /// 选中文件的菜单暂存入口。
    @objc func stageSelected() { session.stage(session.selectedEntries, staged: true) }

    /// 选中文件的菜单取消暂存入口。
    @objc func unstageSelected() { session.stage(session.selectedEntries, staged: false) }

    /// 主菜单和文件右键共用丢弃确认。
    @objc func discardSelected() { session.discard(session.selectedEntries) }

    /// 全部丢弃只覆盖当前状态中的改动。
    @objc func discardAll() { session.discard(session.status?.entries ?? []) }

    /// 平铺偏好跨仓库共享。
    @objc func viewAsList() { UserDefaults.standard.set(0, forKey: "workingCopyViewMode") }

    /// 树形偏好跨仓库共享。
    @objc func viewAsTree() { UserDefaults.standard.set(1, forKey: "workingCopyViewMode") }

    /// 切换到工作区，⌘1 与侧边栏使用相同状态。
    @objc func showWorkingCopy() {
        guard session.repository != nil else {
            return
        }

        session.activeView = .workingCopy
        showsManager = false
        configureRepositoryView()
    }

    /// 切换到全部分支历史，⌘2 与侧边栏使用相同状态。
    @objc func showHistory() {
        guard session.repository != nil else {
            return
        }

        session.activeView = .history
        session.history.showsCommitPage = false
        session.history.selectedReference = nil
        showsManager = false
        configureRepositoryView()
    }

    /// ⌘0 选中当前 HEAD，分离和未出生分支仍可定位。
    @objc func showHeadBranch() {
        guard session.repository != nil else { return }
        session.activeView = .history
        session.history.showsCommitPage = false
        session.history.selectedReference = session.status?.branch.head.map { "refs/heads/" + $0 } ?? "HEAD"
        showsManager = false
        configureRepositoryView()
    }

    /// 新建分支默认从当前选中提交或 HEAD 开始。
    @objc func createBranch() {
        let revision = session.activeView == .history ? session.history.selectedCommit?.id : nil
        presentRepositoryAction(RepositoryActionRequest(kind: .create, reference: revision))
    }

    /// 检出表单只列出本地分支。
    @objc func checkoutBranch() { presentRepositoryAction(RepositoryActionRequest(kind: .checkout)) }

    /// 获取入口收集远端与清理选项。
    @objc func fetch() { presentRepositoryAction(RepositoryActionRequest(kind: .fetch)) }

    /// 全部获取使用持久化的清理与标签选项。
    @objc func fetchAll() {
        let prune = UserDefaults.standard.bool(forKey: "fetchPrune")
        let tags = UserDefaults.standard.bool(forKey: "fetchAllTags")
        session.performGit(
            { runner, output in
                _ = try await RepositorySync(runner: runner)
                    .fetch(prune: prune, allTags: tags, onOutput: output)
            },
            title: AppLocalization.text("sync.fetch")
        )
    }

    /// 拉取表单明确选择合并或变基。
    @objc func pull() { presentRepositoryAction(RepositoryActionRequest(kind: .pull)) }

    /// 推送表单明确目标远端和目标分支。
    @objc func push() { presentRepositoryAction(RepositoryActionRequest(kind: .push)) }

    /// 发布表单允许首次设置 upstream。
    @objc func publishBranch() { presentRepositoryAction(RepositoryActionRequest(kind: .publish)) }

    /// 合并表单在执行前显示 merge-tree 预览。
    @objc func merge() { presentRepositoryAction(RepositoryActionRequest(kind: .merge)) }

    /// 全局 Activity 窗口由应用统一持有。
    @objc func showActivity() { coordinator?.showActivity() }

    /// 提交图开关同时作用于列表头和主菜单。
    @objc func toggleHistoryGraph() {
        UserDefaults.standard.set(
            !UserDefaults.standard.bool(forKey: "historyShowGraph"),
            forKey: "historyShowGraph"
        )
    }

    /// 小号行采用 24 pt 高度。
    @objc func smallHistoryRows() { UserDefaults.standard.set(true, forKey: "historySmallRows") }

    /// 中号行采用 46 pt 高度。
    @objc func mediumHistoryRows() { UserDefaults.standard.set(false, forKey: "historySmallRows") }

    /// 变更集展开快捷键复用文件懒加载。
    @objc func expandChanges() { session.history.expandAll(true) }

    /// 折叠不丢弃已取得的只读补丁。
    @objc func collapseChanges() { session.history.expandAll(false) }

    /// 自动展开阈值立即更新当前提交的文件展示。
    @objc func setAutoExpand(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "historyAutoExpand")
        session.history.expandAll(sender.tag > 0 && session.history.changes.count <= sender.tag)
    }

    /// 双击详情保留提交选择，只替换内层分栏。
    func showCommitPage() {
        session.history.showsCommitPage = true
        configureRepositoryView()
    }

    /// 对话框关闭之后才启动写入，保存发起仓库身份以拒绝迟到提交。
    func presentRepositoryAction(_ request: RepositoryActionRequest) {
        guard session.canWrite, let window, window.attachedSheet == nil else { return }
        let repository = session.repository
        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed
        sheet.contentViewController = NSHostingController(
            rootView: RepositoryOperationDialog(
                session: session,
                request: request,
                cancel: { [weak sheet] in
                    if let sheet { window.endSheet(sheet) }
                },
                submit: { [weak self, weak sheet] title, action in
                    guard let self, let sheet else { return }
                    window.endSheet(sheet)
                    guard self.session.repository == repository else { return }
                    self.session.performGit(action, title: title)
                }
            )
        )
        window.beginSheet(sheet)
    }

    /// 打开系统目录选择器，发起窗口决定普通打开的目的地。
    @objc func chooseRepository() {
        coordinator?.chooseRepository(in: self)
    }

    /// 把错误原文放入可滚动、可复制的附件，恢复操作在 sheet 结束后执行。
    func showFailure(_ failure: AppFailure) {
        guard let window else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = failure.title
        alert.informativeText = failure.message
            + (session.repository.map { "\n\n" + $0.displayPath } ?? "")
        alert.addButton(withTitle: AppLocalization.text("action.close"))
        alert.addButton(withTitle: AppLocalization.text(
            failure.isOpeningFailure ? "action.chooseAnother" : "action.refresh"
        ))

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 175))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.isSelectable = true
        text.isRichText = false
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.textColor = .secondaryLabelColor
        text.textContainerInset = NSSize(width: 8, height: 8)
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.string = failure.details
        text.setAccessibilityLabel(AppLocalization.text("error.details"))
        scroll.documentView = text
        alert.accessoryView = scroll

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertSecondButtonReturn else {
                return
            }

            if failure.isOpeningFailure {
                if failure.isRemoteFailure { self.addRemoteRepository() }
                else { self.chooseRepository() }
            } else {
                self.refreshRepository()
            }
        }
    }

    /// 关窗时取消该窗口的工作，并从应用窗口集合中移除。
    func windowWillClose(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        coordinator?.cancelOpening(in: self)
        let location = session.repository
        session.close()
        coordinator?.removeWindow(self)
        if let location { coordinator?.releaseConnection(location) }
    }

    /// 仓库动作按当前视图与加载状态启用。
    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(fetch), #selector(fetchAll):
            return !showsManager && session.canWrite && session.history.snapshot?.remotes.isEmpty == false
        case #selector(pull):
            return !showsManager && session.canWrite && session.status?.branch.head != nil
                && session.status?.branch.oid != nil && session.context?.operation == nil
                && session.history.branches.contains(where: \.isRemote)
        case #selector(push):
            return !showsManager && session.canWrite && session.status?.branch.oid != nil
                && session.status?.branch.head != nil
                && session.history.snapshot?.remotes.isEmpty == false
        case #selector(publishBranch):
            return !showsManager && session.canWrite && session.history.branches.contains(where: \.isLocal)
                && session.history.snapshot?.remotes.isEmpty == false
        case #selector(merge):
            return !showsManager && session.canWrite && session.status?.branch.head != nil
                && session.status?.branch.oid != nil && session.context?.operation == nil
                && session.history.branches.contains { $0.id != "refs/heads/" + (session.status?.branch.head ?? "") }
        case #selector(createBranch):
            return !showsManager && session.canWrite && session.status?.branch.oid != nil
                && session.context?.operation == nil
        case #selector(checkoutBranch):
            return !showsManager && session.canWrite && session.context?.operation == nil
                && session.history.branches.contains { $0.isLocal && $0.name != session.status?.branch.head }
        case #selector(showHeadBranch):
            return session.repository != nil
        case #selector(toggleHistoryGraph):
            (item as? NSMenuItem)?.state = UserDefaults.standard.bool(forKey: "historyShowGraph") ? .on : .off
            return !showsManager && session.activeView == .history
        case #selector(smallHistoryRows), #selector(mediumHistoryRows):
            let small = UserDefaults.standard.bool(forKey: "historySmallRows")
            (item as? NSMenuItem)?.state = (item.action == #selector(smallHistoryRows)) == small ? .on : .off
            return !showsManager && session.activeView == .history
                && UserDefaults.standard.bool(forKey: "historyShowGraph")
        case #selector(expandChanges), #selector(collapseChanges), #selector(setAutoExpand(_:)):
            if item.action == #selector(setAutoExpand(_:)), let item = item as? NSMenuItem {
                item.state =
                    item.tag == UserDefaults.standard.integer(forKey: "historyAutoExpand") ? .on : .off
            }
            return !showsManager && session.activeView == .history && session.history.selectedCommit != nil
        case #selector(composeCommit), #selector(viewAsList), #selector(viewAsTree):
            return !showsManager && session.repository != nil

        case #selector(stageAll):
            let unstage = NSEvent.modifierFlags.contains(.option)
                && session.status?.entries.contains(where: \.hasStagedChanges) == true
            return !showsManager && session.canWrite
                && session.status?.entries.contains(where: {
                    unstage ? $0.hasStagedChanges : $0.hasUnstagedChanges
                }) == true

        case #selector(unstageAll):
            return !showsManager && session.canWrite && session.status?.entries.contains(where: \.hasStagedChanges) == true

        case #selector(stageSelected), #selector(unstageSelected), #selector(discardSelected):
            return !showsManager && session.canWrite && !session.selectedEntries.isEmpty

        case #selector(discardAll):
            return !showsManager && session.canWrite && session.status?.entries.isEmpty == false

        case #selector(openInTerminal), #selector(copyPath):
            return (showsManager ? session.selectedRecentLocation : session.repository) != nil

        case #selector(revealInFinder):
            return (showsManager ? session.selectedRecentLocation : session.repository)?.localURL != nil

        case #selector(refreshRepository):
            return !showsManager
                && session.repository != nil
                && !session.isRefreshing
                && !session.isOpening

        case #selector(closeRepository):
            return !showsManager && session.repository != nil

        case #selector(showWorkingCopy), #selector(showHistory):
            return session.repository != nil

        default:
            return true
        }
    }

    /// 当前视图需要的工具栏项，工作区额外跟随内层分隔线。
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var items: [NSToolbarItem.Identifier] = [
            .init("open"), .init("repositories"), .init("sidebarSeparator"), .flexibleSpace,
        ]

        if workingCopySplit != nil {
            items.append(.init("detailSeparator"))
            items.append(contentsOf: [.init("stageAll"), .init("commit")])
        }

        if !showsManager, session.repository?.host != nil {
            items.append(.init("host"))
        }

        if !showsManager { items.append(contentsOf: [.init("sync"), .init("merge")]) }

        return items + [.init("terminal"), .init("finder"), .init("refresh"), .init("closeRepository")]
    }

    /// 工具栏固定为本里程碑已有动作。
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    /// 使用系统符号创建按钮，并让分隔符跟随对应分栏。
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if identifier.rawValue == "sync" {
            let group = SyncToolbarGroup(
                itemIdentifier: identifier,
                images: ["arrow.down.circle", "arrow.down.to.line", "arrow.up.circle"]
                    .map {
                        NSImage(systemSymbolName: $0, accessibilityDescription: nil)!
                    },
                selectionMode: .momentary,
                labels: ["sync.fetch", "sync.pull", "sync.push"].map { AppLocalization.text($0) },
                target: self,
                action: #selector(syncSegment(_:))
            )
            group.check = { [weak self] in
                guard let self else { return [false, false, false] }
                return [#selector(self.fetch), #selector(self.pull), #selector(self.push)]
                    .map {
                        let item = NSMenuItem(title: "", action: $0, keyEquivalent: "")
                        return self.validateUserInterfaceItem(item)
                    }
            }
            group.validate()
            return group
        }
        if identifier.rawValue == "host", let host = session.repository?.host {
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.label = host + ":"
            let label = NSTextField(labelWithString: item.label)
            label.font = .systemFont(ofSize: 11)
            label.setAccessibilityLabel(session.repository?.displayPath)
            item.view = label
            return item
        }

        if identifier.rawValue == "sidebarSeparator", let outerSplit {
            return NSTrackingSeparatorToolbarItem(
                identifier: identifier,
                splitView: outerSplit.splitView,
                dividerIndex: 0
            )
        }

        if identifier.rawValue == "detailSeparator", let workingCopySplit {
            return NSTrackingSeparatorToolbarItem(
                identifier: identifier,
                splitView: workingCopySplit.splitView,
                dividerIndex: 0
            )
        }

        let configuration: (String, String, Selector)

        switch identifier.rawValue {
        case "merge":
            configuration = ("sync.merge", "arrow.triangle.merge", #selector(merge))
        case "stageAll":
            configuration = ("working.stageAll", "checkmark.square", #selector(stageAll))

        case "commit":
            configuration = ("working.commit", "checkmark.circle", #selector(composeCommit))

        case "open":
            configuration = ("action.openLocal", "folder.badge.plus", #selector(chooseRepository))

        case "repositories":
            configuration = ("repositories.title", "externaldrive", #selector(showRepositories))

        case "terminal":
            configuration = ("action.openTerminal", "apple.terminal", #selector(openInTerminal))

        case "finder":
            configuration = ("action.revealFinder", "finder", #selector(revealInFinder))

        case "refresh":
            configuration = ("action.refresh", "arrow.clockwise", #selector(refreshRepository))

        case "closeRepository":
            configuration = ("action.closeRepository", "xmark.circle", #selector(closeRepository))

        default:
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = AppLocalization.text(configuration.0)
        item.toolTip = session.repository?.host.map { $0 + ": " + item.label } ?? item.label
        item.image = NSImage(systemSymbolName: configuration.1, accessibilityDescription: item.label)
        item.target = self
        item.action = configuration.2
        return item
    }

    /// 本窗口的修饰键、提交快捷键和工具栏状态使用同一事件源。
    private func configureWorkingCopyKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                guard let self, NSApp.keyWindow === self.window, !self.showsManager,
                      self.session.activeView == .workingCopy,
                      self.window?.attachedSheet == nil else { return false }
                let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
                if event.type == .flagsChanged {
                    let unstage = flags.contains(.option)
                        && self.session.status?.entries.contains(where: \.hasStagedChanges) == true
                    let item = self.window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "stageAll" }
                    item?.label = AppLocalization.text(unstage ? "working.unstageAll" : "working.stageAll")
                    item?.toolTip = item?.label
                    self.window?.toolbar?.validateVisibleItems()
                    return false
                }

                let enter = event.keyCode == 36 && (flags == .command || flags == [.command, .option])
                    || event.keyCode == 76 && flags.isEmpty
                guard enter, self.session.isEditingCommitMessage || flags.contains(.option) else { return false }

                // 快速修补在确认前捕获最近信息，取消确认不会覆盖原来的普通草稿。
                let quick = flags.contains(.option) && !self.session.isEditingCommitMessage && !self.session.amend
                if quick { self.session.setAmend(true) }

                if let operation = self.session.context?.operation,
                   [.rebase, .cherryPick, .revert].contains(operation),
                   self.session.canWrite, self.session.conflictCount == 0 {
                    self.session.finishOperation("continue")
                } else if self.session.canCommit {
                    self.session.commit()
                } else {
                    NSSound.beep()
                }

                if quick { self.session.setAmend(false) }
                return true
            }
            return handled ? nil : event
        }
    }

    /// 分段工具栏只分派已有动作，禁用状态逐段校验。
    @objc private func syncSegment(_ sender: NSToolbarItemGroup) {
        switch sender.selectedIndex {
        case 0: fetch()
        case 1: pull()
        case 2: push()
        default: break
        }
    }

    /// 仓库主视图切换没有转场；工作区与历史分别保存分栏宽度。
    private func configureRepositoryView() {
        guard let repository = session.repository else {
            return
        }

        window?.title = repository.name
        window?.subtitle = repository.displayPath
        window?.representedURL = repository.localURL

        let sidebar = NSHostingController(rootView: RepositorySidebarView(
            session: session,
            selectionChanged: { [weak self] in self?.configureRepositoryView() },
            openTerminal: { [weak self] in self?.openInTerminal() },
            revealFinder: { [weak self] in self?.revealInFinder() },
            copyPath: { [weak self] in self?.copyPath() },
            request: { [weak self] in self?.presentRepositoryAction($0) },
            showActivity: { [weak self] in self?.showActivity() }
        ))
        sidebar.sizingOptions = [.minSize]
        let detail: NSViewController

        switch session.activeView {
        case .workingCopy:
            historySplit = nil
            let split = NSSplitViewController()
            split.splitView.isVertical = true
            split.splitView.dividerStyle = .thin
            split.splitView.autosaveName = "Spooky.WorkingCopy"

            // 窗口与分栏决定内容尺寸，HostingController 只提供最小内容约束。
            let list = NSHostingController(rootView: WorkingCopyListView(session: session))
            list.sizingOptions = [.minSize]
            let listItem = NSSplitViewItem(contentListWithViewController: list)
            listItem.holdingPriority = .init(475)
            listItem.canCollapse = false

            let fileDetail = NSHostingController(rootView: WorkingCopyDetailView(session: session))
            fileDetail.sizingOptions = [.minSize]
            let detailItem = NSSplitViewItem(viewController: fileDetail)
            detailItem.holdingPriority = .init(470)

            split.addSplitViewItem(listItem)
            split.addSplitViewItem(detailItem)
            workingCopySplit = split
            detail = split

        case .history:
            workingCopySplit = nil
            let split = NSSplitViewController()
            split.splitView.isVertical = true
            split.splitView.dividerStyle = .thin
            split.splitView.autosaveName =
                session.history.showsCommitPage ? "Spooky.Commit" : "Spooky.History"
            let list: NSViewController
            let content: NSViewController

            if session.history.showsCommitPage {
                let controller = NSHostingController(
                    rootView: CommitFileListView(history: session.history) { [weak self] in
                        self?.session.history.showsCommitPage = false
                        self?.configureRepositoryView()
                    }
                )
                controller.sizingOptions = [.minSize]
                list = controller
                let diff = NSHostingController(rootView: CommitPageDiffView(history: session.history))
                diff.sizingOptions = [.minSize]
                content = diff
            } else {
                let controller = NSHostingController(
                    rootView: HistoryListView(
                        session: session,
                        createBranch: { [weak self] in
                            self?
                                .presentRepositoryAction(
                                    RepositoryActionRequest(kind: .create, reference: $0)
                                )
                        },
                        openCommit: { [weak self] in self?.showCommitPage() }
                    )
                )
                controller.sizingOptions = [.minSize]
                list = controller
                let detail = NSHostingController(rootView: CommitDetailView(history: session.history))
                detail.sizingOptions = [.minSize]
                content = detail
            }
            let listItem = NSSplitViewItem(contentListWithViewController: list)
            listItem.minimumThickness = 300
            listItem.holdingPriority = .init(475)
            listItem.canCollapse = false
            let contentItem = NSSplitViewItem(viewController: content)
            contentItem.holdingPriority = .init(470)
            contentItem.canCollapse = false
            split.addSplitViewItem(listItem)
            split.addSplitViewItem(contentItem)
            historySplit = split
            detail = split
        }

        installOuterSplit(sidebar: sidebar, detail: detail, name: "Spooky.Repository")

        // 首次使用工作区时列表宽 400 pt，此后交给 NSSplitView 的 autosave 恢复。
        if UserDefaults.standard.object(forKey: "NSSplitView Subview Frames Spooky.WorkingCopy") == nil {
            workingCopySplit?.splitView.setPosition(400, ofDividerAt: 0)
        }
        if let historySplit, let name = historySplit.splitView.autosaveName,
            UserDefaults.standard.object(forKey: "NSSplitView Subview Frames " + name) == nil
        {
            historySplit.splitView.setPosition(320, ofDividerAt: 0)
        }
    }

    /// 侧边栏不可折叠且最小 150 pt，宽度按视图保存并在仓库间共用。
    private func installOuterSplit(
        sidebar: NSViewController,
        detail: NSViewController,
        name: String
    ) {
        let split: NSSplitViewController

        // 仓库内切换只替换详情，保留侧边栏的展开状态、选择与键盘焦点。
        if name == "Spooky.Repository", let existing = outerSplit,
            existing.splitView.autosaveName == name, existing.splitViewItems.count == 2
        {
            split = existing
            split.removeSplitViewItem(split.splitViewItems[1])
        } else {
            split = NSSplitViewController()
            split.splitView.isVertical = true
            split.splitView.dividerStyle = .thin
            split.splitView.autosaveName = name

            let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
            sidebarItem.minimumThickness = 150
            sidebarItem.canCollapse = false
            sidebarItem.holdingPriority = .init(485)
            sidebarItem.titlebarSeparatorStyle = .none
            split.addSplitViewItem(sidebarItem)
        }

        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.holdingPriority = .init(480)
        detailItem.titlebarSeparatorStyle = .line

        split.addSplitViewItem(detailItem)
        outerSplit = split
        window?.contentViewController = split
        window?.contentView?.layoutSubtreeIfNeeded()

        let toolbar = NSToolbar(identifier: "Spooky.MainToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.delegate = self
        window?.toolbar = toolbar
    }
}

/// 系统分段工具栏对每个网络动作分别更新可用性。
@MainActor
private final class SyncToolbarGroup: NSToolbarItemGroup {
    /// 当前窗口提供的动作校验。
    var check: (() -> [Bool])?

    /// 每次菜单或工具栏刷新时同步三段状态。
    override func validate() {
        super.validate()
        for (index, enabled) in (check?() ?? []).enumerated() {
            if subitems.indices.contains(index) { subitems[index].isEnabled = enabled }
            (view as? NSSegmentedControl)?.setEnabled(enabled, forSegment: index)
        }
    }
}
