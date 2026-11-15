import AppKit
import SpookyKit
import SwiftUI

// MARK: - BranchesReviewBasePopUp

/// 基准分支的弹出按钮，带上下箭头；宽度不够时先截断按钮上的分支名，让表头的说明与右侧两个按钮保持完整。
struct BranchesReviewBasePopUp: NSViewRepresentable {
    /// 全部本地分支，按显示顺序。
    let branches: [RepositoryReference]

    /// 当前基准；没有时按钮写 No Branches。
    let base: RepositoryReference?

    /// 选了另一个分支作基准，参数是它的完整引用名。
    let select: (String) -> Void

    /// 菜单与过滤框的状态。
    func makeCoordinator() -> ReferenceFilterMenu {
        ReferenceFilterMenu()
    }

    /// 无边框的弹出按钮，13 pt 字，标题过长时截断。
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.isBordered = false
        button.font = .systemFont(ofSize: 13)
        button.cell?.lineBreakMode = .byTruncatingMiddle
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.menu = context.coordinator.menu
        button.setAccessibilityLabel(AppLocalization.text("review.compareTo"))

        return button
    }

    /// 分支或基准变了才重建菜单，再选中当前基准。
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.select = select
        context.coordinator.rebuild(
            entries: branches.map { ReferenceFilterMenu.Entry(id: $0.id, title: $0.name) },
            current: base.map { ReferenceFilterMenu.Entry(id: $0.id, title: $0.name) },
            emptyTitle: AppLocalization.text("review.noBase")
        )

        button.select(context.coordinator.currentItem)
        button.toolTip = base?.name
    }

    /// 宽度不超过提议的宽度，放不下时由按钮截断标题。
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context _: Context) -> CGSize? {
        let fitting = nsView.intrinsicContentSize

        guard let width = proposal.width else {
            return fitting
        }

        return CGSize(width: min(fitting.width, width), height: fitting.height)
    }
}
