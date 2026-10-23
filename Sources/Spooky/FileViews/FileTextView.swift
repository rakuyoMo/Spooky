import AppKit
import SpookyKit
import SwiftUI

// MARK: - FileTextAnnotations

/// Blame 注释栏的数据：按段排列的提交归属与一起高亮的提交。
struct FileTextAnnotations {
    /// 覆盖全部行、按行号排列的段。
    let groups: [BlameGroup]

    /// 段引用的提交。
    let commits: [String: BlameCommit]

    /// 单击注释后一起高亮的提交。
    let highlightedCommit: String?

    /// 包含某一行（从 1 开始）的段的序号。
    func groupIndex(containing line: Int) -> Int? {
        var lower = 0
        var upper = groups.count - 1

        // 段按行号排列，二分查找
        while lower <= upper {
            let middle = (lower + upper) / 2
            let group = groups[middle]

            if line < group.firstLine {
                upper = middle - 1
            } else if line >= group.firstLine + group.lineCount {
                lower = middle + 1
            } else {
                return middle
            }
        }

        return nil
    }
}

// MARK: - FileTextStyle

/// 正文、行号与注释的字体和颜色，全部取自文本主题。
struct FileTextStyle: Equatable {
    /// 行高是主题字体默认行高的倍数。
    private static let lineHeightMultiple: CGFloat = 1.4

    /// 主题字体。
    let font: NSFont

    /// 固定行高，行号与注释按它和正文对齐。
    let lineHeight: CGFloat

    /// 正文颜色。
    let text: NSColor

    /// 正文、行号与注释共用的背景色。
    let background: NSColor

    /// 行号与注释中作者、日期的颜色：正文色向背景方向调淡。
    let secondary: NSColor

    /// 一起高亮的段的底色：背景色略微加深或提亮。
    let highlight: NSColor

    /// 段之间的分隔线颜色。
    let separator: NSColor

    /// 选中文本的底色。
    let selection: NSColor

    /// 按主题计算全部样式。
    init(theme: TextTheme) {
        font = NSFont(name: theme.fontName, size: theme.fontSize)
            ?? .monospacedSystemFont(ofSize: theme.fontSize, weight: .regular)
        lineHeight = (NSLayoutManager().defaultLineHeight(for: font) * Self.lineHeightMultiple).rounded()
        text = theme.colors["text"]?.nsColor ?? .textColor
        background = theme.colors["background"]?.nsColor ?? .textBackgroundColor
        selection = theme.colors["selection"]?.nsColor ?? .selectedTextBackgroundColor

        // 深色正文调亮、浅色正文调暗；背景同理
        secondary = Self.shifted(text, by: Self.isDark(text) ? 0.2 : -0.2)
        highlight = Self.shifted(background, by: Self.isDark(background) ? 0.1 : -0.1)
        separator = Self.shifted(background, by: Self.isDark(background) ? 0.2 : -0.2)
    }

    /// 按亮度判断颜色偏深还是偏浅。
    private static func isDark(_ color: NSColor) -> Bool {
        guard let rgb = color.usingColorSpace(.sRGB) else {
            return false
        }

        return rgb.redComponent * 0.299 + rgb.greenComponent * 0.587 + rgb.blueComponent * 0.114 < 0.5
    }

    /// RGB 各分量同时增减，透明度不变。
    private static func shifted(_ color: NSColor, by amount: CGFloat) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else {
            return color
        }

        let clamp: (CGFloat) -> CGFloat = { min(max($0 + amount, 0), 1) }

        return NSColor(
            srgbRed: clamp(rgb.redComponent),
            green: clamp(rgb.greenComponent),
            blue: clamp(rgb.blueComponent),
            alpha: rgb.alphaComponent
        )
    }
}

// MARK: - FileTextView

/// 只读、可选中、不折行的文件正文，左侧是行号栏；Blame 时行号栏左边再加一列按段对齐的注释。
struct FileTextView: NSViewRepresentable {
    /// 桥接正文、行号栏与注释弹窗。
    @MainActor
    final class Coordinator {
        /// 最新的输入。
        var parent: FileTextView

        /// 已显示内容的身份，变化时替换正文并回到顶部。
        var contentID: String?

        /// 已应用的样式。
        var style: FileTextStyle?

        /// 单击注释弹出的提交摘要。
        var popover: NSPopover?

        /// 保存初始输入。
        init(_ parent: FileTextView) {
            self.parent = parent
        }

        /// 单击注释：高亮同一提交的所有段，并在注释旁弹出摘要。
        func annotationClicked(_ index: Int, rect: NSRect, in view: NSView) {
            guard
                let annotations = parent.annotations,
                let commit = annotations.commits[annotations.groups[index].commitID]
            else { return }

            parent.highlight?(commit.id)

            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = false
            popover.contentViewController = NSHostingController(rootView: BlameCommitPopover(commit: commit))
            popover.show(relativeTo: rect, of: view, preferredEdge: .maxX)
            self.popover = popover
        }

        /// 双击注释回到对应的提交。
        func annotationDoubleClicked(_ index: Int) {
            guard let annotations = parent.annotations else {
                return
            }

            popover?.close()
            parent.openCommit?(annotations.groups[index].commitID)
        }
    }

    /// 内容身份：文件、版本与显示方式。
    let contentID: String

    /// 各行原文。
    let lines: [String]

    /// 当前文本主题。
    let theme: TextTheme

    /// Blame 的注释；原文为 nil。
    var annotations: FileTextAnnotations? = nil

    /// 正文右键菜单在系统的复制等项之后追加的动作。
    var menuActions: [FileViewAction] = []

    /// 单击注释时高亮的提交。
    var highlight: ((String) -> Void)? = nil

    /// 双击注释时回到的提交。
    var openCommit: ((String) -> Void)? = nil

    /// 建立桥接。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// TextKit 1 的正文视图配合竖直标尺，行号与注释随正文纵向滚动、不随横向滚动。
    func makeNSView(context: Context) -> NSScrollView {
        let document = FileTextDocumentView.make()
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.documentView = document

        let gutter = FileGutterView(scrollView: scroll, document: document)
        gutter.clicked = { [weak coordinator = context.coordinator] index, rect, view in
            coordinator?.annotationClicked(index, rect: rect, in: view)
        }
        gutter.doubleClicked = { [weak coordinator = context.coordinator] in
            coordinator?.annotationDoubleClicked($0)
        }

        scroll.verticalRulerView = gutter
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        return scroll
    }

    /// 内容身份或主题变化时替换正文，其余变化只重绘高亮与注释。
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        guard
            let document = scroll.documentView as? FileTextDocumentView,
            let gutter = scroll.verticalRulerView as? FileGutterView
        else { return }

        let style = FileTextStyle(theme: theme)
        let replaced = coordinator.contentID != contentID

        if replaced || coordinator.style != style {
            document.show(lines, style: style)
            coordinator.contentID = contentID
            coordinator.style = style
        }

        if replaced {
            coordinator.popover?.close()
            document.scroll(.zero)
        }

        document.annotations = annotations
        document.menuActions = menuActions
        gutter.update(lineCount: lines.count, annotations: annotations)
        document.needsDisplay = true
    }
}

// MARK: - FileTextDocumentView

/// 固定行高的只读正文，在背景上画出 Blame 段的分隔线与高亮。
final class FileTextDocumentView: NSTextView {
    /// 当前样式。
    private(set) var style: FileTextStyle?

    /// Blame 的注释；原文为 nil。
    var annotations: FileTextAnnotations?

    /// 右键菜单追加的动作。
    var menuActions: [FileViewAction] = []

    /// 第一行顶边离正文顶部的距离。
    var topInset: CGFloat { textContainerInset.height }

    /// 创建使用 TextKit 1 的只读正文：固定行高靠段落样式保证，行号按行号乘行高定位。
    static func make() -> FileTextDocumentView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
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
    func show(_ lines: [String], style: FileTextStyle) {
        self.style = style

        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = style.lineHeight
        paragraph.maximumLineHeight = style.lineHeight

        textStorage?.setAttributedString(NSAttributedString(
            string: lines.joined(separator: "\n"),
            attributes: [.font: style.font, .foregroundColor: style.text, .paragraphStyle: paragraph]
        ))
        backgroundColor = style.background
        insertionPointColor = style.text
        selectedTextAttributes = [.backgroundColor: style.selection]
        enclosingScrollView?.backgroundColor = style.background
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

    /// 在系统的复制等菜单项之后追加文件动作。
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        guard !menuActions.isEmpty else {
            return menu
        }

        menu.addItem(.separator())

        for action in menuActions {
            menu.addItem(FileViewMenuItem(action))
        }

        return menu
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

// MARK: - FileGutterView

/// 行号栏与 Blame 注释栏，随正文纵向滚动，不随横向滚动。
final class FileGutterView: NSRulerView {
    /// 注释栏的宽度。
    static let annotationWidth: CGFloat = 250

    /// 行号四周的内边距。
    private static let padding: CGFloat = 10

    /// 注释文字的字号。
    private static let annotationFontSize: CGFloat = 11

    /// 单击注释：段的序号、注释所在的矩形与所在视图。
    var clicked: ((Int, NSRect, NSView) -> Void)?

    /// 双击注释：段的序号。
    var doubleClicked: ((Int) -> Void)?

    /// 对应的正文。
    private weak var document: FileTextDocumentView?

    /// 正文的行数。
    private var lineCount = 0

    /// Blame 的注释；原文为 nil。
    private var annotations: FileTextAnnotations?

    /// 标尺只画行号与注释，没有刻度与标记区。
    override var requiredThickness: CGFloat { ruleThickness }

    /// 正文与标尺使用同样的翻转坐标。
    override var isFlipped: Bool { true }

    /// 行号栏的宽度随行数的位数变化。
    private var lineNumberWidth: CGFloat {
        guard let style = document?.style else {
            return 0
        }

        let digits = CGFloat(max(String(lineCount).count, 2))
        let digit = NSAttributedString(string: "8", attributes: [.font: style.font]).size().width

        return (digits * digit).rounded(.up) + Self.padding * 2
    }

    /// 绑定正文；滚动时重绘。
    init(scrollView: NSScrollView, document: FileTextDocumentView) {
        self.document = document
        super.init(scrollView: scrollView, orientation: .verticalRuler)

        clientView = document
        reservedThicknessForMarkers = 0
        reservedThicknessForAccessoryView = 0

        // 标尺只在自己的范围内绘制，不画到正文上方的头部里
        clipsToBounds = true

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipViewScrolled),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    /// 视图由代码构建。
    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("FileGutterView 不从归档恢复")
    }

    /// 行数或注释变化后重新计算宽度并重绘。
    func update(lineCount: Int, annotations: FileTextAnnotations?) {
        self.lineCount = lineCount
        self.annotations = annotations

        let thickness = (annotations == nil ? 0 : Self.annotationWidth) + lineNumberWidth

        if ruleThickness != thickness {
            ruleThickness = thickness
        }

        needsDisplay = true
    }

    /// 只画可见范围内的行号与注释。
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let document, let style = document.style, style.lineHeight > 0 else {
            return
        }

        style.background.setFill()
        bounds.fill()

        let annotationWidth = annotations == nil ? 0 : Self.annotationWidth
        let visible = convert(rect, to: document)

        if let annotations {
            drawAnnotations(annotations, in: visible, style: style)
        }

        drawLineNumbers(in: visible, x: annotationWidth, style: style)
    }

    /// 单击注释弹出提交摘要，双击回到对应的提交。
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        guard
            let document, let style = document.style, style.lineHeight > 0,
            let annotations, point.x < Self.annotationWidth
        else {
            super.mouseDown(with: event)

            return
        }

        // 换算到正文坐标，得到点中的行与段
        let y = convert(point, to: document).y
        let line = Int(((y - document.topInset) / style.lineHeight).rounded(.down)) + 1

        guard line <= lineCount, let index = annotations.groupIndex(containing: line) else {
            return
        }

        if event.clickCount >= 2 {
            doubleClicked?(index)
        } else {
            clicked?(index, annotationRect(of: annotations.groups[index], style: style), self)
        }
    }

    /// 正文滚动后标尺跟着重绘。
    @objc
    private func clipViewScrolled() {
        needsDisplay = true
    }

    /// 段第一行在注释栏中的矩形。
    private func annotationRect(of group: BlameGroup, style: FileTextStyle) -> NSRect {
        let top = convert(NSPoint(x: 0, y: document?.lineTop(group.firstLine - 1) ?? 0), from: document).y
        return NSRect(x: 0, y: top, width: Self.annotationWidth, height: style.lineHeight)
    }

    /// 画出可见的段：高亮底色、段之间的分隔线，以及第一行的标题、作者与日期。
    private func drawAnnotations(_ annotations: FileTextAnnotations, in visible: NSRect, style: FileTextStyle) {
        guard let document else {
            return
        }

        for index in document.visibleGroups(in: visible, annotations: annotations) {
            let group = annotations.groups[index]
            let rect = annotationRect(of: group, style: style)
            let height = CGFloat(group.lineCount) * style.lineHeight

            if group.commitID == annotations.highlightedCommit {
                style.highlight.setFill()
                NSRect(x: 0, y: rect.minY, width: bounds.width, height: height).fill()
            }

            if index > 0 {
                style.separator.setFill()
                NSRect(x: 0, y: rect.minY, width: bounds.width, height: 1).fill()
            }

            if let commit = annotations.commits[group.commitID] {
                drawAnnotation(commit, in: rect, style: style)
            }
        }

        // 注释栏与行号栏之间的竖线
        style.separator.setFill()
        NSRect(x: Self.annotationWidth - 1, y: bounds.minY, width: 1, height: bounds.height).fill()
    }

    /// 一行注释：标题靠左并按宽度截断，作者与日期靠右。
    private func drawAnnotation(_ commit: BlameCommit, in rect: NSRect, style: FileTextStyle) {
        let font = NSFont.systemFont(ofSize: Self.annotationFontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail

        let detail = NSAttributedString(
            string: commit.author + "  " + commit.authorDate.formatted(date: .abbreviated, time: .omitted),
            attributes: [.font: font, .foregroundColor: style.secondary, .paragraphStyle: paragraph]
        )
        let title = NSAttributedString(
            string: commit.summary,
            attributes: [.font: font, .foregroundColor: style.text, .paragraphStyle: paragraph]
        )

        // 文字在第一行里垂直居中；作者与日期最多占一半宽度
        let textHeight = (font.ascender - font.descender).rounded(.up)
        let y = rect.minY + (rect.height - textHeight) / 2
        let detailWidth = min(detail.size().width.rounded(.up), (rect.width - 8) / 2)
        detail.draw(
            with: NSRect(x: rect.maxX - 6 - detailWidth, y: y, width: detailWidth, height: textHeight),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
        title.draw(
            with: NSRect(x: rect.minX + 6, y: y, width: rect.width - detailWidth - 18, height: textHeight),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
    }

    /// 画出可见行的行号，右对齐，与正文共用字体与行高。
    private func drawLineNumbers(in visible: NSRect, x: CGFloat, style: FileTextStyle) {
        guard let document, lineCount > 0 else {
            return
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.minimumLineHeight = style.lineHeight
        paragraph.maximumLineHeight = style.lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.font,
            .foregroundColor: style.secondary,
            .paragraphStyle: paragraph,
        ]
        let first = max(Int(((visible.minY - document.topInset) / style.lineHeight).rounded(.down)), 0)
        let last = min(Int(((visible.maxY - document.topInset) / style.lineHeight).rounded(.up)), lineCount - 1)

        guard first <= last else {
            return
        }

        for index in first ... last {
            let top = convert(NSPoint(x: 0, y: document.lineTop(index)), from: document).y

            NSAttributedString(string: String(index + 1), attributes: attributes).draw(
                with: NSRect(
                    x: x + Self.padding,
                    y: top,
                    width: lineNumberWidth - Self.padding * 2,
                    height: style.lineHeight
                ),
                options: .usesLineFragmentOrigin
            )
        }
    }
}

// MARK: - BlameCommitPopover

/// 单击 Blame 注释弹出的提交摘要：哈希、作者、日期与标题。
private struct BlameCommitPopover: View {
    /// 注释对应的提交。
    let commit: BlameCommit

    /// 上一行哈希与作者、日期，下一行可选中的标题。
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(commit.shortID)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)

                Spacer(minLength: 0)

                Text(commit.author + "  " + commit.authorDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
            }
            .foregroundStyle(.tertiary)

            Text(commit.summary)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 335, alignment: .leading)
    }
}
