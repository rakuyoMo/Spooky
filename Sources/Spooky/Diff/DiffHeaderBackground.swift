import AppKit
import SwiftUI

// MARK: - DiffPresentation

/// 独立文件的块头吸顶，变更集内嵌的块头随内容滚动。
enum DiffPresentation {
    /// 与其它文件一起呈现在变更集内。
    case embedded

    /// 占用自己的单文件滚动区域。
    case standalone
}

// MARK: - DiffHeaderBackground

/// 块头的不透明系统底色与内部边线，不参与内容命中。
struct DiffHeaderBackground: NSViewRepresentable {
    /// 块头与正文自然位置之间的固定高度。
    static let height: CGFloat = 32

    /// 同一文件内已有上一块，且当前没有浮动时显示顶线。
    let showsTopBorder: Bool

    /// 创建不依赖文本主题的块头背景。
    func makeNSView(context _: Context) -> DiffHeaderBackgroundView {
        DiffHeaderBackgroundView()
    }

    /// 吸顶状态只改变边线绘制，不改变布局。
    func updateNSView(_ view: DiffHeaderBackgroundView, context _: Context) {
        view.showsTopBorder = showsTopBorder
        view.needsDisplay = true
    }
}

// MARK: - DiffHeaderBackgroundView

/// 分隔线始终叠在 32 pt 矩形内部，动态系统色跟随外观。
final class DiffHeaderBackgroundView: NSView {
    /// 顶线仅属于正常位置的后续块。
    var showsTopBorder = false

    /// 坐标从顶边向下增长。
    override var isFlipped: Bool { true }

    /// 底色完全遮挡从下方滚过的正文。
    override var isOpaque: Bool { true }

    /// 块头内部的上下边线矩形。
    var borders: [NSRect] {
        let bottom = NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1)
        return showsTopBorder ? [NSRect(x: 0, y: 0, width: bounds.width, height: 1), bottom] : [bottom]
    }

    /// 不抢占块头按钮和原文的鼠标命中。
    override func hitTest(_: NSPoint) -> NSView? { nil }

    /// 先填满不透明底色，再绘制上下边线。
    override func draw(_: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        for border in borders { border.fill() }
    }
}
