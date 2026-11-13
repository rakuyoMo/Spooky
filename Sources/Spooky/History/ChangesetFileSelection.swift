import Foundation

// MARK: - ChangesetFileSelection

/// 提交详情里变更文件行的选区，与文件的展开状态分开。
///
/// 单击选中一行，⇧ 单击从锚点连续选到点中的行，⌘ 单击切换一行；↑ ↓ 把选中移到上一行或下一行，⇧ ↑ ↓ 从锚点连续选到移到的行。
struct ChangesetFileSelection: Equatable {
    /// 选中的文件路径。
    private(set) var paths: Set<String> = []

    /// 连续选择的起点：最近一次单击、⌘ 单击或不带 ⇧ 移到的行。
    private(set) var anchor: String? = nil

    /// 键盘移动的起点：最近一次点中或移到的行。
    private(set) var cursor: String? = nil

    /// 点选一行。
    ///
    /// - Parameters:
    ///   - path: 点中的文件。
    ///   - extending: 按住 ⇧：从锚点连续选到这一行；还没有锚点时按单击处理。
    ///   - toggling: 按住 ⌘：只切换这一行的选中，并把锚点移到这一行。
    ///   - order: 变更集里文件从上到下的顺序。
    mutating func click(_ path: String, extending: Bool, toggling: Bool, order: [String]) {
        if toggling {
            if paths.contains(path) {
                paths.remove(path)
            } else {
                paths.insert(path)
            }

            anchor = path
            cursor = path
            return
        }

        if extending, let range = range(to: path, in: order) {
            paths = range
            cursor = path
            return
        }

        select(path)
    }

    /// 按方向键移动选中。
    ///
    /// - Parameters:
    ///   - offset: −1 是上一行，1 是下一行；到了第一行或最后一行就停在那里。
    ///   - extending: 按住 ⇧：从锚点连续选到移到的行；还没有锚点时按不带 ⇧ 处理。
    ///   - order: 变更集里文件从上到下的顺序。
    mutating func move(by offset: Int, extending: Bool, order: [String]) {
        guard !order.isEmpty else {
            return
        }

        // 还没有点中或移到过的行时，↓ 从第一行开始，↑ 从最后一行开始
        let target: String =
            if let cursor, let index = order.firstIndex(of: cursor) {
                order[min(max(index + offset, 0), order.count - 1)]
            } else {
                offset > 0 ? order[0] : order[order.count - 1]
            }

        if extending, let range = range(to: target, in: order) {
            paths = range
            cursor = target
            return
        }

        select(target)
    }

    /// 变更集重读后只留下仍在其中的文件；锚点或移动起点不在了就一并清掉。
    ///
    /// - Parameter order: 重读后的文件顺序。
    /// - Returns: 去掉不在变更集里的文件之后的选区。
    func retaining(_ order: [String]) -> Self {
        let present = Set(order)
        var retained = self

        retained.paths.formIntersection(present)

        if let anchor, !present.contains(anchor) {
            retained.anchor = nil
        }

        if let cursor, !present.contains(cursor) {
            retained.cursor = nil
        }

        return retained
    }

    /// 右键时实际作用的文件：点在选区里是整个选区，按变更集里的顺序；点在选区外只是被点的那一个。
    ///
    /// - Parameters:
    ///   - path: 右键点中的文件。
    ///   - order: 变更集里文件从上到下的顺序。
    func affected(clicked path: String, order: [String]) -> [String] {
        paths.contains(path) ? order.filter(paths.contains) : [path]
    }

    /// 键盘移动之后要滚到的行：移到的行已完整露出时为 nil。
    ///
    /// 向上移时把行贴着上边露出，向下移时贴着下边；向下移到展开着的行时贴着上边，免得为露出它的 Diff 末尾而越过文件行。
    ///
    /// - Parameters:
    ///   - movingDown: 这次是向下移。
    ///   - visible: 完整露在滚动区域里的文件。
    ///   - expanded: 展开着的文件。
    /// - Returns: 要滚到的文件，以及是否贴着上边。
    func scrollTarget(
        movingDown: Bool,
        visible: Set<String>,
        expanded: Set<String>
    ) -> (path: String, alignsTop: Bool)? {
        guard let cursor, !visible.contains(cursor) else {
            return nil
        }

        return (cursor, !movingDown || expanded.contains(cursor))
    }

    /// 只选中这一行，锚点与移动起点都移到这里。
    private mutating func select(_ path: String) {
        paths = [path]
        anchor = path
        cursor = path
    }

    /// 从锚点到 `path` 之间（含两端）的文件；没有锚点或任一端不在 `order` 里时为 nil。
    private func range(to path: String, in order: [String]) -> Set<String>? {
        guard
            let anchor,
            let start = order.firstIndex(of: anchor),
            let end = order.firstIndex(of: path)
        else {
            return nil
        }

        return Set(order[min(start, end) ... max(start, end)])
    }
}
