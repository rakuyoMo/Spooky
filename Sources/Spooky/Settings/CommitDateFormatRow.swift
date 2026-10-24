import SwiftUI

// MARK: - CommitDateFormatRow

/// General 页的 “Date format for commits”：相对与绝对两项，菜单项文字是用各自格式渲染的示例日期。
struct CommitDateFormatRow: View {
    /// 示例日期：三小时前，两种格式的区别一目了然。
    private static var sample: Date {
        Date(timeIntervalSinceNow: -3 * 3600)
    }

    /// 提交日期的显示格式。
    @AppStorage(CommitDateFormat.key)
    private var format = CommitDateFormat.absolute

    /// 与 General 页其它行相同：右对齐的标签加 278 pt 宽的弹出菜单。
    var body: some View {
        GridRow {
            Text(AppLocalization.text("settings.dateFormat"))

            Picker("", selection: $format) {
                ForEach(CommitDateFormat.allCases, id: \.self) { format in
                    Text(format.string(from: Self.sample)).tag(format)
                }
            }
            .labelsHidden()
            .frame(width: 278)
            .accessibilityLabel(AppLocalization.text("settings.dateFormat"))
        }
    }
}
