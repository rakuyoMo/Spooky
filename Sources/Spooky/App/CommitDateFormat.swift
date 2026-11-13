import Foundation

// MARK: - CommitDateFormat

/// 提交日期的显示格式：Settings → General 的 “Date format for commits”。
///
/// 历史的提交行与日期分组、储藏列表、文件历史都经这里格式化，改动设置后一起变化；两种写法都不带时间。
enum CommitDateFormat: String, CaseIterable {
    /// 按语言与区域的短日期，如 “10/26/26”。
    case absolute

    /// 今天、昨天写成 “Today” “Yesterday”，其余日子写完整日期，如 “October 26, 2026”。
    case relative

    /// 偏好键。
    static let key = "commitDateFormat"

    /// 一个提交或储藏的日期，不带时间。
    ///
    /// - Parameters:
    ///   - date: 要写出的时刻。
    ///   - now: 判断今天、昨天时的当前时刻。
    ///   - calendar: 划分日子的日历；它的时区与语言区域也决定写出的样子。
    func string(from date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let locale = calendar.locale ?? .current

        // 相对写法只在今天、昨天用系统按语言给出的说法，以后的日子与更早的日子都写完整日期
        if self == .relative {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: date),
                to: calendar.startOfDay(for: now)
            ).day

            if let days, days == 0 || days == 1 {
                return Self.dayName(daysAgo: days, locale: locale, calendar: calendar)
            }
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = self == .absolute ? .short : .long
        formatter.timeStyle = .none

        return formatter.string(from: date)
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

    /// 今天或昨天按语言给出的说法，首字母按句首大写，如 “Today” “Yesterday”。
    ///
    /// - Parameters:
    ///   - daysAgo: 离今天的天数，0 是今天，1 是昨天。
    ///   - locale: 写出的语言与区域。
    ///   - calendar: 划分日子的日历。
    private static func dayName(daysAgo days: Int, locale: Locale, calendar: Calendar) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        formatter.formattingContext = .beginningOfSentence

        return formatter.localizedString(from: DateComponents(day: -days))
    }
}
