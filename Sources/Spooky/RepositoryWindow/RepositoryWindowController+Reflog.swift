import AppKit
import SwiftUI

// MARK: - Reflog

extension RepositoryWindowController {
    /// 切换到 Reflog，⌘6 与侧边栏使用相同状态；正在显示仓库管理时回到这个仓库。
    @objc
    func showReflog() {
        guard let repository = session.repository else {
            return
        }

        session.activeView = .reflog

        if showsManager {
            display(repository)
        } else {
            session.onActiveViewChange?()
        }
    }

    /// Reflog 的记录列表与提交详情分栏，宽度按 Reflog 视图单独保存；详情复用历史的提交详情。
    func makeReflogSplit() -> NSSplitViewController {
        let split = NSSplitViewController()
        split.splitView.isVertical = true
        split.splitView.dividerStyle = .thin
        Self.setAutosaveName("Spooky.Reflog", of: split)

        let list = NSHostingController(
            rootView: ReflogListView(session: session) { [weak self] in
                self?.presentRepositoryAction(RepositoryActionRequest(kind: .create, reference: $0))
            }
        )
        list.sizingOptions = [.minSize]
        let listItem = NSSplitViewItem(contentListWithViewController: list)
        listItem.minimumThickness = 300
        listItem.holdingPriority = .init(475)
        listItem.canCollapse = false

        let detail = NSHostingController(rootView: CommitDetailView(history: session.reflog.detail, session: session))
        detail.sizingOptions = [.minSize]
        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.holdingPriority = .init(470)
        detailItem.canCollapse = false

        split.addSplitViewItem(listItem)
        split.addSplitViewItem(detailItem)
        return split
    }
}
