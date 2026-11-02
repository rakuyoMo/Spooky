import AppKit
import SwiftUI

// MARK: - PullRequestMarkdownView

/// 评论与描述的正文：不能编辑、可以选中的文字区，按给出的宽度折行，高度随内容。
///
/// 用 TextKit 1 的 `NSTextView`：代码块、引用块与表格的框只在 TextKit 1 下排版。
/// 行片段边距与内边距都是 0，不画底色；右键是文字区自己的菜单，双击选中单词，链接交给系统打开。
struct PullRequestMarkdownView: NSViewRepresentable {
    /// 正文的 Markdown 原文。
    let text: String

    /// 记下文字区正在显示的原文。
    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 建立只读的文字区：宽度跟随视图，高度不限。
    func makeNSView(context _: Context) -> NSTextView {
        let view = NSTextView(usingTextLayoutManager: false)
        view.isEditable = false
        view.isSelectable = true
        view.allowsUndo = false
        view.drawsBackground = false
        view.usesFindBar = false
        view.usesFontPanel = false
        view.usesInspectorBar = false
        view.isContinuousSpellCheckingEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false

        // 尺寸由 SwiftUI 给出，文字区自己不改变大小
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.heightTracksTextView = false
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        return view
    }

    /// 原文变化时才换上新的文字，不打断已有的选区。
    func updateNSView(_ view: NSTextView, context: Context) {
        guard context.coordinator.text != text else {
            return
        }

        context.coordinator.text = text
        view.textStorage?.setAttributedString(PullRequestMarkdown.attributedString(text))
    }

    /// 按给出的宽度排版量出高度；没有给出宽度时交给 SwiftUI 决定。
    func sizeThatFits(_ proposal: ProposedViewSize, nsView _: NSTextView, context _: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else {
            return nil
        }

        let height = PullRequestMarkdown.height(of: PullRequestMarkdown.attributedString(text), width: width)
        return CGSize(width: width, height: height)
    }
}

// MARK: PullRequestMarkdownView.Coordinator

extension PullRequestMarkdownView {
    /// 文字区正在显示的原文，原文相同时不重设文字。
    @MainActor
    final class Coordinator {
        /// 上次设置的原文；还没设置时为 nil。
        var text: String? = nil
    }
}
