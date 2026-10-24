import AppKit
import SpookyKit
import SwiftUI

// MARK: - HistoryListDrop

/// 历史列表内拖放提交算出的交互式变基动作，只在看 HEAD 分支时有效。
///
/// 落在另一个提交上是压缩，按住 ⌥ 是 fixup；落在两行之间是把提交移到那里。
/// 日期分组行不是提交：落在分组行上不接受，落在分组行上方等于落在它下面最近的提交上方。
@MainActor
enum HistoryListDrop {
    /// 落点算出的动作；不在看 HEAD 分支、落点不是 HEAD 历史里的别的提交，或移动后位置不变时为 nil。
    ///
    /// - Parameters:
    ///   - dragged: 被拖的提交，按列表顺序。
    ///   - row: 表格给出的落点行。
    ///   - between: 落在这一行上方的两行之间；否则落在这一行上。
    ///   - alternate: 是否按住 ⌥。
    static func action(
        dragged: [String],
        row: Int,
        between: Bool,
        alternate: Bool,
        session: RepositorySession
    ) -> RewriteAction? {
        let history = session.history

        // 未拉取的提交不在 HEAD 的历史里，不能参与改写
        guard
            session.isViewingHead,
            session.canRewrite,
            !dragged.isEmpty,
            !dragged.contains(where: { history.unpulled.contains($0) })
        else { return nil }

        guard between else {
            guard
                let target = history.commit(atRow: row),
                !dragged.contains(target.id),
                !history.unpulled.contains(target.id)
            else { return nil }

            return alternate ? .fixup(dragged, into: target.id) : .squash(dragged, into: target.id)
        }

        guard
            let gap = gapTarget(row: row, in: history),
            !dragged.contains(gap.target),
            !history.unpulled.contains(gap.target),
            moves(dragged, to: gap.target, position: gap.position, in: history.commits.map(\.id))
        else { return nil }

        return .move(dragged, to: gap.target, position: gap.position)
    }

    /// 落点旁显示的动作名。
    static func titleKey(of action: RewriteAction) -> String {
        switch action {
        case .fixup: "rewrite.fixup.button"
        case .move: "branch.moveHere"
        default: "rewrite.squash.button"
        }
    }

    /// 两行之间的落点换成相对某个提交的位置：下面最近的提交的上方；下面没有提交时是上面最近的提交的下方。
    private static func gapTarget(
        row: Int,
        in history: RepositoryHistoryState
    ) -> (target: String, position: MovePosition)? {
        let gap = min(max(row, 0), history.rows.count)

        if let below = (gap ..< history.rows.count).lazy.compactMap({ history.commit(atRow: $0) }).first {
            return (below.id, .above)
        }

        let above = (0 ..< gap).reversed().lazy.compactMap { history.commit(atRow: $0) }.first
        return above.map { ($0.id, .below) }
    }

    /// 移动后列表里的提交顺序是否真的变了：拖动的提交已经整段挨着目标时不算移动。
    ///
    /// - Parameter order: 列表里的提交，从新到旧。
    private static func moves(
        _ dragged: [String],
        to target: String,
        position: MovePosition,
        in order: [String]
    ) -> Bool {
        let moving = Set(dragged)
        var result = order.filter { !moving.contains($0) }

        guard let index = result.firstIndex(of: target) else {
            return false
        }

        result.insert(contentsOf: order.filter(moving.contains), at: position == .above ? index : index + 1)
        return result != order
    }
}

// MARK: - HistoryDropLabel

/// 列表内拖放时落点旁的动作名：落在提交上时在那一行右侧，落在两行之间时在缝隙右侧。
@MainActor
final class HistoryDropLabel {
    /// 正在显示的动作名。
    private var view: NSHostingView<DropActionLabel>? = nil

    /// 显示动作名；文字为 nil 时移除。
    ///
    /// - Parameters:
    ///   - row: 表格给出的落点行。
    ///   - between: 落在这一行上方的两行之间。
    func show(_ text: String?, row: Int, between: Bool, in table: NSTableView) {
        guard let text, row >= 0, table.numberOfRows > 0 else {
            hide()
            return
        }

        let label = view ?? NSHostingView(rootView: DropActionLabel(text: text))
        label.rootView = DropActionLabel(text: text)

        if label.superview !== table {
            table.addSubview(label)
        }

        view = label

        // 缝隙在这一行的上边；落在最后一行之后时在最后一行的下边
        let rect = row < table.numberOfRows ? table.rect(ofRow: row) : table.rect(ofRow: table.numberOfRows - 1)
        let size = label.fittingSize
        let gap = row < table.numberOfRows ? rect.minY : rect.maxY
        let midY = between ? gap : rect.midY

        label.frame = NSRect(
            x: table.visibleRect.maxX - size.width - 8,
            y: midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// 拖动离开或结束时移除。
    func hide() {
        view?.removeFromSuperview()
        view = nil
    }
}
