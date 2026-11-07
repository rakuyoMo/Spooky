import Observation
import SpookyKit

/// 一个块的逻辑行选区；显示行用于范围定位，提示与正文共享同一逻辑标识。
@MainActor
@Observable
final class DiffLineSelection {
    /// 当前用于立即绘制的选区。
    private(set) var selected: Set<Int> = []

    /// 松开鼠标或完成键盘 / 辅助功能动作后发布的块头计数。
    private(set) var publishedCount = 0

    /// 范围起点是显示行序号，不是补丁行标识。
    private(set) var anchor: Int? = nil

    /// 每个显示行对应的可选逻辑标识，上下文为 nil。
    private(set) var rows: [Int?] = []

    /// 范围切换后旧视图的事件不能重新激活已退役的模型。
    private(set) var isActive = true

    /// 鼠标最初按下的位置，拖动期间不改写。
    private var dragStart: Int? = nil

    /// 本次拖动已锁定的增选或取消方向。
    private var dragSelecting: Bool? = nil

    /// 初始没有块内容，挂载时绑定显示映射。
    init() { }

    /// 绑定当前块的显示映射，组合块没有可选行。
    func bind(_ hunk: DiffHunk) {
        guard isActive else { return }

        let allowed = Set(hunk.combinedRanges == nil ? hunk.lines.filter(\.isChange).map(\.id) : [])
        let next = DiffDisplayLine.rows(in: hunk).map { allowed.contains($0.lineID) ? $0.lineID : nil }
        guard rows != next else { return }

        clear()
        rows = next
    }

    /// 按下即修改当前选区，块头计数仍保持上次发布值。
    func begin(at index: Int, extending: Bool) {
        guard isActive, rows.indices.contains(index) else { return }

        dragStart = index
        dragSelecting = nil
        guard let id = rows[index] else { return }

        if extending {
            extend(to: index)
        } else {
            dragSelecting = !selected.contains(id)
            toggle(id, at: index)
        }
    }

    /// 沿初始位置到当前位置累计处理，回拖不撤销已经改变的单位。
    func drag(to index: Int) {
        guard isActive, let start = dragStart, rows.indices.contains(index) else { return }

        let indices = start <= index ? Array(start ... index) : Array((index ... start).reversed())
        let identifiers = indices.compactMap { rows[$0] }
        guard let first = identifiers.first else { return }

        if dragSelecting == nil { dragSelecting = !selected.contains(first) }
        let range = Set(identifiers)

        if dragSelecting ?? false {
            selected.formUnion(range)
        } else {
            selected.subtract(range)
        }
    }

    /// 鼠标松开才把逻辑单位数量发布给块头。
    func end() {
        cancelDrag()
        publishedCount = selected.count
    }

    /// Space 与辅助功能按下是完整的一次选择，立即发布。
    func activate(at index: Int, extending: Bool = false) {
        guard isActive, rows.indices.contains(index), let id = rows[index] else { return }

        if extending {
            extend(to: index)
        } else {
            toggle(id, at: index)
        }
        end()
    }

    /// 禁用时只结束临时拖动，不修改现有选择和范围起点。
    func cancelDrag() {
        dragStart = nil
        dragSelecting = nil
    }

    /// 清空本块选择与全部交互状态。
    func clear() {
        selected = []
        publishedCount = 0
        anchor = nil
        cancelDrag()
    }

    /// 退出当前范围后清空并永久停止接收旧视图的事件。
    func invalidate() {
        clear()
        isActive = false
    }

    /// 单击取消时清空范围起点，添加时记住当前显示行。
    private func toggle(_ id: Int, at index: Int) {
        if selected.contains(id) {
            selected.remove(id)
            anchor = nil
        } else {
            selected.insert(id)
            anchor = index
        }
    }

    /// 无起点时取最后一个已选显示行，空选区则从块首开始。
    private func extend(to index: Int) {
        let start = anchor ?? rows.indices.last { rows[$0].map { selected.contains($0) } ?? false } ?? 0
        anchor = start
        selected.formUnion((min(start, index) ... max(start, index)).compactMap { rows[$0] })
    }
}
