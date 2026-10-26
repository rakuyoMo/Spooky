import AppKit
import SpookyKit

// MARK: - Navigation

extension RepositoryWindowController {
    /// 窗口恢复的状态里保存视图引用的键。
    static let viewReferenceKey = "viewReference"

    /// 隐藏窗口标题的偏好键，所有仓库窗口共用。
    static let hidesTitleKey = "hideWindowTitle"

    /// 窗口当前显示的视图：仓库管理，或仓库的主视图与选择。
    var currentReference: ViewReference {
        guard !showsManager, let repository = session.repository else {
            return .repositories
        }

        return .repository(repository, currentDestination)
    }

    /// 视图换过之后：记进后退 / 前进记录，刷新工具栏，按偏好隐藏标题，并让窗口恢复重新保存所在的视图。
    func didChangeView() {
        updateToolbarItems()
        applyTitleVisibility()

        // 按引用显示视图的中途会经过别的视图，由显示完成后统一记录
        guard !isApplyingReference else {
            return
        }

        recordNavigation()
    }

    /// View › Back 与工具栏的后退：回到上一个视图。
    @objc
    func navigateBack() {
        guard let reference = navigation.goBack() else {
            NSSound.beep()
            return
        }

        show(reference)
    }

    /// View › Forward 与工具栏的前进：回到下一个视图。
    @objc
    func navigateForward() {
        guard let reference = navigation.goForward() else {
            NSSound.beep()
            return
        }

        show(reference)
    }

    /// 在本窗口显示一个视图引用：仓库管理直接显示；正在显示的仓库只切换视图；
    /// 其它仓库经正常的打开流程在本窗口打开，服务器仓库同样先连接并体检，失败时显示错误。
    func show(_ reference: ViewReference) {
        switch reference {
        case .repositories:
            showRepositories()

        case .repository(let location, let destination):
            guard session.repository != location else {
                display(location, showing: destination)
                return
            }

            coordinator?.openRepository(
                at: location,
                from: self,
                inNewWindow: false,
                showing: destination,
                staysInSource: true
            )
        }
    }

    /// 显示已验证的仓库并切到指定视图；中途经过的视图不记进后退 / 前进记录，只记最终到达的视图。
    func display(_ repository: RepositoryLocation, showing destination: RepositoryDestination) {
        isApplyingReference = true
        display(repository)
        apply(destination)
        isApplyingReference = false

        recordNavigation()
    }

    /// 窗口恢复保存当前视图引用；重新启动后由 `RepositoryWindowRestoration` 读回并重新打开。
    func window(_: NSWindow, willEncodeRestorableState state: NSCoder) {
        state.encode(currentReference.string, forKey: Self.viewReferenceKey)
    }

    /// 按偏好显示或隐藏窗口标题；隐藏时一并去掉标题旁的仓库目录图标。
    func applyTitleVisibility() {
        let hidden = UserDefaults.standard.bool(forKey: Self.hidesTitleKey)
        window?.titleVisibility = hidden ? .hidden : .visible
        window?.representedURL = hidden || showsManager ? nil : session.repository?.localURL
    }

    /// View › Hide Window Title：切换偏好，所有仓库窗口一起生效。
    @objc
    func toggleWindowTitle() {
        let hidden = UserDefaults.standard.bool(forKey: Self.hidesTitleKey)
        UserDefaults.standard.set(!hidden, forKey: Self.hidesTitleKey)

        // 发起的窗口先生效，再同步其它仓库窗口
        applyTitleVisibility()

        for controller in coordinator?.windows ?? [] where controller !== self {
            controller.applyTitleVisibility()
        }
    }

    /// File › New Tab 与标签栏的 “+”：在本窗口所在的标签组末尾加一个显示仓库管理的标签。
    override func newWindowForTab(_: Any?) {
        coordinator?.openTab(after: self)
    }

    /// 后退、前进、标签页与窗口标题的可用性，菜单项同时换上当前状态的标题；动作不属于本组时为 nil。
    func navigationAvailability(of item: any NSValidatedUserInterfaceItem) -> Bool? {
        switch item.action {
        case #selector(navigateBack):
            return navigation.canGoBack

        case #selector(navigateForward):
            return navigation.canGoForward

        case #selector(newWindowForTab(_:)):
            // 系统不支持窗口标签页时隐藏这一项
            (item as? NSMenuItem)?.isHidden = !NSWindow.allowsAutomaticWindowTabbing
            return NSWindow.allowsAutomaticWindowTabbing

        case #selector(toggleWindowTitle):
            let hidden = UserDefaults.standard.bool(forKey: Self.hidesTitleKey)
            (item as? NSMenuItem)?.title = AppLocalization.text(hidden ? "menu.showWindowTitle" : "menu.hideWindowTitle")
            return true

        default:
            return nil
        }
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 仓库里当前的主视图与选择；文件、远端、子模块与工作树视图缺少所看的对象时按工作区记。
    private var currentDestination: RepositoryDestination {
        let history = session.history

        switch session.activeView {
        case .workingCopy:
            return .workingCopy

        case .history:
            // 整页详情记所看的提交，列表记侧边栏选中的引用
            if history.showsCommitPage, history.selectedIDs.count == 1, let commit = history.selectedIDs.first {
                return .commit(commit)
            }

            return .history(references: history.selectedReferences.sorted())

        case .stashes:
            return .stashes

        case .reflog:
            return .reflog

        case .pullRequests:
            return .pullRequests

        case .branchesReview:
            return .branchesReview

        case .settings:
            return .settings

        case .remote:
            return session.selectedRemote.map { .remote($0) } ?? .workingCopy

        case .submodule:
            return session.submodules.selectedPath.map { .submodule(path: $0) } ?? .workingCopy

        case .worktree:
            return session.worktrees.selectedPath.map { .worktree(path: $0) } ?? .workingCopy

        case .fileHistory:
            return session.fileHistory.path.map { .fileHistory(path: $0) } ?? .workingCopy

        case .fileContent:
            let content = session.fileContent
            return content.path.map { .file(path: $0, revision: content.revision, mode: content.mode) } ?? .workingCopy
        }
    }

    /// 记下当前视图，刷新后退与前进按钮，并让窗口恢复重新保存所在的视图。
    private func recordNavigation() {
        navigation.record(currentReference)
        window?.toolbar?.validateVisibleItems()
        window?.invalidateRestorableState()
    }

    /// 在已显示的仓库里切到指定视图；引用、文件、远端、子模块或工作树已不存在时，由各视图按自己的规则显示空状态或回到工作区。
    private func apply(_ destination: RepositoryDestination) {
        switch destination {
        case .workingCopy:
            showWorkingCopy()

        case .history(let references):
            showHistory()
            session.history.selectedReferences = Set(references)

        case .commit(let commit):
            // 回到全部历史并选中这个提交，再换成整页详情；提交不在已加载的分页里时继续加载去找
            showHistory()
            session.history.showsCommitPage = true
            session.history.locate(commit)
            session.onActiveViewChange?()

        case .stashes:
            showStashes()

        case .reflog:
            showReflog()

        case .pullRequests:
            showPullRequests()

        case .branchesReview:
            showBranchesReview()

        case .settings:
            showRepositorySettings()

        case .remote(let name):
            session.showRemote(name)

        case .submodule(let path):
            session.showSubmodule(path)

        case .worktree(let path):
            session.showWorktree(path)

        case .fileHistory(let path):
            session.showFileHistory(path)

        case .file(let path, let revision, let mode):
            session.showFile(path, at: revision, mode: mode)
        }
    }
}
