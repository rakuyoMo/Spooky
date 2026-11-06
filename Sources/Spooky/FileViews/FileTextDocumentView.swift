import AppKit

// MARK: - FileTextDocumentView

/// 固定行高的只读正文，在背景上画出 Blame 段的分隔线与高亮。
final class FileTextDocumentView: NSTextView {
    /// 当前样式。
    private(set) var style: FileTextStyle?

    /// 当前的 Tab 宽度、不可见字符与主题颜色设置。
    private(set) var rendering: TextStyle?

    /// Blame 的注释；原文为 nil。
    var annotations: FileTextAnnotations?

    /// 已读 blob 的完整原文，复制不使用显示替代字符。
    private var source: [UInt16] = []

    /// 全文显示 UTF-16 范围到原文的对应关系。
    private var mapping = TextSourceMap()

    /// 复制只提供映射后的原始纯文本。
    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] { [.string] }

    /// 第一行顶边离正文顶部的距离。
    var topInset: CGFloat { textContainerInset.height }

    /// 创建使用 TextKit 1 的只读正文：固定行高靠段落样式保证，行号按行号乘行高定位。
    static func make() -> FileTextDocumentView {
        let storage = NSTextStorage()
        let layout = TextInvisibleLayoutManager()
        layout.allowsNonContiguousLayout = true
        storage.addLayoutManager(layout)

        // 容器不跟随视图宽度，长行不折行，改为横向滚动
        let container = NSTextContainer(
            size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        container.widthTracksTextView = false
        layout.addTextContainer(container)

        let document = FileTextDocumentView(frame: .zero, textContainer: container)
        document.isEditable = false
        document.isSelectable = true
        document.isRichText = false
        document.usesFindBar = false
        document.drawsBackground = true
        document.isVerticallyResizable = true
        document.isHorizontallyResizable = true
        document.minSize = .zero
        document.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        document.autoresizingMask = [.width]
        document.textContainerInset = NSSize(width: 4, height: 6)
        return document
    }

    /// 第 index 行（从 0 开始）顶边的纵坐标。
    func lineTop(_ index: Int) -> CGFloat {
        topInset + CGFloat(index) * (style?.lineHeight ?? 0)
    }

    /// 替换正文与样式，所有行使用同一个固定行高。
    ///
    /// - Parameters:
    ///   - lines: 各行原文。
    ///   - source: 已读 blob 的完整源串，保留全部行分隔符与末尾 LF。
    ///   - style: 字体、行高与颜色。
    ///   - rendering: Tab 宽度与不可见字符设置，与 Diff 的显示一致。
    ///   - spans: 与行一一对应的语法片段；为空时按正文色显示。
    func show(
        _ lines: [String],
        source: String,
        style: FileTextStyle,
        rendering: TextStyle,
        spans: [[SyntaxSpan]]?
    ) {
        self.style = style
        self.rendering = rendering
        self.source = Array(source.utf16)
        mapping = TextSourceMap()

        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = style.lineHeight
        paragraph.maximumLineHeight = style.lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.font,
            .foregroundColor: style.text,
            .paragraphStyle: paragraph,
        ]
        let content = NSMutableAttributedString()

        // 行尾归属取 blob，不使用 Blame 协议在每条记录后补齐的 LF。
        for (index, line) in lines.enumerated() {
            let lineSpans = spans.flatMap { $0.indices.contains(index) ? $0[index] : nil }
            let rendered = TextLineRenderer.rendered(line, spans: lineSpans, style: rendering)
            content.append(rendered.appKit(attributes: attributes))
            mapping.append(rendered.mapping)

            if index < lines.count - 1 || source.utf16.last == 10 {
                content.append(TextInvisibleLayoutManager.lineFeed(after: line, style: rendering, attributes: attributes))
                mapping.append(source: 1, display: 1)
            }
        }

        textStorage?.setAttributedString(content)
        backgroundColor = style.background
        insertionPointColor = style.text
        selectedTextAttributes = [.backgroundColor: style.selection]
        enclosingScrollView?.backgroundColor = style.background
    }

    /// 显示选区还原到已读 blob 的源串，包含被隐藏的 CR 和实际末尾 LF。
    func copiedText(in range: NSRange) -> String {
        let original = NSIntersectionRange(mapping.sourceRange(for: range), NSRange(location: 0, length: source.count))
        return String(decoding: source[original.location ..< NSMaxRange(original)], as: UTF16.self)
    }

    /// 原生 Copy、菜单与快捷键共用完整源映射，不复制可见替换符。
    override func writeSelection(to pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == .string, selectedRange().length > 0 else { return false }

        return pasteboard.setString(copiedText(in: selectedRange()), forType: .string)
    }

    /// 背景之上画出高亮的段与段之间的分隔线。
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        guard let annotations, let style, style.lineHeight > 0 else {
            return
        }

        for index in visibleGroups(in: rect, annotations: annotations) {
            let group = annotations.groups[index]
            let top = lineTop(group.firstLine - 1)

            if group.commitID == annotations.highlightedCommit {
                style.highlight.setFill()
                NSRect(
                    x: rect.minX,
                    y: top,
                    width: rect.width,
                    height: CGFloat(group.lineCount) * style.lineHeight
                )
                .fill()
            }

            if index > 0 {
                style.separator.setFill()
                NSRect(x: rect.minX, y: top, width: rect.width, height: 1).fill()
            }
        }
    }

    /// 与某个矩形相交的段的序号。
    func visibleGroups(in rect: NSRect, annotations: FileTextAnnotations) -> Range<Int> {
        guard let style, style.lineHeight > 0, !annotations.groups.isEmpty else {
            return 0 ..< 0
        }

        // 先换算出矩形覆盖的行，再找到包含首末两行的段
        let first = max(Int(((rect.minY - topInset) / style.lineHeight).rounded(.down)) + 1, 1)
        let last = max(Int(((rect.maxY - topInset) / style.lineHeight).rounded(.up)) + 1, first)
        let lower = annotations.groupIndex(containing: first) ?? 0
        let upper = annotations.groupIndex(containing: last) ?? annotations.groups.count - 1

        return lower ..< max(upper + 1, lower)
    }
}
