import AppKit
import SpookyKit
import SwiftUI

// MARK: - DiffHunkTextView

/// 每块一个原生文本区和独立行号栏，外层 SwiftUI 继续负责分节与滚动。
struct DiffHunkTextView: NSViewRepresentable {
    /// 原始补丁块。
    let hunk: DiffHunk

    /// 字体、颜色与显示设置。
    let style: TextStyle

    /// 两侧全文的语法片段。
    let syntax: DiffSyntax?

    /// 逻辑行上的行内高亮。
    let highlights: [Int: [Range<Int>]]

    /// 是否允许行号选择。
    let enabled: Bool

    /// 只读文本不暴露行号写入动作。
    let readOnly: Bool

    /// 行号选区与正文字符选区分别持有。
    @Binding
    var selected: Set<Int>

    /// 创建同一份负责量高和绘制的文本栈。
    func makeNSView(context _: Context) -> DiffHunkTextContainer {
        DiffHunkTextContainer()
    }

    /// 只在内容或样式改变时更新文字，行号选择变化不重设全文。
    func updateNSView(_ view: DiffHunkTextContainer, context _: Context) {
        view.show(hunk: hunk, style: style, syntax: syntax, highlights: highlights)
        view.gutter.configure(hunk: hunk, enabled: enabled, readOnly: readOnly, selected: selected)
        view.gutter.onSelectionChange = { selected = $0 }
    }

    /// 按提议宽度布局正文，块高包括 TextKit 自带的末尾空片段。
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: DiffHunkTextContainer, context _: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }

        return CGSize(width: width, height: nsView.measure(width: width))
    }
}

// MARK: - DiffHunkTextContainer

/// 并排放置行号与正文，没有内层滚动视图。
final class DiffHunkTextContainer: NSView {
    /// 可选择的正文。
    let document = DiffTextDocumentView.make()

    /// 处理逻辑行选择的行号栏。
    let gutter = DiffGutterView()

    /// 当前原文与显示映射。
    private(set) var content: DiffTextContent?

    /// 当前显示样式。
    private(set) var style: TextStyle?

    /// 当前宽度下的布局。
    private(set) var textLayout: DiffTextLayout?

    /// 上次构造正文使用的块。
    private var hunk: DiffHunk?

    /// 上次构造正文使用的语法片段。
    private var syntax: DiffSyntax?

    /// 上次构造正文使用的行内范围。
    private var highlights: [Int: [Range<Int>]] = [:]

    /// 已量过的宽度；只有几何输入改变时才重新排版。
    private var measuredWidth: CGFloat?

    /// 与文字区一致的自上而下坐标。
    override var isFlipped: Bool { true }

    /// 建立正文与行号的共享内容所有权。
    init() {
        super.init(frame: .zero)

        document.owner = self
        gutter.owner = self
        addSubview(gutter)
        addSubview(document)
    }

    /// 块容器仅从代码构造。
    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("块文本区仅从代码构造") }

    /// 内容变更时重建映射；颜色变化只更新属性，不触碰字符选区。
    func show(hunk: DiffHunk, style: TextStyle, syntax: DiffSyntax?, highlights: [Int: [Range<Int>]]) {
        guard self.hunk != hunk || self.style != style || self.syntax != syntax || self.highlights != highlights else {
            return
        }

        let previousStyle = self.style
        let previousHunk = self.hunk
        let next = DiffTextContent(hunk: hunk, style: style, syntax: syntax, highlights: highlights)
        let sameText = content?.attributed.string == next.attributed.string
        let sameMetrics = previousStyle?.theme.fontName == style.theme.fontName
            && previousStyle?.theme.fontSize == style.theme.fontSize
        self.hunk = hunk
        self.style = style
        self.syntax = syntax
        self.highlights = highlights
        content = next

        if sameText, sameMetrics, previousHunk == hunk {
            updateColors(next.attributed)
        } else {
            document.textStorage?.setAttributedString(next.attributed)
            document.typingAttributes = DiffTextContent.attributes(style: style)
            measuredWidth = nil
            textLayout = nil
        }

        document.backgroundColor = style.theme.colors["background"]?.calibratedNSColor ?? .textBackgroundColor
        document.selectedTextAttributes = [
            .backgroundColor: style.theme.colors["selection"]?.calibratedNSColor ?? NSColor.selectedTextBackgroundColor,
        ]
        needsLayout = true
        document.needsDisplay = true
        gutter.needsDisplay = true
    }

    /// 同一宽度复用布局，重排时同时刷新行号命中范围。
    @discardableResult
    func measure(width: CGFloat) -> CGFloat {
        guard let content, let style else { return 0 }

        if measuredWidth != width || textLayout == nil {
            let gutterWidth = content.columnWidth * CGFloat(content.rows.first?.line.numbers.count ?? 2)
            document.textContainer?.containerSize = CGSize(
                width: max(1, width - gutterWidth - 8),
                height: CGFloat.greatestFiniteMagnitude
            )
            textLayout = DiffTextLayout(content: content, document: document, style: style)
            measuredWidth = width
        }

        return textLayout?.height ?? 0
    }

    /// 宿主宽度改变时重排，并把实际高度交给文字区。
    override func layout() {
        super.layout()

        let height = measure(width: bounds.width)
        let gutterWidth = (content?.columnWidth ?? 0) * CGFloat(content?.rows.first?.line.numbers.count ?? 2)
        gutter.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: height)
        document.frame = CGRect(x: gutterWidth, y: 0, width: max(1, bounds.width - gutterWidth), height: height)
    }

    /// 只写入绘制属性，避免颜色更新使字形和段落重新布局。
    private func updateColors(_ attributed: NSAttributedString) {
        guard let storage = document.textStorage else { return }

        storage.beginEditing()
        storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: storage.length))
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { values, range, _ in
            let colors = values.filter { $0.key == .foregroundColor || $0.key == .backgroundColor }
            storage.addAttributes(colors, range: range)
        }
        storage.endEditing()
    }
}
