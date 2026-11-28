import AppKit
import SwiftUI

// MARK: - ScriptTextEditor

/// 输入脚本的多行文本框：12 pt 等宽字体，引号、破折号与文本替换都不自动改写，交给解释器的就是输入的字符。
struct ScriptTextEditor: NSViewRepresentable {
    /// 脚本的内容。
    @Binding
    var text: String

    /// 辅助功能读出的名称。
    let label: String

    /// 创建与视图同生命周期的协调器。
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    /// 可以纵向滚动、按宽度折行的文本视图。
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        // 系统默认打开智能引号等改写，脚本里的 " 会被换成弯引号
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false

        textView.textContainerInset = NSSize(width: 2, height: 4)
        textView.string = text
        textView.setAccessibilityLabel(label)

        return scrollView
    }

    /// 内容与绑定不同时才重设，避免打断输入法与撤销。
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text

        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else {
            return
        }

        textView.string = text
    }
}

// MARK: ScriptTextEditor.Coordinator

extension ScriptTextEditor {
    /// 把输入写回绑定。
    final class Coordinator: NSObject, NSTextViewDelegate {
        /// 脚本内容的绑定，随视图更新。
        var text: Binding<String>

        /// 以脚本内容的绑定创建协调器。
        ///
        /// - Parameter text: 脚本内容的绑定。
        init(text: Binding<String>) {
            self.text = text
        }

        /// 输入后写回绑定。
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text.wrappedValue = textView.string
        }
    }
}
