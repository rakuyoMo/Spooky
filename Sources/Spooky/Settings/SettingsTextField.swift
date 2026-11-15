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
