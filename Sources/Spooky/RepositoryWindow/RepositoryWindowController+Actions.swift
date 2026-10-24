import AppKit
import SpookyKit
import SwiftUI

extension RepositoryWindowController {
    /// 主菜单和工具栏使用当前仓库，管理页使用当前选中的记录。
    @objc
    func openInTerminal() {
        guard let location = showsManager ? session.selectedRecentLocation : session.repository else { return }
        openLocationInTerminal(location)
    }

    /// 右键菜单可直接指定记录，错误显示在发起操作的窗口。
    func openLocationInTerminal(_ location: RepositoryLocation) {
        Task { [weak self] in
            do { try await TerminalLauncher.open(location) }
            catch { self?.showFailure(AppFailure(error: error, opening: false, location: location)) }
        }
    }

    /// Finder 只能显示本机路径。
    @objc
    func revealInFinder() {
        guard
            let location = showsManager ? session.selectedRecentLocation : session.repository,
            let url = location.localURL
        else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 服务器路径带主机前缀，避免复制后误认为本机目录。
    @objc
    func copyPath() {
        guard let location = showsManager ? session.selectedRecentLocation : session.repository else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(location.displayPath, forType: .string)
    }

    /// 菜单和工具栏共用刷新入口。
    @objc
    func refreshRepository() {
        guard !showsManager else {
            return
        }

        session.refresh(full: true)
    }

    /// 提交菜单与工具栏聚焦已有的工作区标题框。
    @objc
    func composeCommit() {
        if session.activeView != .workingCopy { showWorkingCopy() }
        session.commitFocusRequest += 1
    }

    /// 全部暂存的工具栏入口支持 ⌥ 切换到全部取消暂存。
    @objc
    func stageAll() {
        let unstage = NSEvent.modifierFlags.contains(.option)
            && (session.status?.entries.contains(where: \.hasStagedChanges) ?? false)
        session.stageAll(staged: !unstage)
    }

    /// 主菜单的独立取消暂存动作。
    @objc
    func unstageAll() { session.stageAll(staged: false) }

    /// 选中文件的菜单暂存入口。
    @objc
    func stageSelected() { session.stage(session.selectedEntries, staged: true) }

    /// 选中文件的菜单取消暂存入口。
    @objc
    func unstageSelected() { session.stage(session.selectedEntries, staged: false) }

    /// 主菜单和文件右键共用丢弃确认。
    @objc
    func discardSelected() { session.discard(session.selectedEntries) }

    /// 全部丢弃只覆盖当前状态中的改动。
    @objc
    func discardAll() { session.discard(session.status?.entries ?? []) }

    /// 新建分支默认从当前选中提交或 HEAD 开始。
    @objc
    func createBranch() {
        let revision = session.activeView == .history ? session.history.selectedCommit?.id : nil
        presentRepositoryAction(RepositoryActionRequest(kind: .create, reference: revision))
    }

    /// 检出表单只列出本地分支。
    @objc
    func checkoutBranch() { presentRepositoryAction(RepositoryActionRequest(kind: .checkout)) }

    /// 获取入口收集远端与清理选项。
    @objc
    func fetch() { presentRepositoryAction(RepositoryActionRequest(kind: .fetch)) }

    /// 全部获取使用持久化的清理与标签选项。
    @objc
    func fetchAll() {
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
    @objc
    func pull() { presentRepositoryAction(RepositoryActionRequest(kind: .pull)) }

    /// 推送表单明确目标远端和目标分支。
    @objc
    func push() { presentRepositoryAction(RepositoryActionRequest(kind: .push)) }

    /// 发布表单允许首次设置 upstream。
    @objc
    func publishBranch() { presentRepositoryAction(RepositoryActionRequest(kind: .publish)) }

    /// 合并表单在执行前显示 merge-tree 预览。
    @objc
    func merge() { presentRepositoryAction(RepositoryActionRequest(kind: .merge)) }

    /// 提交图开关同时作用于列表头和主菜单。
    @objc
    func toggleHistoryGraph() {
        UserDefaults.standard.set(
            !UserDefaults.standard.bool(forKey: "historyShowGraph"),
            forKey: "historyShowGraph"
        )
    }

    /// 小号行采用 24 pt 高度。
    @objc
    func smallHistoryRows() { UserDefaults.standard.set(true, forKey: "historySmallRows") }

    /// 中号行采用 46 pt 高度。
    @objc
    func mediumHistoryRows() { UserDefaults.standard.set(false, forKey: "historySmallRows") }

    /// 变更集展开快捷键复用文件懒加载。
    @objc
    func expandChanges() { session.history.expandAll(true) }

    /// 折叠不丢弃已取得的只读补丁。
    @objc
    func collapseChanges() { session.history.expandAll(false) }

    /// 自动展开阈值立即更新当前提交的文件展示。
    @objc
    func setAutoExpand(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "historyAutoExpand")
        session.history.expandAll(sender.tag > 0 && session.history.changes.count <= sender.tag)
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
                    // 只有写操作真正开始才关闭表单；仓库忙碌或断线时保留未发送的参数。
                    // 检出、拉取与合并被本地改动挡住时按设置询问是否先储藏
                    guard
                        let self, let sheet, session.repository == repository,
                        session.performGit(
                            action,
                            title: title,
                            offersAutoStash: [.checkout, .pull, .merge].contains(request.kind)
                        )
                    else { return false }

                    window.endSheet(sheet)
                    return true
                }
            )
        )
        window.beginSheet(sheet)
    }

    /// 仓库动作按当前视图与加载状态启用；菜单、工具栏与右键菜单共用会话的可用性规则。
    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        let repositoryView = !showsManager && session.repository != nil

        // 分支与同步、工作区文件、历史显示、储藏与 Diff 各组动作分别判断，组外的窗口级动作在下方判断。
        let enabled = branchAndSyncAvailability(of: item.action, repositoryView: repositoryView)
            ?? workingCopyAvailability(of: item.action, repositoryView: repositoryView)
            ?? historyDisplayAvailability(of: item)
            ?? stashAvailability(of: item.action, repositoryView: repositoryView)
            ?? diffAvailability(of: item)
            ?? workingCopyFileAvailability(of: item)
            ?? referenceAvailability(of: item.action, repositoryView: repositoryView)

        if let enabled {
            return enabled
        }

        switch item.action {
        case #selector(showHeadBranch):
            return session.repository != nil

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

        case #selector(focusSearch):
            return repositoryView && session.activeView.supportsSearch

        default:
            return true
        }
    }

    /// 分支与同步动作的可用性；动作不属于本组时为 nil。
    private func branchAndSyncAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(fetch), #selector(fetchAll):
            repositoryView && session.canFetch

        case #selector(pull):
            repositoryView && session.canPull

        case #selector(push):
            repositoryView && session.canPush

        case #selector(publishBranch):
            repositoryView && session.canPublish

        case #selector(merge):
            repositoryView && session.canMerge

        case #selector(createBranch):
            repositoryView && session.canCreateBranch

        case #selector(checkoutBranch):
            repositoryView && session.canCheckout

        default:
            nil
        }
    }

    /// 工作区文件动作的可用性，按住 ⌥ 时全部暂存按全部取消暂存判断；动作不属于本组时为 nil。
    private func workingCopyAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(composeCommit):
            return repositoryView

        case #selector(stageAll):
            let entries = session.status?.entries ?? []
            let unstage = NSEvent.modifierFlags.contains(.option) && entries.contains(where: \.hasStagedChanges)
            return repositoryView && (unstage ? session.canUnstage(entries) : session.canStage(entries))

        case #selector(unstageAll):
            return repositoryView && session.canUnstage(session.status?.entries ?? [])

        case #selector(stageSelected):
            return repositoryView && session.canStage(session.selectedEntries)

        case #selector(unstageSelected):
            return repositoryView && session.canUnstage(session.selectedEntries)

        case #selector(discardSelected):
            return repositoryView && session.canDiscard(session.selectedEntries)

        case #selector(discardAll):
            return repositoryView && session.canDiscard(session.status?.entries ?? [])

        default:
            return nil
        }
    }

    /// 历史显示选项的可用性，菜单项同时标出当前选中的选项；动作不属于本组时为 nil。
    private func historyDisplayAvailability(of item: any NSValidatedUserInterfaceItem) -> Bool? {
        switch item.action {
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

        default:
            return nil
        }
    }
}
