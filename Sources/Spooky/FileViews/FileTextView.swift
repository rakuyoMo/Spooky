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
    /// 主题字体。
    let font: NSFont

    /// 固定行高，行号与注释按它和正文对齐：原文是主题字体的默认行高，Blame 另加 10 pt。
    let lineHeight: CGFloat

    /// 每行文字下方留的空白：Blame 把多出的高度上下各分一半，文字在行里竖直居中；原文为 0。
    let lineSpacing: CGFloat

    /// 正文颜色。
    let text: NSColor

    /// 正文、行号与注释共用的背景色。
    let background: NSColor

    /// 行号与注释中作者、日期的颜色：正文色向背景方向调淡。
    let secondary: NSColor

    /// 一起高亮的段的底色：背景色略微加深或提亮。
    let highlight: NSColor

    /// Blame 注释栏的底色：背景色略微提亮或加深，与正文区分。
    let annotationBackground: NSColor

    /// 注释栏里一起高亮的段的底色：比注释栏的底色再提亮或加深一些。
    let annotationHighlight: NSColor

    /// 段之间的分隔线颜色。
    let separator: NSColor

    /// 选中文本的底色。
    let selection: NSColor

    /// 按主题计算全部样式。
    ///
    /// - Parameters:
    ///   - theme: 文本主题。
    ///   - blame: 是否用 Blame 的行高。
    init(theme: TextTheme, blame: Bool = false) {
        font = NSFont(name: theme.fontName, size: theme.fontSize)
            ?? .monospacedSystemFont(ofSize: theme.fontSize, weight: .regular)

        // Blame 每行多出 10 pt，上下各留一半
        let natural = NSLayoutManager().defaultLineHeight(for: font).rounded()
        lineHeight = blame ? natural + 10 : natural
        lineSpacing = blame ? 5 : 0

        text = theme.colors["text"]?.calibratedNSColor ?? .textColor
        background = theme.colors["background"]?.calibratedNSColor ?? .textBackgroundColor
        selection = theme.colors["selection"]?.calibratedNSColor ?? .selectedTextBackgroundColor

        // 推导色取主题原始分量的 sRGB 表示，深色调亮、浅色调暗
        let sourceText = theme.colors["text"]?.nsColor ?? .textColor
        let sourceBackground = theme.colors["background"]?.nsColor ?? .textBackgroundColor
        secondary = Self.shifted(sourceText, by: Self.isDark(sourceText) ? 0.2 : -0.2)
        highlight = Self.shifted(sourceBackground, by: Self.isDark(sourceBackground) ? 0.1 : -0.1)
        separator = Self.shifted(sourceBackground, by: Self.isDark(sourceBackground) ? 0.2 : -0.2)
        annotationBackground = Self.shifted(sourceBackground, by: Self.isDark(sourceBackground) ? 0.09 : -0.08)
        annotationHighlight = Self.shifted(sourceBackground, by: Self.isDark(sourceBackground) ? 0.17 : -0.16)
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

/// 只读、可选中、不折行的文件正文，左侧是行号栏；Blame 时正文右边再加一列按段对齐的注释。
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

        /// 已应用的完整主题、Tab 宽度与不可见字符设置。
        var rendering: TextStyle?

        /// 已着色的内容身份与是否着色；变化时重新着色。
        var syntaxKey: String?

        /// 当前内容的语法片段，与行一一对应；不着色或识别不了语言时为空。
        var spans: [[SyntaxSpan]]?

        /// 后台着色任务，内容变化时取消。
        var syntaxTask: Task<Void, Never>?

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
            popover.show(relativeTo: rect, of: view, preferredEdge: .minX)
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

    /// 文件在仓库里的路径，按它识别语法着色的语言。
    let path: String

    /// 各行原文。
    let lines: [String]

    /// 已读 blob 的完整源串，决定末行 LF 与复制内容。
    let source: String

    /// 当前文本主题。
    let theme: TextTheme

    /// Blame 的注释；原文为 nil。
    var annotations: FileTextAnnotations? = nil

    /// 单击注释时高亮的提交。
    var highlight: ((String) -> Void)? = nil

    /// 双击注释时回到的提交。
    var openCommit: ((String) -> Void)? = nil

    /// 语法着色总开关。
    @AppStorage(TextPreferences.syntaxColoringKey)
    private var colorsSyntax = true

    /// 一个制表符占的空格数。
    @AppStorage(TextPreferences.tabWidthKey)
    private var tabWidth = TextPreferences.defaultTabWidth

    /// 标出不可见字符。
    @AppStorage(TextPreferences.showsInvisiblesKey)
    private var showsInvisibles = false

    /// 建立桥接。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 正文、行号栏与注释栏的容器；注释的单击与双击交给桥接。
    func makeNSView(context: Context) -> FileTextContainerView {
        let container = FileTextContainerView()

        container.annotationView.clicked = { [weak coordinator = context.coordinator] index, rect, view in
            coordinator?.annotationClicked(index, rect: rect, in: view)
        }

        container.annotationView.doubleClicked = { [weak coordinator = context.coordinator] in
            coordinator?.annotationDoubleClicked($0)
        }

        return container
    }

    /// 内容身份或主题变化时替换正文，其余变化只重绘高亮与注释。
    func updateNSView(_ container: FileTextContainerView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        guard let document = container.document, let gutter = container.gutter else {
            return
        }

        let style = FileTextStyle(theme: theme, blame: annotations != nil)
        let rendering = TextStyle(theme: theme, tabWidth: tabWidth, showsInvisibles: showsInvisibles)
        let replaced = coordinator.contentID != contentID

        // 内容换了就丢掉上一份语法片段，着色完成后再补上颜色
        if replaced {
            coordinator.spans = nil
        }

        if replaced || coordinator.style != style || coordinator.rendering != rendering {
            document.show(lines, source: source, style: style, rendering: rendering, spans: coordinator.spans)
            coordinator.contentID = contentID
            coordinator.style = style
            coordinator.rendering = rendering
        }

        if replaced {
            coordinator.popover?.close()
            document.scroll(.zero)
        }

        highlight(in: document, style: style, rendering: rendering, coordinator: coordinator)

        document.annotations = annotations
        gutter.update(lineCount: lines.count)
        document.needsDisplay = true

        // 原文没有注释栏
        container.annotationView.update(annotations: annotations)

        if container.annotationView.isHidden != (annotations == nil) {
            container.annotationView.isHidden = annotations == nil
            container.needsLayout = true
        }
    }
}

// MARK: - Syntax

extension FileTextView {
    /// 内容或着色开关变化时在后台重新着色；内容超过大 Diff 警告阈值时不着色，按纯文本显示。
    private func highlight(
        in document: FileTextDocumentView,
        style: FileTextStyle,
        rendering: TextStyle,
        coordinator: Coordinator
    ) {
        let key = contentID + "\u{0}" + String(colorsSyntax)

        guard coordinator.syntaxKey != key else {
            return
        }

        coordinator.syntaxKey = key
        coordinator.syntaxTask?.cancel()

        // 关掉着色时立即恢复纯文本
        guard colorsSyntax else {
            if coordinator.spans != nil {
                coordinator.spans = nil
                document.show(lines, source: source, style: style, rendering: rendering, spans: nil)
            }

            return
        }

        let lines = lines
        let source = source
        let path = path
        let text = lines.joined(separator: "\n")

        guard text.utf8.count <= RepositorySession.diffWarningBytes else {
            return
        }

        coordinator.syntaxTask = Task { [weak coordinator, weak document] in
            var spans: [[SyntaxSpan]]?

            // 识别与着色借用 highlight.js 的上下文完成；内容或开关变化时任务取消，尚未开始的着色直接跳过
            if let language = await SyntaxHighlighter.language(forPath: path, content: text) {
                spans = await SyntaxHighlighter.highlight(text, as: language)
            }

            // 着色期间内容或开关又变了，结果作废
            guard
                let coordinator, let document, let spans,
                coordinator.syntaxKey == key, !Task.isCancelled,
                let style = coordinator.style
            else { return }

            coordinator.spans = spans
            document.show(lines, source: source, style: style, rendering: document.rendering ?? rendering, spans: spans)
        }
    }
}

// MARK: - FileTextContainerView

/// 正文的滚动视图与右边的 Blame 注释栏；原文时注释栏隐藏，正文占满。
final class FileTextContainerView: NSView {
    /// 带行号栏的正文滚动视图。
    let scrollView: NSScrollView

    /// 正文右边的注释栏。
    let annotationView: FileAnnotationView

    /// 正文。
    var document: FileTextDocumentView? { scrollView.documentView as? FileTextDocumentView }

    /// 行号栏。
    var gutter: FileGutterView? { scrollView.verticalRulerView as? FileGutterView }

    /// 创建正文、行号栏与注释栏。
    init() {
        let document = FileTextDocumentView.make()
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = document

        scrollView.verticalRulerView = FileGutterView(scrollView: scrollView, document: document)
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        annotationView = FileAnnotationView(scrollView: scrollView, document: document)
        super.init(frame: .zero)

        addSubview(scrollView)
        addSubview(annotationView)

        annotationView.widthChanged = { [weak self] in
            self?.needsLayout = true
        }
    }

    /// 视图由代码构建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("FileTextContainerView 不从归档恢复")
    }

    /// 有注释时注释栏贴右边，正文让出它的宽度。
    override func layout() {
        super.layout()

        let annotationWidth = annotationView.isHidden ? 0 : min(annotationView.width, bounds.width)

        scrollView.frame = NSRect(x: 0, y: 0, width: bounds.width - annotationWidth, height: bounds.height)
        annotationView.frame = NSRect(
            x: bounds.width - annotationWidth,
            y: 0,
            width: annotationWidth,
            height: bounds.height
        )

        window?.invalidateCursorRects(for: annotationView)
    }
}

// MARK: - FileGutterView

/// 行号栏，随正文纵向滚动，不随横向滚动。
final class FileGutterView: NSRulerView {
    /// 行号四周的内边距。
    private static let padding: CGFloat = 10

    /// 对应的正文。
    private weak var document: FileTextDocumentView?

    /// 正文的行数。
    private var lineCount = 0

    /// 标尺只画行号，没有刻度与标记区。
    override var requiredThickness: CGFloat { ruleThickness }

    /// 正文与标尺使用同样的翻转坐标。
    override var isFlipped: Bool { true }

    /// 行号栏的宽度：最大行号的文字宽度加两侧内边距，随行数的位数变化。
    private var lineNumberWidth: CGFloat {
        guard let style = document?.style else {
            return 0
        }

        let largest = NSAttributedString(string: String(lineCount), attributes: [.font: style.font])

        return largest.size().width.rounded(.up) + Self.padding * 2
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

    /// 行数变化后重新计算宽度并重绘。
    func update(lineCount: Int) {
        self.lineCount = lineCount

        if ruleThickness != lineNumberWidth {
            ruleThickness = lineNumberWidth
        }

        needsDisplay = true
    }

    /// 只画可见范围内的行号。
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let document, let style = document.style, style.lineHeight > 0 else {
            return
        }

        style.background.setFill()
        bounds.fill()

        drawLineNumbers(in: convert(rect, to: document), style: style)
    }

    /// 正文滚动后标尺跟着重绘。
    @objc
    private func clipViewScrolled() {
        needsDisplay = true
    }

    /// 画出可见行的行号，右对齐，与正文共用字体、行高与文字的竖直位置。
    private func drawLineNumbers(in visible: NSRect, style: FileTextStyle) {
        guard let document, lineCount > 0 else {
            return
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.minimumLineHeight = style.lineHeight - style.lineSpacing
        paragraph.maximumLineHeight = style.lineHeight - style.lineSpacing

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
                    x: Self.padding,
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

/// 单击 Blame 注释弹出的提交摘要：左边 64 pt 的头像，右边哈希、作者、日期与标题四行。
private struct BlameCommitPopover: View {
    /// 注释对应的提交。
    let commit: BlameCommit

    /// 四行都是 13 pt 的系统字体，标题超过 311 pt 换行。
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 64)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 4) {
                row("blame.hash", commit.shortID)
                row("blame.author", commit.author + " <" + commit.authorEmail + ">")
                row("blame.date", commit.authorDate.formatted(date: .abbreviated, time: .shortened))
                row("blame.subject", commit.summary)
            }
            .font(.system(size: 13))
        }
        .padding(12)
        .frame(width: 423, alignment: .leading)
    }

    /// 一行：右对齐的次要色标签，后面是可选中的值。
    private func row(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(AppLocalization.text(key))
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)

            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: 311, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
