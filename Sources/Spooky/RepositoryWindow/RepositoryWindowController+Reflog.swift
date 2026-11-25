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

    /// Reflog 的记录列表与提交详情分栏，尺寸按 Reflog 视图单独保存；详情复用历史的提交详情。
    func makeReflogSplit() -> NSSplitViewController {
        let split = makeInnerSplit(name: "Spooky.Reflog")

        let list = NSHostingController(
            rootView: ReflogListView(session: session) { [weak self] in
                self?.presentRepositoryAction(RepositoryActionRequest(kind: .create, reference: $0))
            }
        )

        // 列表没有最小宽：宿主不把内容的最小尺寸交给分栏，内容列表的分栏项默认的最窄 200 改为 0
        list.sizingOptions = []
        let listItem = NSSplitViewItem(contentListWithViewController: list)
        listItem.minimumThickness = listMinimumThickness(0)
        listItem.holdingPriority = .init(475)
        listItem.canCollapse = false

        // 列表不延伸到工具栏下面，免得列表的底色与分隔线穿过工具栏上的项
        listItem.allowsFullHeightLayout = false

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
