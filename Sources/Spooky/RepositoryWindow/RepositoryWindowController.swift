import AppKit
import SpookyKit
import SwiftUI

// MARK: - RepositoryWindowController

/// 仓库窗口的 AppKit 外壳，负责两层分栏、工具栏与错误 sheet。
@MainActor
final class RepositoryWindowController: NSWindowController, NSWindowDelegate,
    NSToolbarDelegate, NSUserInterfaceValidations
{
    /// 首次打开或恢复失败时使用的内容尺寸。
    static let defaultContentSize = NSSize(width: 1000, height: 540)

    /// 窗口位置与尺寸的 autosave 名称。
    private static let frameName = "Spooky.RepositoryWindow"

    /// 首次打开或恢复失败时外层侧边栏的宽度。
    private static let defaultSidebarWidth: CGFloat = 260

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

    /// 历史、整页提交详情与文件历史拥有各自保存宽度的内层分栏。
    private var historySplit: NSSplitViewController?

    /// 窗口级快捷键跨越 AppKit 文件列表与 SwiftUI 信息框。
    private var keyMonitor: Any?

    /// 文件历史搜索框的贡献者补全。
    let contributorCompletion = ContributorCompletion()

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
        configureCommentPrompt()
        session.onFailure = { [weak self] in self?.showFailure($0) }

        session.history.onFailure = { [weak self] error in
            guard let self else { return }

            if error is RemoteConnectionError {
                self.session.reconnect()
            } else {
                showFailure(AppFailure(error: error, opening: false, location: self.session.repository))
            }
        }

        // 断线写入的核对结果、写入后的跨窗口刷新与视图回退都由窗口承接。
        session.onRecovery = { [weak self] in self?.showRecovery($0, snapshot: $1) }

        session.onWriteFinished = { [weak self] location in
            guard let self else { return }
            self.coordinator?.repositoryChanged(location, by: self)
        }

        session.onStashRequest = { [weak self] in self?.presentStash($0) }
        session.onRevisionRequest = { [weak self] in self?.presentRevisionDialog($0) }

        session.onViewReset = { [weak self] in
            guard let self, !self.showsManager else { return }
            configureRepositoryView()
        }

        // 文件视图与提交详情的入口在内容区里，切换主视图后同样重建分栏
        session.onActiveViewChange = { [weak self] in
            guard let self, !self.showsManager else { return }
            configureRepositoryView()
        }

        // 文件操作的参数表单与多按钮询问同样以窗口的 sheet 呈现
        session.onFileRequest = { [weak self] in self?.presentFileRequest($0) }

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
        restoreFrame()
        observeToolbarState()
        observeConnectionState()
        observeSubtitle()
        observeHistorySearch()
    }

    /// 窗口由代码构建，不从归档恢复控制器。
    required init?(coder _: NSCoder) {
        nil
    }

    /// 核对结果的说明：没有新的核对表示写入未在服务器上开始，否则比较写入前后的 HEAD。
    static func recoveryMessage(_ write: InterruptedWrite, snapshot: RemoteRecoverySnapshot?) -> String {
        guard let snapshot else {
            return AppLocalization.text("recovery.notStarted", write.title)
        }

        let before = write.branch?.oid
        let after = snapshot.status.branch.oid
        let name: (String?) -> String = { $0.map { String($0.prefix(8)) } ?? AppLocalization.text("recovery.unborn") }
        let summary = before == after
            ? AppLocalization.text("recovery.unchanged", write.title, name(after))
            : AppLocalization.text("recovery.changed", write.title, name(before), name(after))
        let state = AppLocalization.text(
            "connection.recovery",
            snapshot.status.branch.head ?? AppLocalization.text("branch.detachedShort"),
            snapshot.status.entries.count,
            AppLocalization.text(snapshot.indexLocked ? "state.yes" : "state.no"),
            AppLocalization.text(snapshot.merging ? "state.yes" : "state.no"),
            AppLocalization.text(snapshot.rebasing ? "state.yes" : "state.no")
        )
        return summary + "\n\n" + state
    }

    /// 恢复的窗口位置必须有一半以上落在某个屏幕内，且尺寸不超过该屏幕；否则视为恢复失败。
    static func isUsable(_ frame: NSRect, in screens: [NSRect]) -> Bool {
        screens.contains { screen in
            let visible = frame.intersection(screen)
            return frame.width <= screen.width && frame.height <= screen.height
                && visible.width * visible.height >= frame.width * frame.height / 2
        }
    }

    /// 分栏宽度记录里每一栏都至少 1 pt 宽才沿用；各栏都不可折叠，零宽或无法读取的记录只会来自损坏的保存值。
    static func isUsable(splitFrames: [Any]) -> Bool {
        !splitFrames.isEmpty && splitFrames.allSatisfy { frame in
            // 每条记录形如 “x, y, 宽, 高, 折叠, 隐藏”。
            let fields = (frame as? String)?.split(separator: ",") ?? []
            let width = fields.count > 2 ? Double(fields[2].trimmingCharacters(in: .whitespaces)) : nil

            return (width ?? 0) >= 1
        }
    }

    /// 显示已验证的仓库，并立即开始读取工作区。
    func display(_ repository: RepositoryLocation) {
        let sameRepositoryView = session.repository == repository && !showsManager
        session.display(repository)
        showsManager = false
        window?.title = repository.name
        updateSubtitle()
        window?.representedURL = repository.localURL

        if !sameRepositoryView {
            configureRepositoryView()
        }

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)

        // 从仓库管理回到仓库时恢复前台轮询；重新显示总是读取一次完整状态。
        session.setActive(true)

        if !session.isRefreshing {
            session.refresh(full: true)
        }
    }

    /// 在同一个窗口显示仓库管理，保留当前仓库会话供再次打开。
    @objc
    func showRepositories() {
        guard let coordinator else {
            return
        }

        showsManager = true
        window?.title = AppLocalization.text("repositories.title")
        updateSubtitle()
        window?.representedURL = nil
        workingCopySplit = nil
        historySplit = nil

        // 管理页显示期间保留仓库会话，但按后台频率轮询。
        session.setActive(false)

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

    /// 窗口激活会立即刷新仓库状态；显示管理页时仓库保持后台频率。
    func windowDidBecomeKey(_: Notification) {
        session.setActive(!showsManager)
    }

    /// 后台窗口降为十秒轮询。
    func windowDidResignKey(_: Notification) {
        session.setActive(false)
    }

    /// 关窗时取消该窗口的工作，并从应用窗口集合中移除。
    func windowWillClose(_: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        coordinator?.cancelOpening(in: self)
        let location = session.repository
        session.close()
        coordinator?.removeWindow(self)
        if let location { coordinator?.releaseConnection(location) }
    }
}

// MARK: - Navigation

extension RepositoryWindowController {
    /// 打开系统目录选择器，发起窗口决定普通打开的目的地。
    @objc
    func chooseRepository() {
        coordinator?.chooseRepository(in: self)
    }

    /// 体检在表单内部进行，只有成功的工作区才进入可用列表。
    @objc
    func addRemoteRepository() {
        guard let window, window.attachedSheet == nil else { return }
        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed
        let view = AddRemoteRepositoryView(
            opened: { [weak self, weak sheet] repository in
                guard let self, let sheet else { return }
                window.endSheet(sheet)
                coordinator?.displayRepository(repository, from: self, inNewWindow: false)
            },
            cancelled: { [weak sheet] in
                guard let sheet else { return }
                window.endSheet(sheet)
            }
        )
        sheet.contentViewController = NSHostingController(rootView: view)
        window.beginSheet(sheet)
    }

    /// 关闭仓库只回到管理界面，不关闭窗口或结束 App。
    @objc
    func closeRepository() {
        coordinator?.cancelOpening(in: self)
        let location = session.repository
        session.close()
        if let location { coordinator?.releaseConnection(location) }
        showRepositories()
    }

    /// 切换到工作区，⌘1 与侧边栏使用相同状态。
    @objc
    func showWorkingCopy() {
        guard session.repository != nil else {
            return
        }

        session.activeView = .workingCopy
        showsManager = false
        configureRepositoryView()
    }

    /// 切换到全部分支历史，⌘2 与侧边栏使用相同状态。
    @objc
    func showHistory() {
        guard session.repository != nil else {
            return
        }

        session.activeView = .history
        session.history.showsCommitPage = false
        session.history.selectedReference = nil
        showsManager = false
        configureRepositoryView()
    }

    /// 切换到储藏列表，⌘3 与侧边栏使用相同状态。
    @objc
    func showStashes() {
        guard session.repository != nil else {
            return
        }

        session.activeView = .stashes
        showsManager = false
        configureRepositoryView()
    }

    /// ⌘0 选中当前 HEAD，分离和未出生分支仍可定位。
    @objc
    func showHeadBranch() {
        guard session.repository != nil else { return }
        session.activeView = .history
        session.history.showsCommitPage = false
        session.history.selectedReference = session.status?.branch.head.map { "refs/heads/" + $0 } ?? "HEAD"
        showsManager = false
        configureRepositoryView()
    }

    /// 双击详情保留提交选择，只替换内层分栏。
    func showCommitPage() {
        session.history.showsCommitPage = true
        configureRepositoryView()
    }

    /// 全局 Activity 窗口由应用统一持有。
    @objc
    func showActivity() { coordinator?.showActivity() }
}

// MARK: - Alerts

extension RepositoryWindowController {
    /// 把错误原文放入可滚动、可复制的附件，恢复操作在 sheet 结束后执行。
    func showFailure(_ failure: AppFailure) {
        guard let window else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = failure.title
        alert.informativeText = failure.message + "\n\n" + failure.context
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
                if failure.isRemoteFailure { addRemoteRepository() }
                else { chooseRepository() }
            } else {
                refreshRepository()
            }
        }
    }

    /// 重连核对后报告中断写入的结果：HEAD 是否变化与仓库状态；写入没有被重试。
    func showRecovery(_ write: InterruptedWrite, snapshot: RemoteRecoverySnapshot?) {
        guard let window else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = AppLocalization.text("recovery.title")
        alert.informativeText = Self.recoveryMessage(write, snapshot: snapshot)
            + (session.repository.map { "\n\n" + AppLocalization.text("failure.location", $0.displayPath) } ?? "")
        alert.addButton(withTitle: AppLocalization.text("action.close"))

        // 中断时的错误 sheet 可能仍未关闭，AppKit 会在它结束后依次显示。
        alert.beginSheetModal(for: window)
    }
}

// MARK: - Toolbar

extension RepositoryWindowController {
    /// 当前视图需要的工具栏项，工作区额外跟随内层分隔线。
    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
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

        if !showsManager { items.append(contentsOf: [.init("sync"), .init("merge"), .init("stashes")]) }

        items += [.init("terminal"), .init("finder"), .init("refresh"), .init("closeRepository")]

        // 搜索框排在最后，空间不足时最后才收进溢出菜单
        return showsManager ? items : items + [.init("search")]
    }

    /// 工具栏固定为本里程碑已有动作。
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    /// 使用系统符号创建按钮，并让分隔符跟随对应分栏。
    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        if identifier.rawValue == "sync" {
            let group = NSToolbarItemGroup(
                itemIdentifier: identifier,
                images: ["arrow.down.circle", "arrow.down.to.line", "arrow.up.circle"]
                    .map {
                        // 取不到符号时以空图占位，分段数与标签保持一致。
                        NSImage(systemSymbolName: $0, accessibilityDescription: nil) ?? NSImage()
                    },
                selectionMode: .momentary,
                labels: ["sync.fetch", "sync.pull", "sync.push"].map { AppLocalization.text($0) },
                target: self,
                action: nil
            )

            // 始终以分段控件显示，空间不足时整组进入工具栏的溢出菜单。
            group.controlRepresentation = .expanded

            // 每段带上自己的动作：点击直接分派到对应动作，工具栏自动校验时也逐段决定可用性。
            let actions = [#selector(fetch), #selector(pull), #selector(push)]

            for (segment, action) in zip(group.subitems, actions) {
                segment.target = self
                segment.action = action
            }

            return group
        }
        if identifier.rawValue == "search" {
            return makeSearchItem(identifier)
        }

        if identifier.rawValue == "stashes" {
            return makeStashToolbarItem(identifier)
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
}

// MARK: - Private

extension RepositoryWindowController {
    /// 分栏按名称恢复宽度；记录不可用时视为恢复失败，先清除记录，由调用方按默认宽度建立。
    static func setAutosaveName(_ name: String, of split: NSSplitViewController) {
        let key = "NSSplitView Subview Frames " + name

        if let frames = UserDefaults.standard.array(forKey: key), !isUsable(splitFrames: frames) {
            UserDefaults.standard.removeObject(forKey: key)
        }

        split.splitView.autosaveName = name
    }

    /// 恢复上次的位置和尺寸；记录缺失或已不在任何屏幕内时回到默认尺寸并居中。
    private func restoreFrame() {
        guard let window else {
            return
        }

        // 内容控制器装入后再设初始尺寸，避免 SwiftUI 的理想尺寸覆盖窗口默认值。
        window.setContentSize(Self.defaultContentSize)
        let restored = window.setFrameUsingName(Self.frameName)

        if !restored || !Self.isUsable(window.frame, in: NSScreen.screens.map(\.visibleFrame)) {
            window.setContentSize(Self.defaultContentSize)
            window.center()
        }

        window.setFrameAutosaveName(Self.frameName)
    }

    /// 写入、刷新与连接状态异步变化后重新校验工具栏，结束的操作立即恢复按钮。
    private func observeToolbarState() {
        withObservationTracking {
            for action in [
                #selector(fetch), #selector(pull), #selector(push), #selector(merge),
                #selector(stageAll), #selector(refreshRepository), #selector(closeRepository),
                #selector(applyStash), #selector(saveStash),
            ] {
                _ = validateUserInterfaceItem(NSMenuItem(title: "", action: action, keyEquivalent: ""))
            }
        } onChange: { [weak self] in
            // 变更通知早于新值写入，下一轮主线程再校验并重新订阅。
            Task { @MainActor in
                self?.window?.toolbar?.validateVisibleItems()
                self?.observeToolbarState()
            }
        }
    }

    /// 连接状态变化后通知应用，App 图标上的指示灯随所有窗口的连接状态亮灭。
    private func observeConnectionState() {
        withObservationTracking {
            _ = session.connectionState
        } onChange: { [weak self] in
            // 变更通知早于新值写入，下一轮主线程再通知并重新订阅。
            Task { @MainActor in
                self?.coordinator?.connectionStateChanged()
                self?.observeConnectionState()
            }
        }
    }

    /// 本窗口的修饰键、提交快捷键和工具栏状态使用同一事件源。
    private func configureWorkingCopyKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                self?.handleWorkingCopyKey(event) ?? false
            }

            return handled ? nil : event
        }
    }

    /// 工作区处于前台时处理按键：修饰键变化时切换全部暂存按钮的文案，回车键提交或继续进行中的操作；返回事件是否已处理。
    private func handleWorkingCopyKey(_ event: NSEvent) -> Bool {
        guard
            NSApp.keyWindow === window, !showsManager,
            session.activeView == .workingCopy,
            window?.attachedSheet == nil
        else { return false }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])

        // 按住 ⌥ 且有已暂存改动时，全部暂存按钮改为全部取消暂存。
        if event.type == .flagsChanged {
            let unstage = flags.contains(.option)
                && (session.status?.entries.contains(where: \.hasStagedChanges) ?? false)
            let item = window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "stageAll" }
            item?.label = AppLocalization.text(unstage ? "working.unstageAll" : "working.stageAll")
            item?.toolTip = item?.label
            window?.toolbar?.validateVisibleItems()
            return false
        }

        // 主键盘回车需要 ⌘ 或 ⌘⌥，小键盘回车不带修饰键；只在编辑提交信息或按住 ⌥ 时生效。
        let enter = event.keyCode == 36 && (flags == .command || flags == [.command, .option])
            || event.keyCode == 76 && flags.isEmpty
        guard enter, session.isEditingCommitMessage || flags.contains(.option) else { return false }

        // 快速修补在确认前捕获最近信息，取消确认不会覆盖原来的普通草稿。
        let quick = flags.contains(.option) && !session.isEditingCommitMessage && !session.amend
        if quick { session.setAmend(true) }

        if
            let operation = session.context?.operation,
            [.rebase, .cherryPick, .revert].contains(operation),
            session.canWrite, session.conflictCount == 0
        {
            session.finishOperation("continue")
        } else if session.canCommit {
            session.commit()
        } else {
            NSSound.beep()
        }

        if quick { session.setAmend(false) }
        return true
    }

    /// 仓库主视图切换没有转场；工作区与历史分别保存分栏宽度。
    private func configureRepositoryView() {
        guard let repository = session.repository else {
            return
        }

        window?.title = repository.name
        updateSubtitle()
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
            let split = makeWorkingCopySplit()
            workingCopySplit = split
            detail = split

        case .history:
            workingCopySplit = nil
            let split = makeHistorySplit()
            historySplit = split
            detail = split

        case .stashes:
            workingCopySplit = nil
            historySplit = nil
            detail = makeStashSplit()

        case .fileHistory:
            workingCopySplit = nil
            let split = makeFileHistorySplit()
            historySplit = split
            detail = split

        case .fileContent:
            workingCopySplit = nil
            historySplit = nil
            detail = makeFileContentView()
        }

        installOuterSplit(sidebar: sidebar, detail: detail, name: "Spooky.Repository")

        // 首次使用或恢复失败后工作区列表宽 400 pt、历史与文件历史的列表宽 320 pt，此后交给 NSSplitView 的 autosave 恢复。
        if UserDefaults.standard.object(forKey: "NSSplitView Subview Frames Spooky.WorkingCopy") == nil {
            workingCopySplit?.splitView.setPosition(400, ofDividerAt: 0)
        }

        if
            let historySplit, let name = historySplit.splitView.autosaveName,
            UserDefaults.standard.object(forKey: "NSSplitView Subview Frames " + name) == nil
        {
            historySplit.splitView.setPosition(320, ofDividerAt: 0)
        }

        // 首次使用或恢复失败后储藏列表同样宽 320 pt，此后交给 NSSplitView 的 autosave 恢复。
        if
            session.activeView == .stashes, let split = detail as? NSSplitViewController,
            UserDefaults.standard.object(forKey: "NSSplitView Subview Frames Spooky.Stashes") == nil
        {
            split.splitView.setPosition(320, ofDividerAt: 0)
        }
    }

    /// 工作区的文件列表与 Diff 详情分栏，宽度按工作区单独保存。
    private func makeWorkingCopySplit() -> NSSplitViewController {
        let split = NSSplitViewController()
        split.splitView.isVertical = true
        split.splitView.dividerStyle = .thin
        Self.setAutosaveName("Spooky.WorkingCopy", of: split)

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
        return split
    }

    /// 历史的提交列表与提交详情分栏；整页提交详情换成文件列表与补丁，两种布局分别保存宽度。
    private func makeHistorySplit() -> NSSplitViewController {
        let split = NSSplitViewController()
        split.splitView.isVertical = true
        split.splitView.dividerStyle = .thin
        Self.setAutosaveName(session.history.showsCommitPage ? "Spooky.Commit" : "Spooky.History", of: split)

        let list: NSViewController
        let content: NSViewController

        if session.history.showsCommitPage {
            let controller = NSHostingController(
                rootView: CommitFileListView(session: session, history: session.history) { [weak self] in
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

            let detail = NSHostingController(rootView: CommitDetailView(history: session.history, session: session))
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
        return split
    }

    /// 侧边栏不可折叠且最小 150 pt，宽度按视图保存并在仓库间共用。
    private func installOuterSplit(
        sidebar: NSViewController,
        detail: NSViewController,
        name: String
    ) {
        let split: NSSplitViewController

        // 仓库内切换只替换详情，保留侧边栏的展开状态、选择与键盘焦点。
        if
            name == "Spooky.Repository", let existing = outerSplit,
            existing.splitView.autosaveName == name, existing.splitViewItems.count == 2
        {
            split = existing
            split.removeSplitViewItem(split.splitViewItems[1])
        } else {
            split = NSSplitViewController()
            split.splitView.isVertical = true
            split.splitView.dividerStyle = .thin
            Self.setAutosaveName(name, of: split)

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

        // 换入的分栏先取当前内容尺寸：AppKit 会把窗口缩放到新视图的尺寸，缩小的窗口还会改写分栏的宽度记录。
        if let size = window?.contentView?.frame.size {
            split.view.setFrameSize(size)
        }

        window?.contentViewController = split
        window?.contentView?.layoutSubtreeIfNeeded()

        // 首次使用或恢复失败后侧边栏宽 260 pt，此后交给 NSSplitView 的 autosave 恢复。
        if UserDefaults.standard.object(forKey: "NSSplitView Subview Frames " + name) == nil {
            split.splitView.setPosition(Self.defaultSidebarWidth, ofDividerAt: 0)
        }

        let toolbar = NSToolbar(identifier: "Spooky.MainToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.delegate = self
        window?.toolbar = toolbar
    }
}
