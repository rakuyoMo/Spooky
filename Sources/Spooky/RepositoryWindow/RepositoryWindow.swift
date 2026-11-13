import AppKit

// MARK: - RepositoryWindow

/// 仓库窗口：点在列表里时，先把键盘焦点交给这个列表。
///
/// 侧边栏与历史列表的行是不接受第一响应者的 SwiftUI 视图，窗口不会因为点击把焦点交给列表，焦点会留在原处。
final class RepositoryWindow: NSWindow {
    /// 按下鼠标左键时，点中的列表还没有焦点就先交给它，再照常分发。
    override func sendEvent(_ event: NSEvent) {
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
}
