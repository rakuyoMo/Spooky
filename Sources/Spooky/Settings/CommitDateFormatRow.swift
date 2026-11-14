import SwiftUI

// MARK: - CommitDateFormatRow

/// General 页的 “Date format for commits”：相对与绝对两项，菜单项文字是用各自格式渲染的示例日期。
struct CommitDateFormatRow: View {
    /// 提交日期的显示格式。
    @AppStorage(CommitDateFormat.key)
    private var format = CommitDateFormat.absolute

    /// 与 General 页其它行相同：右对齐的标签加占满控件列的弹出菜单。
    var body: some View {
        SettingsRow(AppLocalization.text("settings.dateFormat")) {
            Picker("", selection: $format) {
                ForEach(CommitDateFormat.allCases, id: \.self) { format in
                    Text(format.string(from: Self.sample())).tag(format)
                }
            }
            .labelsHidden()
            .settingsColumnWidth()
            .accessibilityLabel(AppLocalization.text("settings.dateFormat"))
        }
    }

    /// 示例日期：三天前的此刻，两种格式都写出具体的日子。
    ///
    /// - Parameters:
    ///   - now: 当前时刻。
    ///   - calendar: 往前数日子的日历。
    static func sample(now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -3, to: now) ?? now
    }
}
