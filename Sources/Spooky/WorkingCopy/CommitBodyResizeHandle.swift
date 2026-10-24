import AppKit
import SwiftUI

// MARK: - CommitBodyResizeHandle

/// 正文框的拖柄：下沿的细条只上下拖动改正文高度；右下角的拖柄还能左右拖动，直接移动工作区列表右侧的分隔线。
struct CommitBodyResizeHandle: NSViewRepresentable {
    /// 拖柄所在的位置。
    enum Kind {
        /// 正文框下沿，只改高度，悬停时显示上下调整的光标。
        case edge

        /// 正文框右下角，同时改高度与所在分栏的宽度。
        case corner
    }

    /// 接收拖动事件的视图；位移取自事件本身，分栏随拖动改变宽度时也不会累积误差。
    @MainActor
    final class HandleView: NSView {
        /// 拖柄的位置。
        var kind = Kind.edge

        /// 纵向位移（向下为正）与窗口高度。
        var onResize: ((Double, Double) -> Void)? = nil

        /// 角上的拖柄画出斜纹，下沿的细条不画。
        override func draw(_: NSRect) {
            guard kind == .corner else { return }

            NSColor.tertiaryLabelColor.setStroke()

            // 三条斜线落在右下角 10 × 10 pt 的范围内。
            let path = NSBezierPath()
            path.lineWidth = 1

            for inset in [3.0, 6.0, 9.0] {
                path.move(to: NSPoint(x: bounds.maxX - 5 - inset, y: bounds.minY + 5))
                path.line(to: NSPoint(x: bounds.maxX - 5, y: bounds.minY + 5 + inset))
            }

            path.stroke()
        }

        /// 下沿的细条悬停时显示上下调整的光标；角上的拖柄保持普通光标。
        override func resetCursorRects() {
            guard kind == .edge else { return }

            addCursorRect(bounds, cursor: .resizeUpDown)
        }

        /// 按下时不让窗口跟着拖动。
        override var mouseDownCanMoveWindow: Bool { false }

        /// 按下由拖柄自己接住，之后的拖动事件都交给它，不转给下面的正文框与按钮。
        override func mouseDown(with _: NSEvent) { }

        /// 拖动时先改高度，角上的拖柄再移动分隔线。
        override func mouseDragged(with event: NSEvent) {
            onResize?(event.deltaY, Double(window?.frame.height ?? 0))

            guard kind == .corner, event.deltaX != 0 else { return }

            moveDivider(by: event.deltaX)
        }

        /// 找到所在的左右分栏，把这一栏右侧的分隔线随鼠标横向移动。
        private func moveDivider(by deltaX: Double) {
            var pane: NSView = self

            // 沿父视图向上，第一个直接放在左右分栏里的视图就是工作区列表所在的一栏。
            while let parent = pane.superview {
                if let split = parent as? NSSplitView, split.isVertical {
                    guard
                        let index = split.arrangedSubviews.firstIndex(of: pane),
                        index < split.arrangedSubviews.count - 1
                    else { return }

                    split.setPosition(pane.frame.maxX + deltaX, ofDividerAt: index)
                    return
                }

                pane = parent
            }
        }
    }

    /// 拖柄的位置。
    let kind: Kind

    /// 正文区高度，拖动时在 192 pt 与窗口高度的一半之间变化。
    @Binding
    var height: Double

    /// 创建处理鼠标拖动的 AppKit 视图。
    func makeNSView(context _: Context) -> HandleView {
        let view = HandleView()
        view.kind = kind
        view.onResize = { deltaY, windowHeight in resize(by: deltaY, windowHeight: windowHeight) }
        return view
    }

    /// 绑定随视图刷新更新，拖动时始终改写最新的高度。
    func updateNSView(_ view: HandleView, context _: Context) {
        view.kind = kind
        view.onResize = { deltaY, windowHeight in resize(by: deltaY, windowHeight: windowHeight) }
    }

    /// 按鼠标的纵向位移改正文高度，不小于 192 pt、不超过窗口高度的一半。
    private func resize(by deltaY: Double, windowHeight: Double) {
        let minimum = CommitEditorSettings.minimumBodyHeight
        let maximum = max(minimum, windowHeight / 2)

        height = min(max(height + deltaY, minimum), maximum)
    }
}
