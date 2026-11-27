import AppKit

// MARK: - RepositoryWindow

/// 仓库窗口：点击列表时交出焦点，按 Esc 时可退出工具栏搜索。
///
/// 侧边栏与历史列表的行是不接受第一响应者的 SwiftUI 视图，窗口不会因为点击把焦点交给列表，焦点会留在原处。
final class RepositoryWindow: NSWindow {
    /// 分发事件前处理列表点击与工具栏搜索的焦点。
    override func sendEvent(_ event: NSEvent) {
        if endToolbarSearchOnEscape(event) {
            return
        }

        if event.type == .leftMouseDown, let list = unfocusedList(at: event.locationInWindow) {
            makeFirstResponder(list)
        }

        super.sendEvent(event)
    }

    /// 窗口坐标所在、还没有键盘焦点的列表。
    ///
    /// - Parameter location: 窗口坐标。
    /// - Returns: 点中的列表；没点在列表里，或焦点已在列表与它里面的视图上时为 nil。
    func unfocusedList(at location: NSPoint) -> NSTableView? {
        var view = contentView?.superview?.hitTest(location)

        // 从点中的视图往上找到所在的列表
        while let current = view, !(current is NSTableView) {
            view = current.superview
        }

        guard let list = view as? NSTableView, list.acceptsFirstResponder else {
            return nil
        }

        // 焦点已在列表或行内的输入框上时不动
        if let responder = firstResponder as? NSView, responder.isDescendant(of: list) {
            return nil
        }

        return list
    }

    /// 只有焦点在工具栏搜索框上时，Esc 才结束搜索编辑。
    private func endToolbarSearchOnEscape(_ event: NSEvent) -> Bool {
        guard
            event.type == .keyDown, event.keyCode == 53,
            event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift]),
            let item = toolbar?.items.first(where: { $0.itemIdentifier == RepositoryToolbar.search })
            as? NSSearchToolbarItem,
            let editor = item.searchField.currentEditor() as? NSTextView,
            firstResponder === editor
        else { return false }

        // 输入法还有候选文字时，先让它处理 Esc。
        guard !editor.hasMarkedText() else {
            return false
        }

        // 走工具栏的原生结束流程，保留搜索词，并让搜索项恢复随宽度变化的尺寸。
        item.endSearchInteraction()
        return true
    }
}
