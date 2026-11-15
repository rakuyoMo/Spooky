import AppKit
import SwiftUI

// MARK: - BezelTextField

/// 高度固定、宽度按提议取的系统输入框。
///
/// SwiftUI 的 `TextField` 在 macOS 上按行数定高，不随给出的高度变高；需要输入框本身是某个高度时用它。
struct BezelTextField: NSViewRepresentable {
    /// 把输入与结束输入转给 SwiftUI。
    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        /// 最近一次更新时的输入框描述。
        var parent: BezelTextField

        /// 创建协调器。
        ///
        /// - Parameter parent: 输入框描述。
        init(parent: BezelTextField) {
            self.parent = parent
        }

        /// 每次输入都写回文字。
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }

            parent.text = field.stringValue
        }

        /// 回车或离开输入框时交出最终的文字。
        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }

            parent.onEndEditing(field.stringValue)
        }
    }

    /// 输入框里的文字。
    @Binding
    var text: String

    /// 辅助功能读出的名称。
    let label: String

    /// 文字的水平对齐。
    var alignment = NSTextAlignment.natural

    /// 输入框本身的高度，系统的边框画在这个高度之外；默认是单行输入框的 22 pt。
    var height: CGFloat = 22

    /// 是否按词折成多行；单行时文字超出宽度后横向滚动。
    var wraps = false

    /// 没有文字时显示的占位文字。
    var placeholder: String?

    /// 结束输入时调用。
    var onEndEditing: (String) -> Void = { _ in }

    /// 创建可编辑的系统输入框；折行时关掉单行模式与横向滚动。
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.alignment = alignment
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.setAccessibilityLabel(label)

        if wraps {
            field.usesSingleLineMode = false
            field.cell?.wraps = true
            field.cell?.isScrollable = false
            field.lineBreakMode = .byWordWrapping
        }

        return field
    }

    /// 跟随外部对文字的修改与可用状态，编辑中同样如此；输入法正在组字时不替换，组字的文字提交后写回绑定。
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = context.environment.isEnabled

        // 编辑中显示的是字段编辑器里的文字，直接比对它；打字写回的绑定与它相同，光标不动
        if let editor = field.currentEditor() as? NSTextView {
            guard !editor.hasMarkedText(), editor.string != text else {
                return
            }
        } else if field.stringValue == text {
            return
        }

        // 编辑中设置 `stringValue` 时，系统替换字段编辑器里的文字并清掉它的撤销记录，编辑继续、不发出结束输入；
        // 直接改字段编辑器的 `string` 会留下按旧文字记的撤销范围，之后撤销会越界
        field.stringValue = text
    }

    /// 宽度按提议，高度固定。
    func sizeThatFits(_ proposal: ProposedViewSize, nsView _: NSTextField, context _: Context) -> CGSize? {
        CGSize(width: proposal.replacingUnspecifiedDimensions().width, height: height)
    }

    /// 创建接收输入的协调器。
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
}
