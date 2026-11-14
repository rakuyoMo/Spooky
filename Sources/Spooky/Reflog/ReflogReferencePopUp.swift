import AppKit
import SwiftUI

// MARK: - ReflogReferencePopUp

/// Reflog 的引用弹出按钮：工具栏样式、没有边框、二级文字色。
///
/// 菜单顶部是过滤框，所看的引用排在最前，其后是分隔线与其余引用；没换过引用时就是 HEAD、分隔线与本地分支。
struct ReflogReferencePopUp: NSViewRepresentable {
    /// 可看的引用：HEAD 在前，其后是本地分支的完整引用名。
    let references: [String]

    /// 所看的引用。
    let current: String

    /// 选了另一项引用，参数是它的完整引用名。
    let select: (String) -> Void

    /// 菜单与过滤框的状态。
    func makeCoordinator() -> ReferenceFilterMenu {
        ReferenceFilterMenu()
    }

    /// 无边框的工具栏样式弹出按钮，13 pt 字。
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.bezelStyle = .accessoryBar
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.font = .systemFont(ofSize: 13)
        button.menu = context.coordinator.menu
        button.setAccessibilityLabel(AppLocalization.text("reflog.ref"))

        return button
    }

    /// 引用或所看的引用变了才重建菜单，再选中所看的引用。
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.select = select

        context.coordinator.rebuild(
            entries: references.map { ReferenceFilterMenu.Entry(id: $0, title: ReflogListView.name(of: $0)) },
            current: ReferenceFilterMenu.Entry(id: current, title: ReflogListView.name(of: current)),
            emptyTitle: ""
        )

        button.select(context.coordinator.currentItem)
    }
}
