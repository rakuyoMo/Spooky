import AppKit
import SpookyKit
import SwiftUI

// MARK: - Branches Review

extension RepositoryWindowController {
    /// 接上分支整理、自动归档与变基对话框的回调：对话框以 sheet 呈现，引用读完后检查是否该自动归档。
    func configureBranchesReview() {
        session.branchesReview.onArchiveRequest = { [weak self] automatic, candidates in
            self?.presentArchiveDialog(automatic: automatic, candidates: candidates)
        }

        session.history.onReferencesLoaded = { [weak self] in
            self?.offerAutoArchiveIfDue()
        }

        // 分支右键的 Rebase On “父分支”… 打开预选了父分支的变基对话框
        session.onRebaseRequest = { [weak self] in
            self?.presentSyncDialog(.rebase, source: $0)
        }
    }

    /// Compare Branches 的开关，所有窗口共用；历史列表头的按钮是同一个偏好。
    @objc
    func toggleCompareBranches() {
        let key = RepositoryHistoryState.comparesBranchesKey
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
    }

    /// 分支整理与 Compare Branches 的可用性，菜单项同时标出开关状态；动作不属于本组时为 nil。
    func branchesReviewAvailability(of item: any NSValidatedUserInterfaceItem) -> Bool? {
        switch item.action {
        case #selector(showBranchesReview):
            return session.repository != nil

        case #selector(toggleCompareBranches):
            (item as? NSMenuItem)?.state = session.history.comparesBranches ? .on : .off
            return !showsManager && session.activeView == .history && session.history.selectedLocalBranch != nil

        default:
            return nil
        }
    }

    /// 分支整理的列表与详情分栏，列表首次宽 420 pt，此后按分支整理单独保存宽度。
    func makeBranchesReviewSplit() -> NSSplitViewController {
        let split = NSSplitViewController()
        split.splitView.isVertical = true
        split.splitView.dividerStyle = .thin
        Self.setAutosaveName("Spooky.BranchesReview", of: split)

        let list = NSHostingController(
            rootView: BranchesReviewListView(session: session) { [weak self] in
                self?.presentRepositoryAction($0)
            }
        )
        list.sizingOptions = [.minSize]

        let listItem = NSSplitViewItem(contentListWithViewController: list)
        listItem.minimumThickness = 300
        listItem.holdingPriority = .init(475)
        listItem.canCollapse = false

        let detail = NSHostingController(rootView: BranchesReviewDetailView(session: session))
        detail.sizingOptions = [.minSize]

        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.holdingPriority = .init(470)
        detailItem.canCollapse = false

        split.addSplitViewItem(listItem)
        split.addSplitViewItem(detailItem)

        if UserDefaults.standard.object(forKey: "NSSplitView Subview Frames Spooky.BranchesReview") == nil {
            split.splitView.setPosition(420, ofDividerAt: 0)
        }

        return split
    }

    /// 批量归档对话框；自动归档时是待处理分支的确认。
    func presentArchiveDialog(automatic: Bool, candidates: [RepositoryReference]) {
        guard session.canWrite, let window, window.attachedSheet == nil else {
            return
        }

        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed
        let dialog = ArchiveBranchesDialog(session: session, automatic: automatic, candidates: candidates) { [weak sheet] in
            if let sheet {
                window.endSheet(sheet)
            }
        }

        sheet.contentViewController = NSHostingController(rootView: dialog)
        window.beginSheet(sheet)
    }

    /// 自动归档开着、距上次检查满一天且窗口在前台时，列出待归档的分支请用户确认；没有待归档的分支时只记下检查时刻。
    private func offerAutoArchiveIfDue() {
        guard
            SidebarPreferences.isOn(SidebarPreferences.autoArchiveKey),
            let repository = session.repository,
            session.history.snapshot != nil,
            window?.isKeyWindow ?? false,
            window?.attachedSheet == nil,
            session.canWrite,
            BranchArchiving.isDue(for: repository)
        else {
            return
        }

        BranchArchiving.recordCheck(for: repository)

        let candidates = session.archiveCandidates(automatic: true)

        if !candidates.isEmpty {
            presentArchiveDialog(automatic: true, candidates: candidates)
        }
    }
}
