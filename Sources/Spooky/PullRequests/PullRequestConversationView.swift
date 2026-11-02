import AppKit
import SpookyKit
import SwiftUI

// MARK: - PullRequestConversationView

/// Conversation 段：头部、描述、评论与提交组排成一列，末尾是发表评论。
///
/// 原生大纲列表提供讨论的选中色、⌘ / ⇧ 多选、提交组的折叠、右键菜单、双击与回车；
/// 选择与折叠按请求记在内存里，切换请求再回来或重新读取后恢复。
struct PullRequestConversationView: NSViewRepresentable {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 显示的请求。
    let request: PullRequest

    /// 请求的评论。
    let comments: [PullRequestComment]

    /// 比较范围里的提交，按拓扑序从新到旧；还没读完、需要获取或比较没打开时为 nil。
    let commits: [HistoryCommit]?

    /// 有接口客户端，可以发表评论。
    let canComment: Bool

    /// 建立列表与会话之间的桥接。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 单列的大纲列表：没有表头，底色是列表的底色，可以多选。
    func makeNSView(context: Context) -> NSScrollView {
        let outline = ConversationOutlineView()
        outline.style = .plain
        outline.headerView = nil
        outline.intercellSpacing = .zero
        outline.backgroundColor = AppPalette.nsColor("general_background_color")
        outline.allowsMultipleSelection = true
        outline.indentationPerLevel = ConversationOutlineView.indentation
        outline.autoresizesOutlineColumn = false
        outline.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outline.setAccessibilityIdentifier("pull-request-conversation")

        let column = NSTableColumn(identifier: .init("conversation"))
        column.resizingMask = .autoresizingMask
        outline.addTableColumn(column)
        outline.outlineTableColumn = column

        // 双击与回车走同一个动作，菜单在打开时按作用的行现拼
        outline.delegate = context.coordinator
        outline.dataSource = context.coordinator
        outline.target = context.coordinator
        outline.doubleAction = #selector(Coordinator.doubleClicked(_:))
        outline.openSelection = { context.coordinator.openSelection() }

        // 菜单项按可用条件启用或停用，不交给响应链自动判断
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = context.coordinator
        outline.menu = menu
        context.coordinator.outline = outline

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.backgroundColor = outline.backgroundColor
        scroll.documentView = outline
        return scroll
    }

    /// 输入变化时由桥接器决定是否重建行。
    func updateNSView(_: NSScrollView, context: Context) {
        context.coordinator.update(self)
    }
}

// MARK: PullRequestConversationView.ConversationOutlineView

extension PullRequestConversationView {
    /// 每层缩进 16：展开三角在本层的 16 里，单元格从左缘 16 × (层级 + 1) 起；回车与双击一样打开作用的行。
    final class ConversationOutlineView: NSOutlineView {
        /// 每层的缩进，也是展开三角所占的宽度。
        static let indentation: CGFloat = 16

        /// 回车打开所选的行。
        var openSelection: (() -> Void)?

        /// 回车（keyCode 36）交给打开动作，其它按键交给系统列表。
        override func keyDown(with event: NSEvent) {
            guard event.keyCode == 36 else {
                super.keyDown(with: event)

                return
            }

            openSelection?()
        }

        /// 展开三角在本层的 16 里。
        override func frameOfOutlineCell(atRow row: Int) -> NSRect {
            var frame = super.frameOfOutlineCell(atRow: row)

            guard !frame.isEmpty else {
                return frame
            }

            frame.origin.x = Self.indentation * CGFloat(level(forRow: row))
            frame.size.width = Self.indentation
            return frame
        }

        /// 单元格从左缘 16 × (层级 + 1) 起，右缘不变。
        override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {
            var frame = super.frameOfCell(atColumn: column, row: row)
            let x = Self.indentation * CGFloat(level(forRow: row) + 1)

            frame.size.width = max(0, frame.maxX - x)
            frame.origin.x = x
            return frame
        }
    }
}
