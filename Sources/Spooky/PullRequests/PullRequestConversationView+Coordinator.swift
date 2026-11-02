import AppKit
import SpookyKit
import SwiftUI

// MARK: - Nested Types

extension PullRequestConversationView {
    /// 大纲列表的一行；提交组的子行是组里的提交与组末的空白。
    final class Node: NSObject {
        /// 这一行的内容。
        let item: PullRequestConversationItem

        /// 子行。
        let children: [Node]

        /// 创建一行；只有提交组带子行。
        init(_ item: PullRequestConversationItem, children: [Node] = []) {
            self.item = item
            self.children = children
        }
    }

    /// 决定是否重建行的全部输入。
    struct Snapshot: Equatable {
        /// 显示的请求。
        let request: PullRequest

        /// 请求的评论。
        let comments: [PullRequestComment]

        /// 列出的提交的哈希；还没读完时为 nil。
        let commits: [String]?

        /// 可以发表评论。
        let canComment: Bool
    }
}

// MARK: - PullRequestConversationView.Coordinator

extension PullRequestConversationView {
    /// 把列表的事件交给会话，按请求记住选择与折叠。
    @MainActor
    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate {
        /// 当前 SwiftUI 输入。
        var parent: PullRequestConversationView

        /// 原生列表的弱引用。
        weak var outline: NSOutlineView?

        /// 顶层的行。
        private var roots: [Node] = []

        /// 上次重建行时的输入。
        private var snapshot: Snapshot? = nil

        /// 头部、描述与评论量出的行高。
        private var heights: [PullRequestConversationItem.Key: CGFloat] = [:]

        /// 量行高时的列宽，列宽变化后重新量。
        private var measuredWidth: CGFloat = 0

        /// 量行高用的 SwiftUI 宿主，第一次量时创建。
        private var sizing: NSHostingController<PullRequestConversationTextRow>? = nil

        /// 程序重建与恢复期间不改写选择与折叠的记忆。
        private var updating = false

        /// 建立桥接。
        init(_ parent: PullRequestConversationView) {
            self.parent = parent
        }

        /// 输入变化时重建行，再恢复这个请求的折叠与选择。
        func update(_ parent: PullRequestConversationView) {
            self.parent = parent

            guard let outline else { return }

            let snapshot = Snapshot(
                request: parent.request,
                comments: parent.comments,
                commits: parent.commits?.map(\.id),
                canComment: parent.canComment
            )

            guard snapshot != self.snapshot else { return }

            self.snapshot = snapshot

            // 重建期间列表发出的选择与折叠通知不写进记忆
            updating = true
            defer { updating = false }

            heights = [:]
            roots = Self.nodes(comments: parent.comments, commits: parent.commits ?? [])
            outline.reloadData()

            // 换上新行后按这个请求的记忆恢复折叠与选择
            restoreExpansion(in: outline)
            restoreSelection(in: outline)
        }

        /// 顶层的行数或提交组里的子行数。
        func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            (item as? Node)?.children.count ?? roots.count
        }

        /// 按索引取出行。
        func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            ((item as? Node)?.children ?? roots)[index]
        }

        /// 只有提交组能展开。
        func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
            !((item as? Node)?.children.isEmpty ?? true)
        }

        /// 头部、描述与评论按列宽量出；提交组 34，提交 24，组末的空白 8，发表评论 62。
        func outlineView(_: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
            guard let node = item as? Node else { return 1 }

            switch node.item {
            case .header, .description, .comment: return measuredHeight(of: node.item)
            case .group: return 34
            case .commit: return 24
            case .spacer: return 8
            case .addComment: return 62
            }
        }

        /// 描述、评论、提交组与提交可以选中；点提交组本身只选中，不切换折叠。
        func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
            (item as? Node)?.item.isSelectable ?? false
        }

        /// ⇧ 点选一段或全选时跳过不能选中的行。
        func outlineView(
            _ outlineView: NSOutlineView,
            selectionIndexesForProposedSelection proposed: IndexSet
        ) -> IndexSet {
            proposed.filteredIndexSet { (outlineView.item(atRow: $0) as? Node)?.item.isSelectable ?? false }
        }

        /// 头部没有分隔线；描述、评论与发表评论顶边一条分隔线；提交组与组里的行用交替行的底色。
        func outlineView(_: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
            guard let node = item as? Node else { return nil }

            switch node.item {
            case .header: return PullRequestConversationRowView(style: .plain)
            case .description, .comment, .addComment: return PullRequestConversationRowView(style: .separated)
            case .group: return PullRequestConversationRowView(style: .eventGroup)
            case .commit, .spacer: return PullRequestConversationRowView(style: .event)
            }
        }

        /// 各行的内容；组末的空白没有内容。
        func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? Node else { return nil }

            switch node.item {
            case .header, .description, .comment:
                let row = PullRequestConversationTextRow(session: parent.session, request: parent.request, item: node.item)
                return Self.fill(outlineView.hostingView(row, identifier: "conversation-text"))

            case .group(let group):
                let row = PullRequestCommitGroupRow(group: group)
                return Self.fill(outlineView.hostingView(row, identifier: "conversation-group"))

            case .commit(let commit):
                let row = PullRequestConversationCommitRow(
                    commit: commit,
                    signatures: parent.session.signatures,
                    runner: parent.session.runner
                )

                return Self.fill(outlineView.hostingView(row, identifier: "conversation-commit"))

            case .spacer:
                return nil

            case .addComment:
                return addCommentCell(in: outlineView)
            }
        }

        /// 用户改变选择时记下这个请求选中的行。
        func outlineViewSelectionDidChange(_: Notification) {
            guard !updating, let outline else { return }

            let keys = outline.selectedRowIndexes.compactMap { (outline.item(atRow: $0) as? Node)?.item.key }
            parent.session.pullRequests.conversation.selections[parent.request.id] = Set(keys)
        }

        /// 用户展开提交组时从折叠的记忆里去掉它。
        func outlineViewItemDidExpand(_ notification: Notification) {
            rememberExpansion(notification, collapsed: false)
        }

        /// 用户折叠提交组时记下它。
        func outlineViewItemDidCollapse(_ notification: Notification) {
            rememberExpansion(notification, collapsed: true)
        }

        /// 列宽变化后重新量头部、描述与评论的行高。
        func outlineViewColumnDidResize(_: Notification) {
            guard let outline, outline.numberOfRows > 0 else { return }

            let rows = IndexSet(integersIn: 0 ..< outline.numberOfRows)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                outline.noteHeightOfRows(withIndexesChanged: rows)
            }
        }
    }
}

// MARK: - Private

extension PullRequestConversationView.Coordinator {
    /// 头部、描述、时间线与发表评论；提交组的子行是组里的提交，最后是一个空白行。
    private static func nodes(
        comments: [PullRequestComment],
        commits: [HistoryCommit]
    ) -> [PullRequestConversationView.Node] {
        typealias Node = PullRequestConversationView.Node

        let timeline = PullRequestConversationItem.timeline(comments: comments, commits: commits).map { item in
            guard case .group(let group) = item else {
                return Node(item)
            }

            return Node(item, children: group.commits.map { Node(.commit($0)) } + [Node(.spacer(group.day))])
        }

        return [Node(.header), Node(.description)] + timeline + [Node(.addComment)]
    }

    /// 单元格铺满表格给的位置，不按 SwiftUI 内容的尺寸加约束。
    private static func fill(_ view: NSHostingView<some View>) -> NSView {
        view.sizingOptions = []
        return view
    }

    /// 发表评论的单元格：没有接口客户端时按钮不可用。
    private func addCommentCell(in outlineView: NSOutlineView) -> NSView {
        let identifier = NSUserInterfaceItemIdentifier("conversation-add-comment")

        let cell =
            outlineView.makeView(withIdentifier: identifier, owner: nil) as? PullRequestAddCommentCell
                ?? PullRequestAddCommentCell()

        let session = parent.session
        let request = parent.request

        cell.identifier = identifier
        cell.button.isEnabled = parent.canComment
        cell.perform = { session.requestPullRequest(.comment(request)) }
        return cell
    }

    /// 头部、描述或评论在当前列宽下的高度；列宽变化后丢弃量过的结果。
    private func measuredHeight(of item: PullRequestConversationItem) -> CGFloat {
        let indentation = PullRequestConversationView.ConversationOutlineView.indentation
        let width = (outline?.tableColumns.first?.width ?? 0) - indentation

        // 列表还没布局时先给最小高度，列宽确定后会重新量
        guard width > 0 else {
            return 1
        }

        if width != measuredWidth {
            measuredWidth = width
            heights = [:]
        }

        if let height = heights[item.key] {
            return height
        }

        // 同一个 SwiftUI 宿主换上这一行的内容，按列宽量出高度
        let row = PullRequestConversationTextRow(session: parent.session, request: parent.request, item: item)
        let sizing = sizing ?? NSHostingController(rootView: row)
        sizing.rootView = row
        self.sizing = sizing

        let size = sizing.sizeThatFits(in: NSSize(width: width, height: .greatestFiniteMagnitude))
        let height = max(1, ceil(size.height))
        heights[item.key] = height
        return height
    }

    /// 提交组默认展开，这个请求折叠过的保持折叠。
    private func restoreExpansion(in outline: NSOutlineView) {
        let collapsed = parent.session.pullRequests.conversation.collapsedGroups[parent.request.id] ?? []

        for node in roots {
            guard case .group(let group) = node.item, !collapsed.contains(group.day) else { continue }
            outline.expandItem(node)
        }
    }

    /// 选中这个请求上次选中、现在还在的行。
    private func restoreSelection(in outline: NSOutlineView) {
        let keys = parent.session.pullRequests.conversation.selections[parent.request.id] ?? []

        let rows = IndexSet((0 ..< outline.numberOfRows).filter { row in
            (outline.item(atRow: row) as? PullRequestConversationView.Node).map { keys.contains($0.item.key) } ?? false
        })

        outline.selectRowIndexes(rows, byExtendingSelection: false)
    }

    /// 用户展开或折叠提交组时更新这个请求的折叠记忆。
    private func rememberExpansion(_ notification: Notification, collapsed: Bool) {
        guard
            !updating,
            let node = notification.userInfo?["NSObject"] as? PullRequestConversationView.Node,
            case .group(let group) = node.item
        else { return }

        let conversation = parent.session.pullRequests.conversation

        if collapsed {
            conversation.collapsedGroups[parent.request.id, default: []].insert(group.day)
        } else {
            conversation.collapsedGroups[parent.request.id]?.remove(group.day)
        }
    }
}
