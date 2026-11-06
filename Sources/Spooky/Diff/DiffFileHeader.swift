import AppKit
import SpookyKit
import SwiftUI

// MARK: - DiffFileHeader

/// 文件段顶部的可选择摘要，固定字体，不随正文主题变化。
struct DiffFileHeader: NSViewRepresentable {
    /// 摘要来自解析后的文件段。
    let file: DiffFile

    /// 原生文本区与分隔线共用一个容器。
    func makeNSView(context _: Context) -> DiffFileHeaderView { DiffFileHeaderView() }

    /// 只有摘要变化时重设文本，避免颜色或布局更新清空选区。
    func updateNSView(_ view: DiffFileHeaderView, context _: Context) {
        view.show(DiffSummary.text(for: file))
    }

    /// 按实际折行高度回传 SwiftUI，不追加块正文的末尾空片段。
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: DiffFileHeaderView, context _: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }

        return CGSize(width: width, height: nsView.measure(width: width))
    }
}

// MARK: - DiffFileHeaderView

/// 固定边距的摘要文本与底部分隔线，测量和绘制使用同一份 TextKit 栈。
final class DiffFileHeaderView: NSView {
    /// 固定 11 pt 等宽字体，独立于主题偏好。
    static var summaryFont: NSFont { .userFixedPitchFont(ofSize: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .regular) }

    /// 可选中、不可编辑的原生文本。
    let document: NSTextView

    /// 与文本一致的自上而下坐标。
    override var isFlipped: Bool { true }

    /// 建立不带滚动视图的 TextKit 1 文本区。
    init() {
        let storage = NSTextStorage()
        let manager = NSLayoutManager()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: 1, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        document = NSTextView(frame: .zero, textContainer: container)
        document.isEditable = false
        document.isSelectable = true
        document.isRichText = false
        document.drawsBackground = false
        document.usesFontPanel = false
        document.isHorizontallyResizable = false
        document.isVerticallyResizable = false
        document.textContainerInset = .zero
        super.init(frame: .zero)

        clipsToBounds = true
        document.clipsToBounds = true
        addSubview(document)
    }

    /// 摘要仅从代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("摘要视图仅从代码创建") }

    /// 段落最小行高按固定字体计算，行间距为 2 pt。
    func show(_ text: String) {
        guard document.string != text else { return }

        let font = Self.summaryFont
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = (font.ascender - font.descender + 4).rounded()
        paragraph.lineSpacing = 2
        document.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]))
        needsLayout = true
    }

    /// TextKit 的末行没有额外行间距；上下 8 pt，底部另留 4 pt。
    func measure(width: CGFloat) -> CGFloat {
        guard let manager = document.layoutManager, let container = document.textContainer else { return 20 }

        container.containerSize = CGSize(width: max(1, width - 40), height: CGFloat.greatestFiniteMagnitude)
        manager.ensureLayout(for: container)
        let height = document.string.isEmpty ? 0 : manager.usedRect(for: container).height
        return ceil(height + 20)
    }

    /// 左右 20 pt，文本上边距 8 pt；底线铺满整个文件头。
    override func layout() {
        super.layout()

        let height = measure(width: bounds.width)
        document.frame = CGRect(x: 20, y: 8, width: max(1, bounds.width - 40), height: max(0, height - 20))
    }

    /// 摘要没有背景，仅在底部绘制 1 pt 系统分隔线。
    override func draw(_: NSRect) {
        NSColor.separatorColor.setFill()
        CGRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
    }
}
