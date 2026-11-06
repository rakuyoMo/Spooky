import AppKit

// MARK: - DiffTextDocumentView

/// 一个块内可跨行选择的原生文字区；复制恢复源字符，绘制不侵入行号栏。
final class DiffTextDocumentView: NSTextView {
    /// 持有内容与布局的块容器。
    weak var owner: DiffHunkTextContainer?

    /// 复制只提供原始纯文本，不能把显示标记作为富文本导出。
    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] { [.string] }

    /// 构造可折行的 TextKit 1 正文，尺寸由块容器控制。
    static func make() -> DiffTextDocumentView {
        let storage = NSTextStorage()
        let manager = TextInvisibleLayoutManager()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: 1, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        let view = DiffTextDocumentView(frame: .zero, textContainer: container)
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.allowsUndo = false
        view.usesFindBar = false
        view.usesFontPanel = false
        view.usesInspectorBar = false
        view.isContinuousSpellCheckingEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = false
        view.textContainerInset = CGSize(width: 4, height: 0)
        return view
    }

    /// 原生 Copy 和右键复制共用这个入口，只写入实际选区映射到的原文。
    override func writeSelection(to pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == .string, let content = owner?.content, selectedRange().length > 0 else {
            return false
        }

        return pasteboard.setString(content.copiedText(in: selectedRange()), forType: .string)
    }

    /// 改动底色与连续改动边线只画在正文上，末尾空片段保持主题背景。
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        guard let owner, let content = owner.content, let layout = owner.textLayout, let style = owner.style else {
            return
        }

        for item in layout.rows(intersecting: rect) {
            let row = content.rows[item.index].line
            let key = row.prefix == 43 ? "added" : (row.prefix == 45 ? "deleted" : "")
            guard let color = style.theme.colors[key] else { continue }

            let area = CGRect(x: 0, y: item.rect.minY, width: bounds.width, height: item.rect.height)
            owner.backgroundColor(for: row)?.setFill()
            area.fill()
            PaletteColor(hex: color.hex, alpha: min(1, color.alpha + 0.25)).nsColor.setFill()
            let before = item.index > 0 ? content.rows[item.index - 1].line.prefix : nil
            let after = item.index + 1 < content.rows.count ? content.rows[item.index + 1].line.prefix : nil

            if before != row.prefix {
                CGRect(x: 0, y: area.minY, width: area.width, height: 1).fill()
            }

            if after != row.prefix {
                CGRect(x: 0, y: area.maxY - 1, width: area.width, height: 1).fill()
            }
        }
    }
}
