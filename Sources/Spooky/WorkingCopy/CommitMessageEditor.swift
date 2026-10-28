import AppKit
import SpookyKit
import SwiftUI

// MARK: - CommitMessageTextView

/// 提交标题与正文共用的文本视图：占位文字、超出字数的警告底色、提交哈希的胶囊、硬折行的参考线与段落重排。
final class CommitMessageTextView: NSTextView {
    /// 内容为空时显示的占位文字，可以有多行。
    var placeholder = "" {
        didSet { needsDisplay = true }
    }

    /// 每行的字数上限：超出部分铺警告底色，硬折行时超长的行整行铺底色、参考线画在这一列；nil 表示不检查。
    var characterLimit: Int? {
        didSet { updateHighlights() }
    }

    /// 硬折行只改显示：文字不折行、可以横向滚动，超长的行整行铺警告底色；关闭时按视图宽度折行。
    var hardWrap = false {
        didSet {
            guard hardWrap != oldValue else { return }

            updateWrapping()
            updateHighlights()
        }
    }

    /// 硬折行时是否画参考线与页外底色。
    var showsGuide = false {
        didSet { needsDisplay = true }
    }

    /// Reformat Paragraph 使用的字数上限；nil 表示这个视图不提供重排。
    var reformatLimit: Int?

    /// 最近提交的完整哈希；文字里与它们前缀相同的十六进制词画成蓝色胶囊。
    var knownCommits: [String] = [] {
        didSet { updateHighlights() }
    }

    /// 当前画成胶囊的文字范围。
    private var badgeRanges: [NSRange] = []

    /// 成为或失去第一响应者时通知外层。
    var onFocusChange: (Bool) -> Void = { _ in }

    /// 获得焦点后通知外层，用于展开提交区与 ⌘↩ 的判断。
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()

        if accepted { onFocusChange(true) }

        return accepted
    }

    /// 失去焦点后通知外层。
    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()

        if accepted { onFocusChange(false) }

        return accepted
    }

    /// 视图宽度变化时，硬折行的文字区仍至少铺满可见区域。
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        updateMinimumWidth()
    }

    /// 文字改变后重新标出超出字数的部分。
    override func didChangeText() {
        super.didChangeText()

        updateHighlights()
    }

    /// 内容为空时在文字起点画占位文字。
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholder.isEmpty else { return }

        // 占位文字与正文一样在文字区宽度内折行。
        let padding = textContainer?.lineFragmentPadding ?? 0
        let width = min(textContainer?.size.width ?? bounds.width, bounds.width - textContainerOrigin.x * 2)
        let area = NSRect(
            x: textContainerOrigin.x + padding,
            y: textContainerOrigin.y,
            width: max(0, width - padding * 2),
            height: bounds.height
        )
        NSAttributedString(string: placeholder, attributes: [
            .font: font ?? .systemFont(ofSize: 13),
            .foregroundColor: NSColor.placeholderTextColor,
        ])
        .draw(with: area, options: [.usesLineFragmentOrigin])
    }

    /// 硬折行时参考线右侧铺页外底色、参考线用分隔线颜色；提交哈希的胶囊画在这些底色之上。
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        if showsGuide, let x = guideX {
            AppPalette.nsColor("text_view_off_page_background_color").setFill()
            NSRect(x: x, y: rect.minY, width: max(0, bounds.maxX - x), height: rect.height).fill()
            NSColor.separatorColor.setFill()
            NSRect(x: x, y: rect.minY, width: 1, height: rect.height).fill()
        }

        drawBadges()
    }

    /// Edit › Reformat Paragraph：把光标所在段落按字数上限断行；作为一次编辑，可以撤销。
    @objc
    func reformatParagraph(_: Any?) {
        let text = string
        guard let reformatLimit, isEditable, let selection = Range(selectedRange(), in: text) else { return }

        // 段落是光标所在的整行，末尾的换行不参与重排。
        var lines = text.lineRange(for: selection)
        if text[lines].hasSuffix("\n") {
            lines = lines.lowerBound ..< text.index(before: lines.upperBound)
        }

        let original = String(text[lines])
        let wrapped = CommitMessage.hardWrapped(original, limit: reformatLimit)
        let range = NSRange(lines, in: text)
        guard wrapped != original, shouldChangeText(in: range, replacementString: wrapped) else { return }

        replaceCharacters(in: range, with: wrapped)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + wrapped.utf16.count, length: 0))
    }

    /// 只有提供重排的可编辑视图启用 Reformat Paragraph。
    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(reformatParagraph(_:)) {
            return reformatLimit != nil && isEditable
        }

        return super.validateUserInterfaceItem(item)
    }
}

// MARK: - Layout

extension CommitMessageTextView {
    /// 等宽字体下一列的宽度。
    private var columnWidth: CGFloat {
        let font = font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
        return NSAttributedString(string: "0", attributes: [.font: font]).size().width
    }

    /// 硬折行时参考线的横坐标。
    private var guideX: CGFloat? {
        guard hardWrap, let characterLimit else { return nil }

        return textContainerOrigin.x + (textContainer?.lineFragmentPadding ?? 0) + CGFloat(characterLimit) * columnWidth
    }

    /// 硬折行时文字区不折行、可以横向滚动；软折行时回到可见宽度，跟随视图宽度折行。只作用于正文。
    private func updateWrapping() {
        guard let textContainer, isVerticallyResizable else { return }

        let visible = enclosingScrollView?.contentSize.width ?? bounds.width

        isHorizontallyResizable = hardWrap
        enclosingScrollView?.hasHorizontalScroller = hardWrap
        textContainer.widthTracksTextView = !hardWrap
        textContainer.size = NSSize(width: hardWrap ? .greatestFiniteMagnitude : visible, height: .greatestFiniteMagnitude)

        if !hardWrap {
            setFrameSize(NSSize(width: visible, height: frame.height))
        }

        updateMinimumWidth()
        needsDisplay = true
    }

    /// 硬折行时文字区至少与可见区域一样宽，参考线右侧的底色铺满可见区域。
    private func updateMinimumWidth() {
        let width = hardWrap ? enclosingScrollView?.contentSize.width ?? 0 : 0

        if minSize.width != width {
            minSize = NSSize(width: width, height: minSize.height)
        }
    }

    /// 重新标注每行超出字数上限的部分与提交哈希；用临时属性，不进入撤销记录与内容。
    private func updateHighlights() {
        guard let layoutManager else { return }

        let text = string
        let full = NSRange(text.startIndex..., in: text)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)

        if let characterLimit {
            markExcess(in: text, limit: characterLimit, layoutManager: layoutManager)
        }

        // 与最近提交前缀相同的十六进制词画成胶囊，文字改用胶囊上的颜色。
        badgeRanges = text.ranges(of: #/\b[0-9a-fA-F]{7,64}\b/#)
            .filter { range in knownCommits.contains { $0.hasPrefix(text[range].lowercased()) } }
            .map { NSRange($0, in: text) }

        for range in badgeRanges {
            layoutManager.addTemporaryAttribute(
                .foregroundColor,
                value: AppPalette.nsColor("light_blue_badge_text_color"),
                forCharacterRange: range
            )
        }

        needsDisplay = true
    }

    /// 每行超出字数上限的部分铺警告底色，硬折行时超长的行整行铺底色；上限按字符计，换算成文本视图使用的 UTF-16 范围再标注。
    private func markExcess(in text: String, limit: Int, layoutManager: NSLayoutManager) {
        let color = AppPalette.nsColor("text_view_warning_background_color")
        let wholeLine = hardWrap

        text.enumerateSubstrings(in: text.startIndex..., options: .byLines) { line, lines, _, _ in
            guard let line, line.count > limit else { return }

            let marked = wholeLine ? lines : text.index(lines.lowerBound, offsetBy: limit) ..< lines.upperBound
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: NSRange(marked, in: text))
        }
    }

    /// 胶囊按文字所在的行片段绘制，跨行的哈希分成几段。
    private func drawBadges() {
        guard let layoutManager, let textContainer, !badgeRanges.isEmpty else { return }

        AppPalette.nsColor("light_blue_badge_background_color").setFill()

        for range in badgeRanges {
            let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphs,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textContainer
            ) { rect, _ in
                let frame = rect.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)
                NSBezierPath(roundedRect: frame.insetBy(dx: -2, dy: 0), xRadius: 4, yRadius: 4).fill()
            }
        }
    }
}

// MARK: - CommitMessageEditor

/// 提交标题或正文的 AppKit 文本视图，内容、焦点与补全同步到 SwiftUI。
struct CommitMessageEditor: NSViewRepresentable {
    /// 编辑器的用途。
    enum Role {
        /// 单行标题：回车或 Tab 转到正文，识别 fixup / squash 前缀。
        case subject

        /// 多行正文。
        case body
    }

    /// 标题或正文。
    let role: Role

    /// 编辑的文字。
    @Binding
    var text: String

    /// 占位文字。
    let placeholder: String

    /// 写入、快速修补或继续序列期间只读。
    let isEditable: Bool

    /// 硬折行时使用等宽字体。
    let monospaced: Bool

    /// 每行字数上限，超出部分铺警告底色。
    let characterLimit: Int?

    /// Reformat Paragraph 使用的字数上限；nil 表示不提供重排。
    let reformatLimit: Int?

    /// 硬折行：只改显示，文字不折行，超长的行整行铺警告底色；只用于正文。
    let hardWrap: Bool

    /// 硬折行时是否画参考线。
    let showsGuide: Bool

    /// 数值变化时让本编辑器获得焦点。
    let focusRequest: Int

    /// 焦点变化。
    let onFocusChange: (Bool) -> Void

    /// 标题按回车或 Tab 时转到正文。
    let onSubmit: () -> Void

    /// 按补全查询读取候选。
    let completions: (CompletionTrigger) async -> [CommitCompletion]

    /// 视图移除时关闭补全弹窗。
    static func dismantleNSView(_: NSScrollView, coordinator: Coordinator) {
        coordinator.panel.close()
    }

    /// 创建与视图同生命周期的协调器。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 文本视图放在滚动视图里：标题不折行、随光标横向滚动且没有滚动条，正文纵向滚动。
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = role == .body
        scrollView.autohidesScrollers = true

        // 警告底色与胶囊依赖 NSLayoutManager 的临时属性，明确使用 TextKit 1。
        let textView = CommitMessageTextView(usingTextLayoutManager: false)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainer?.lineFragmentPadding = 4
        textView.textContainerInset = role == .subject ? NSSize(width: 6, height: 5) : NSSize(width: 6, height: 7)
        textView.autoresizingMask = [.width]

        if role == .subject {
            textView.isHorizontallyResizable = true
            textView.isVerticallyResizable = false
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 24)
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 24)
            textView.textContainer?.maximumNumberOfLines = 1
            textView.setAccessibilityIdentifier("commit-subject")
        } else {
            textView.isVerticallyResizable = true
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.setAccessibilityIdentifier("commit-body")
        }

        textView.setAccessibilityLabel(placeholder.components(separatedBy: "\n").first)
        textView.onFocusChange = { focused in
            if !focused { context.coordinator.panel.close() }
            context.coordinator.parent.onFocusChange(focused)
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.loadKnownCommits()
        return scrollView
    }

    /// 同步内容、可编辑状态、字体、上限与焦点请求；内容相同时不重设，避免打断输入法与撤销。
    func updateNSView(_: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }

        // 程序写入的内容不经过代理回写，警告底色随后由上限的设置刷新。
        if textView.string != text {
            textView.string = text
        }

        let font: NSFont = monospaced ? .monospacedSystemFont(ofSize: 13, weight: .regular) : .systemFont(ofSize: 13)
        if textView.font != font { textView.font = font }

        textView.isEditable = isEditable
        textView.textColor = isEditable ? .textColor : .disabledControlTextColor
        textView.placeholder = placeholder
        textView.characterLimit = characterLimit
        textView.hardWrap = hardWrap
        textView.showsGuide = showsGuide && hardWrap
        textView.reformatLimit = reformatLimit

        if coordinator.focusRequest != focusRequest {
            coordinator.focusRequest = focusRequest
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
    }
}

// MARK: CommitMessageEditor.Coordinator

extension CommitMessageEditor {
    /// 文本视图的代理：回写内容、限制标题为单行、驱动补全弹窗。
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        /// 最近一次 SwiftUI 传入的配置。
        var parent: CommitMessageEditor

        /// 管理的文本视图。
        weak var textView: CommitMessageTextView?

        /// 已处理的焦点请求。
        var focusRequest: Int

        /// 补全弹窗。
        let panel = CommitCompletionPanel()

        /// 每次查询的序号，过期的结果不再显示。
        private var generation = 0

        /// 当前补全。
        private var trigger: CompletionTrigger?

        /// 记录初始配置；初始的焦点请求视为已处理。
        init(_ parent: CommitMessageEditor) {
            self.parent = parent
            focusRequest = parent.focusRequest
        }

        /// 内容变化回写绑定，并按光标位置更新补全。
        func textDidChange(_: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            updateCompletion()
        }

        /// 光标移动后补全可能不再成立。
        func textViewDidChangeSelection(_: Notification) {
            guard panel.isVisible else { return }
            updateCompletion()
        }

        /// 标题不接受换行：粘贴的多行文字合成一行。
        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn range: NSRange,
            replacementString string: String?
        ) -> Bool {
            guard parent.role == .subject, let string, string.contains(where: \.isNewline) else { return true }

            let line = string.split(whereSeparator: \.isNewline).joined(separator: " ")
            textView.insertText(line, replacementRange: range)
            return false
        }

        /// 补全弹窗优先处理按键；标题的回车与 Tab 转到正文。
        func textView(_: NSTextView, doCommandBy selector: Selector) -> Bool {
            if panel.handle(selector) {
                return true
            }

            guard parent.role == .subject else { return false }

            if
                [
                    #selector(NSResponder.insertNewline(_:)),
                    #selector(NSResponder.insertTab(_:)),
                    #selector(NSResponder.insertLineBreak(_:)),
                    #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
                ]
                    .contains(selector)
            {
                parent.onSubmit()
                return true
            }

            return false
        }
    }
}

// MARK: - Completion

extension CommitMessageEditor.Coordinator {
    /// 读取最近提交的哈希，文字里引用它们的地方画成胶囊。
    func loadKnownCommits() {
        let load = parent.completions

        Task { [weak self] in
            let items = await load(.commit(query: "", range: NSRange(location: 0, length: 0)))

            self?.textView?.knownCommits = items.compactMap {
                if case .commit(let commit) = $0.content { commit.id } else { nil }
            }
        }
    }

    /// 识别光标处的补全，读取候选后显示；不再成立时关闭弹窗。
    private func updateCompletion() {
        guard
            let textView, textView.isEditable, textView.window?.firstResponder === textView,
            textView.selectedRange().length == 0
        else {
            panel.close()
            return
        }

        let detected = CompletionTrigger.detect(
            in: textView.string,
            caret: textView.selectedRange().location,
            subject: parent.role == .subject,
            issues: CommitEditorSettings.completesIssues
        )
        trigger = detected
        generation += 1

        guard let detected else {
            panel.close()
            return
        }

        let request = generation
        let load = parent.completions

        Task { [weak self] in
            let items = await load(detected)

            // 输入已经继续或补全已取消时丢弃这次结果。
            guard let self, generation == request, let textView = self.textView else { return }

            panel.show(items, for: textView, at: detected.range.location) { [weak self] item in
                self?.accept(item)
            }
        }
    }

    /// 用选中的候选替换补全范围；作为一次输入，可以撤销。
    private func accept(_ item: CommitCompletion) {
        guard let textView, let trigger else { return }

        panel.close()
        self.trigger = nil
        textView.insertText(item.insertion, replacementRange: trigger.range)
    }
}
