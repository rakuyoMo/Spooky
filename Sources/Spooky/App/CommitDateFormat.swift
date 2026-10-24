import Foundation

// MARK: - CommitDateFormat

/// 提交日期的显示格式：Settings → General 的 “Date format for commits”。
///
/// 历史的提交行与日期分组、储藏列表、文件历史都经这里格式化，改动设置后一起变化。
enum CommitDateFormat: String, CaseIterable {
    /// 日期加时间，如 “Oct 23, 2026 at 2:05 PM”。
    case absolute

    /// 相对现在的时间，如 “5 minutes ago”。
    case relative

    /// 偏好键。
    static let key = "commitDateFormat"

    /// 一个提交或储藏的日期。
    func string(from date: Date, now: Date = Date()) -> String {
        #warning("TODO: 绝对格式写成缩写日期加时间、相对格式写成 “5 minutes ago” 一类，都是推断；需对照实测核实今天的提交是否只写时间、相对格式的单位与措辞，影响提交行、储藏与文件历史的日期文字")

        switch self {
        case .absolute:
            return date.formatted(date: .abbreviated, time: .shortened)

        case .relative:
            return Self.relativeFormatter.localizedString(for: date, relativeTo: now)
        }
    }

    /// 按天分组时一组的标题：绝对格式写出完整日期，相对格式写 “today” “yesterday” 这类说法。
    func dayTitle(_ day: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        switch self {
        case .absolute:
            return day.formatted(date: .long, time: .omitted)

        case .relative:
            // 两端都取当天零点，比较的是相差的整天
            let today = calendar.startOfDay(for: now)
            return Self.relativeFormatter.localizedString(for: calendar.startOfDay(for: day), relativeTo: today)
        }
    }
}

// MARK: - Private

extension CommitDateFormat {
    /// 相对时间用完整单位名，相邻的日子写作 “yesterday” “today”。
    private static var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter
    }
}
