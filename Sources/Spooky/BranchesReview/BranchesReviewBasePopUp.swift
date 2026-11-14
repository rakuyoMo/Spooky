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
    func makeCoordinator() -> BranchesReviewBaseMenu {
        BranchesReviewBaseMenu()
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
        context.coordinator.rebuild(branches: branches, base: base)

        button.select(context.coordinator.baseItem)
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

// MARK: - BranchesReviewBaseMenu

/// 基准分支的菜单：顶部是过滤框，接着是当前基准（打勾）、分隔线，再是其它本地分支；输入文字时只留名字含这段文字的分支。
@MainActor
final class BranchesReviewBaseMenu: NSObject {
    /// 弹出按钮用的菜单。
    let menu = NSMenu()

    /// 当前基准的菜单项；没有基准时是写着 No Branches 的占位项。
    private(set) var baseItem: NSMenuItem? = nil

    /// 选了另一个分支作基准。
    var select: (String) -> Void = { _ in }

    /// 菜单顶部的过滤框。
    let field = NSSearchField()

    /// 上次建菜单时的分支与基准，没变时不重建。
    private var built: [String]? = nil

    /// 建出带过滤框的空菜单。
    override init() {
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false

        field.delegate = self
        field.placeholderString = AppLocalization.text("sidebar.filter")
        field.sendsSearchStringImmediately = true
    }

    /// 按分支与基准重建菜单；与上次相同时不动。
    ///
    /// - Parameters:
    ///   - branches: 全部本地分支，按显示顺序。
    ///   - base: 当前基准。
    func rebuild(branches: [RepositoryReference], base: RepositoryReference?) {
        let key = [base?.id ?? ""] + branches.map(\.id)

        guard key != built else {
            return
        }

        built = key
        menu.removeAllItems()
        menu.addItem(fieldItem())

        // 当前基准在过滤框下面，与其它分支用分隔线隔开
        if let base {
            baseItem = branchItem(base)
        } else {
            baseItem = NSMenuItem(title: AppLocalization.text("review.noBase"), action: nil, keyEquivalent: "")
            baseItem?.isEnabled = false
        }

        if let baseItem {
            menu.addItem(baseItem)
        }

        menu.addItem(.separator())

        for branch in branches where branch.id != base?.id {
            menu.addItem(branchItem(branch))
        }
    }

    /// 只留名字含这段文字的分支，不分大小写；文字为空时全部显示，有文字时分隔线隐藏。
    ///
    /// - Parameter text: 过滤框里的文字。
    func filter(_ text: String) {
        for item in menu.items where item.view == nil {
            if item.isSeparatorItem {
                item.isHidden = !text.isEmpty
            } else {
                item.isHidden = !text.isEmpty && !item.title.localizedCaseInsensitiveContains(text)
            }
        }
    }

    /// 选中一个分支作基准。
    @objc
    private func choose(_ item: NSMenuItem) {
        guard let id = item.representedObject as? String else {
            return
        }

        select(id)
    }
}

// MARK: NSMenuDelegate

extension BranchesReviewBaseMenu: NSMenuDelegate {
    /// 打开菜单时让过滤框拿到键盘输入；菜单跟踪期间只跑事件跟踪模式。
    func menuWillOpen(_: NSMenu) {
        RunLoop.main.perform(inModes: [.eventTracking]) { [field] in
            field.window?.makeFirstResponder(field)
        }
    }

    /// 关闭菜单后清空过滤文字，下次打开时列出全部分支。
    func menuDidClose(_: NSMenu) {
        field.stringValue = ""
        filter("")
    }
}

// MARK: NSSearchFieldDelegate

extension BranchesReviewBaseMenu: NSSearchFieldDelegate {
    /// 每输入一个字就重新过滤。
    func controlTextDidChange(_: Notification) {
        filter(field.stringValue)
    }
}

// MARK: - Private

extension BranchesReviewBaseMenu {
    /// 放过滤框的菜单项，左右留出与菜单文字对齐的边距。
    private func fieldItem() -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        field.frame = NSRect(x: 12, y: 4, width: 196, height: 22)
        field.autoresizingMask = [.width]
        container.addSubview(field)

        let item = NSMenuItem()
        item.view = container

        return item
    }

    /// 一个分支的菜单项。
    private func branchItem(_ branch: RepositoryReference) -> NSMenuItem {
        let item = NSMenuItem(title: branch.name, action: #selector(choose(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = branch.id

        return item
    }
}
