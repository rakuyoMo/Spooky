import AppKit
import SwiftUI

// MARK: - SettingsTextField

/// 设置页的单行输入框：可见边框就是 24 pt 高的布局框，相邻两个输入框的可见间隔等于给出的行距。
///
/// 系统输入框的边框画在视图外 1 pt，所以视图取 22 pt 高、上下各让出 1 pt，边框正好落在布局框上。
/// SwiftUI 的 `TextField` 固定 24 pt 高，边框会伸出布局框，相邻输入框之间的可见间隔比行距小 2 pt。
struct SettingsTextField: View {
    /// 画在视图外的边框宽度：系统输入框在可见边框里上下左右各收这么多。
    static let bezelOutset: CGFloat = 1

    /// 输入框里的文字：随输入更新；外部改了它时，编辑中的输入框同样跟着显示。
    @Binding
    var text: String

    /// 辅助功能读出的名称。
    let label: String

    /// 文字的水平对齐。
    var alignment = NSTextAlignment.natural

    /// 结束输入（回车或离开输入框）时调用，参数是输入框里的文字。
    var onEndEditing: (String) -> Void = { _ in }

    /// 22 pt 高的系统输入框，上下各留出边框的宽度。
    var body: some View {
        BezelTextField(
            text: $text,
            label: label,
            alignment: alignment,
            onEndEditing: onEndEditing
        )
        .padding(.vertical, Self.bezelOutset)
    }
}

// MARK: - BezelTextField

/// 22 pt 高、宽度按提议取的系统输入框。
private struct BezelTextField: NSViewRepresentable {
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

    /// 系统输入框的高度：边框画在这个高度之外。
    private static let height: CGFloat = 22

    /// 输入框里的文字。
    @Binding
    var text: String

    /// 辅助功能读出的名称。
    let label: String

    /// 文字的水平对齐。
    let alignment: NSTextAlignment

    /// 结束输入时调用。
    let onEndEditing: (String) -> Void

    /// 创建单行、可编辑的系统输入框。
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.alignment = alignment
        field.delegate = context.coordinator
        field.setAccessibilityLabel(label)

        return field
    }

    /// 跟随外部对文字的修改，编辑中同样如此；输入法正在组字时不替换，组字的文字提交后写回绑定。
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self

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
        CGSize(width: proposal.replacingUnspecifiedDimensions().width, height: Self.height)
    }

    /// 创建接收输入的协调器。
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
}
