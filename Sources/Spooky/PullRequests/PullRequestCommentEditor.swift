import AppKit
import SwiftUI

// MARK: - PullRequestCommentEditor

/// 评论的多行输入：可以滚动的 13 pt 纯文本，输入 `@` 时在光标下方列出能提及的用户。
struct PullRequestCommentEditor: NSViewRepresentable {
    /// 编辑的文字。
    @Binding
    var text: String

    /// 读屏时读出的标签。
    let label: String

    /// 按 `@` 之后的查询读取候选。
    let completions: (String) async -> [CommitCompletion]

    /// 视图移除时关闭补全弹窗。
    static func dismantleNSView(_: NSScrollView, coordinator: Coordinator) {
        coordinator.panel.close()
    }

    /// 创建与视图同生命周期的协调器。
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 纯文本视图，宽度随滚动区，长行折行，可以撤销。
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 13)
        textView.string = text
        textView.setAccessibilityLabel(label)

        context.coordinator.textView = textView
        return scrollView
    }

    /// 同步外面写入的文字；内容相同时不重设，避免打断输入法与撤销。
    func updateNSView(_: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        guard let textView = coordinator.textView, textView.string != text else {
            return
        }

        textView.string = text
    }
}

// MARK: PullRequestCommentEditor.Coordinator

extension PullRequestCommentEditor {
    /// 文本视图的代理：回写内容，驱动补全弹窗。
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        /// 最近一次 SwiftUI 传入的配置。
        var parent: PullRequestCommentEditor

        /// 管理的文本视图。
        weak var textView: NSTextView?

        /// 补全弹窗。
        let panel = CommitCompletionPanel()

        /// 每次查询的序号，过期的结果不再显示。
        private var generation = 0

        /// 光标处正在输入的提及。
        private var trigger: MentionCompletion.Trigger?

        /// 记录初始配置。
        init(_ parent: PullRequestCommentEditor) {
            self.parent = parent
        }

        /// 内容变化回写绑定，并按光标位置更新补全。
        func textDidChange(_: Notification) {
            guard let textView else {
                return
            }

            parent.text = textView.string
            updateCompletion()
        }

        /// 光标移动后补全可能不再成立。
        func textViewDidChangeSelection(_: Notification) {
            guard panel.isVisible else {
                return
            }

            updateCompletion()
        }

        /// 失去焦点时关闭弹窗，还没读完的候选作废。
        func textDidEndEditing(_: Notification) {
            generation += 1
            panel.close()
        }

        /// 补全弹窗显示时优先处理按键。
        func textView(_: NSTextView, doCommandBy selector: Selector) -> Bool {
            panel.handle(selector)
        }
    }
}

// MARK: - Completion

extension PullRequestCommentEditor.Coordinator {
    /// 识别光标处的提及，读取候选后显示；不再成立时关闭弹窗。
    private func updateCompletion() {
        generation += 1

        guard let textView, textView.selectedRange().length == 0 else {
            trigger = nil
            panel.close()
            return
        }

        trigger = MentionCompletion.detect(in: textView.string, caret: textView.selectedRange().location)

        guard let trigger else {
            panel.close()
            return
        }

        let request = generation
        let load = parent.completions

        Task { [weak self] in
            let items = await load(trigger.query)

            // 输入已经继续或焦点已离开时丢弃这次结果
            guard let self, generation == request, let textView = self.textView else {
                return
            }

            panel.show(items, for: textView, at: trigger.range.location) { [weak self] in
                self?.accept($0)
            }
        }
    }

    /// 用选中的候选替换提及的范围；作为一次输入，可以撤销。
    private func accept(_ item: CommitCompletion) {
        guard let textView, let trigger else {
            return
        }

        panel.close()
        self.trigger = nil
        textView.insertText(item.insertion, replacementRange: trigger.range)
    }
}
