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

    /// 本窗口的后退 / 前进记录。
    var navigation = NavigationHistory()

    /// 工具栏 Clone 项弹出的最近克隆。
    var clonePopover: NSPopover?

    /// 正在按视图引用切换视图，中途经过的视图不记进后退 / 前进记录。
    var isApplyingReference = false

    /// 跨窗口的打开与记录管理。
    private(set) weak var coordinator: SpookyApplicationController?

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

    /// Edit 菜单撤销与重做的本仓库写操作，栈与同一仓库的其它窗口共用。
    lazy var repositoryUndoManager = RepositoryUndoManager(session: session)

    /// 文本框与提交信息编辑框自己的文字撤销。
    let textUndoManager = UndoManager()

    /// 本窗口仓库的自动获取：只在窗口显示仓库且 App 处于前台时进行。
    private lazy var autoFetch = RepositoryAutoFetch(session: session) { [weak self] in
        NSApp.isActive && !(self?.showsManager ?? true)
    }

    /// 创建原生窗口；窗口按系统偏好参与标签页，并以视图引用参与系统的窗口恢复。
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
        window.tabbingMode = .automatic
        window.collectionBehavior = [.fullScreenPrimary]

        // 重新启动时由恢复类按保存的视图引用重建窗口
        window.identifier = RepositoryWindowRestoration.identifier
        window.restorationClass = RepositoryWindowRestoration.self
        window.isRestorable = true
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
        session.onRewriteRequest = { [weak self] in self?.presentRewrite($0) }

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

        // 分支、标签与远端管理的对话框与询问同样以窗口的 sheet 呈现
        session.onReferenceRequest = { [weak self] in self?.presentReferenceRequest($0) }

        // 子模块与工作树的对话框与询问同样以窗口的 sheet 呈现
        session.submodules.onRequest = { [weak self] in self?.presentSubmoduleRequest($0) }
        session.worktrees.onRequest = { [weak self] in self?.presentWorktreeRequest($0) }

        // 请求视图的对话框同样以窗口的 sheet 呈现
        session.pullRequests.onRequest = { [weak self] in self?.presentPullRequestRequest($0) }

        // 子模块、父仓库与工作树在本窗口、新标签或新窗口打开
        session.onOpenRepository = { [weak self] location, target in self?.openRepository(at: location, in: target) }
        session.onOpenInTerminal = { [weak self] in self?.openLocationInTerminal($0) }

        // 批量归档对话框与自动归档的确认同样以窗口的 sheet 呈现
        configureBranchesReview()

        // 侧边栏与标签菜单预选了分支或版本的同步对话框同样以窗口的 sheet 呈现
        session.onSyncRequest = { [weak self] in self?.presentSyncDialog($0.kind, preselecting: $0.preselection) }

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
        configureToolbar()
        restoreFrame()
        observeToolbarState()
        observeConnectionState()
        observeSubtitle()
        observeHistorySearch()
        autoFetch.start()
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
        return summary + "\n\n" + state + "\n\n" + remoteReferenceChanges(write, snapshot: snapshot)
    }

    /// 中断前后远端跟踪分支的变化，每个变化的分支一行；获取或推送可能已经部分完成。
    static func remoteReferenceChanges(_ write: InterruptedWrite, snapshot: RemoteRecoverySnapshot) -> String {
        let before = write.remoteReferences
        let after = snapshot.remoteReferences

        // 提交取前 8 位，引用不存在时写 “无”
        let name: (String?) -> String = { object in
            object.map { String($0.prefix(8)) } ?? AppLocalization.text("recovery.noReference")
        }

        let changes = Set(before.keys).union(after.keys)
            .filter { before[$0] != after[$0] }
            .sorted()
            .map { reference in
                let branch = String(reference.dropFirst("refs/remotes/".count))
                return branch + "  " + name(before[reference]) + " → " + name(after[reference])
            }

        guard !changes.isEmpty else {
            return AppLocalization.text("recovery.remoteUnchanged")
        }

        return AppLocalization.text("recovery.remoteChanged") + "\n" + changes.joined(separator: "\n")
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

        // 侧边栏与详情区共用本窗口的仓库管理状态
        let manager = RepositoryManagerController(bookmarks: coordinator.bookmarks, session: session)
        manager.window = self
        manager.coordinator = coordinator

        let detail = NSHostingController(rootView: RepositoryManagerDetailView(manager: manager))
        detail.sizingOptions = [.minSize]

        installOuterSplit(
            sidebar: BookmarkSidebarController(manager: manager),
            detail: detail,
            name: "Spooky.Repositories"
        )
        coordinator.bookmarks.validate()
        didChangeView()
    }

    /// 打开的仓库找不到或连不上时，整个窗口换成丢失页；会话与上一个仓库的连接一并交还。
    ///
    /// - Parameters:
    ///   - location: 打不开的仓库。
    ///   - reason: 路径不存在或服务器连不上。
    func showMissingRepository(_ location: RepositoryLocation, reason: MissingRepositoryView.Reason) {
        let page = NSHostingController(rootView: MissingRepositoryView(
            location: location,
            reason: reason,
            session: session,
            refresh: { [weak self] in
                guard let self else {
                    return
                }

                coordinator?.openRepository(at: location, from: self, inNewWindow: false)
            },
            close: { [weak self] in self?.showRepositories() }
        ))
        page.sizingOptions = [.minSize]

        showPage(page, title: location.name)
    }

    /// 整个窗口换成一页：仓库丢失页或克隆进度页。会话与上一个仓库的连接一并交还，标题换成页面所指的仓库。
    ///
    /// - Parameters:
    ///   - page: 换入的页面。
    ///   - title: 窗口标题。
    func showPage(_ page: NSViewController, title: String) {
        let previous = session.repository
        session.close()

        if let previous {
            coordinator?.releaseConnection(previous)
        }

        showsManager = false
        outerSplit = nil
        workingCopySplit = nil
        historySplit = nil
        window?.title = title
        window?.representedURL = nil
        updateSubtitle()

        // 换入的页面先取当前内容尺寸，窗口不随新视图缩放
        if let size = window?.contentView?.frame.size {
            page.view.setFrameSize(size)
        }

        window?.contentViewController = page
        updateToolbarItems()
    }

    /// 窗口激活会立即刷新仓库状态；显示管理页时仓库保持后台频率。
    func windowDidBecomeKey(_: Notification) {
        session.setActive(!showsManager)
    }

    /// 后台窗口降为十秒轮询；App 或窗口失去前台时，按住 ⌥ 换出的快速操作复原。
    func windowDidResignKey(_: Notification) {
        session.setActive(false)
        updateQuickToolbarItems(option: false)
    }

    /// 关窗时取消该窗口的工作，并从应用窗口集合中移除。
    func windowWillClose(_: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        autoFetch.stop()
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

    /// 切换到分支整理，⌘5 与侧边栏使用相同状态。
    @objc
    func showBranchesReview() {
        guard session.repository != nil else { return }
        session.activeView = .branchesReview
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
                #selector(fetch), #selector(pull), #selector(push), #selector(sync),
                #selector(merge), #selector(rebase), #selector(refreshRepository), #selector(closeRepository),
                #selector(applyStash), #selector(saveStash), #selector(createBranch),
                #selector(forcePushWithLease), #selector(pushRevision), #selector(pushToGerritRemote),
                #selector(stageAll), #selector(composeCommit),
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
                // 主窗口的同步按钮随 ⌥ 换成快速操作，全部暂存换成全部取消暂存，与当前视图无关
                if event.type == .flagsChanged, let self, NSApp.keyWindow === self.window {
                    let option = event.modifierFlags.contains(.option)
                    let stageAll = self.window?.toolbar?.items.first { $0.itemIdentifier == RepositoryToolbar.stageAll }

                    if let stageAll {
                        self.updateStageAllItem(stageAll, option: option)
                    }

                    self.updateQuickToolbarItems(option: option)
                }

                return self?.handleWorkingCopyKey(event) ?? false
            }

            return handled ? nil : event
        }
    }

    /// 工作区处于前台时处理按键：回车键提交或继续进行中的操作；返回事件是否已处理。
    private func handleWorkingCopyKey(_ event: NSEvent) -> Bool {
        guard
            event.type == .keyDown,
            NSApp.keyWindow === window, !showsManager,
            session.activeView == .workingCopy,
            window?.attachedSheet == nil
        else { return false }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])

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
            !(session.context?.progress?.stopsForEdit ?? false),
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

        let detail = makeDetailView()

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

        // 首次使用或恢复失败后储藏与 Reflog 的列表同样宽 320 pt，此后交给 NSSplitView 的 autosave 恢复。
        if
            [.stashes, .reflog].contains(session.activeView), let split = detail as? NSSplitViewController,
            let name = split.splitView.autosaveName,
            UserDefaults.standard.object(forKey: "NSSplitView Subview Frames " + name) == nil
        {
            split.splitView.setPosition(320, ofDividerAt: 0)
        }

        didChangeView()
    }

    /// 当前主视图的内容：工作区、历史与文件历史记下各自的内层分栏，其余视图清掉它们。
    private func makeDetailView() -> NSViewController {
        switch session.activeView {
        case .workingCopy:
            historySplit = nil
            let split = makeWorkingCopySplit()
            workingCopySplit = split
            return split

        case .history:
            workingCopySplit = nil
            let split = makeHistorySplit()
            historySplit = split
            return split

        case .stashes:
            workingCopySplit = nil
            historySplit = nil
            return makeStashSplit()

        case .reflog:
            workingCopySplit = nil
            historySplit = nil
            return makeReflogSplit()

        case .fileHistory:
            workingCopySplit = nil
            let split = makeFileHistorySplit()
            historySplit = split
            return split

        case .fileContent:
            workingCopySplit = nil
            historySplit = nil
            return makeFileContentView()

        case .remote:
            workingCopySplit = nil
            historySplit = nil
            return makeRemoteDetailView()

        case .branchesReview:
            workingCopySplit = nil
            historySplit = nil
            return makeBranchesReviewSplit()

        case .pullRequests:
            workingCopySplit = nil
            historySplit = nil
            return makePullRequestsSplit()

        case .settings:
            workingCopySplit = nil
            historySplit = nil
            return makeRepositorySettingsView()

        case .submodule:
            workingCopySplit = nil
            historySplit = nil
            return makeSubmoduleDetailView()

        case .worktree:
            workingCopySplit = nil
            historySplit = nil
            return makeWorktreeDetailView()
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

        // 换了外层分栏后，工具栏的侧边栏分隔符改跟新的分隔线
        trackSidebar(of: split)
    }
}
