import Foundation
import SpookyKit

// MARK: - HistoryGrouping

/// 按提交人日期把历史列表分组的方式，原始值就是偏好里保存的值。
enum HistoryGrouping: Int, CaseIterable {
    /// 不分组。
    case ungrouped = 0

    /// 每天一组。
    case day = 1

    /// 每周一组。
    case week = 2

    /// 每月一组。
    case month = 3

    /// 视图设置菜单里的标题键。
    var titleKey: String {
        switch self {
        case .ungrouped: "history.group.none"
        case .day: "history.group.day"
        case .week: "history.group.week"
        case .month: "history.group.month"
        }
    }

    /// 按模板生成当前语言的日期格式。
    private static func formatter(template: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    /// 包含该日期的那一组的起点；不分组时为 nil。
    func start(of date: Date, in calendar: Calendar) -> Date? {
        switch self {
        case .ungrouped: nil
        case .day: calendar.startOfDay(for: date)
        case .week: calendar.dateInterval(of: .weekOfYear, for: date)?.start
        case .month: calendar.dateInterval(of: .month, for: date)?.start
        }
    }

    /// 一组的标题：按天时跟随提交日期格式，按周写出当月第几周与全年第几周，按月写出月份与年份。
    func title(
        of start: Date,
        format: CommitDateFormat,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        switch self {
        case .ungrouped:
            return ""

        case .day:
            return format.dayTitle(start, now: now, calendar: calendar)

        case .week:
            let month = Self.formatter(template: "MMMyyyy", calendar: calendar).string(from: start)

            return AppLocalization.text(
                "history.group.weekTitle",
                calendar.component(.weekOfMonth, from: start),
                month,
                calendar.component(.weekOfYear, from: start)
            )

        case .month:
            return Self.formatter(template: "MMMMyyyy", calendar: calendar).string(from: start)
        }
    }
}

// MARK: - HistoryViewSettings

/// 历史的视图设置：提交图、只看第一父、排序、日期分组与行高，所有窗口共用一份偏好。
///
/// 显示提交图时总按拓扑序排列，Topo Order 一项在菜单里勾选并灰掉；分组只在按日期排序时生效。
struct HistoryViewSettings: Equatable {
    /// 显示提交图的偏好键。
    static let showGraphKey = "historyShowGraph"

    /// 小号行的偏好键。
    static let smallRowsKey = "historySmallRows"

    /// 只显示第一父提交的偏好键。
    static let firstParentKey = "historyShowFirstParentOnly"

    /// 按拓扑序排序的偏好键。
    static let topoOrderKey = "historySortByTopoOrder"

    /// 按日期排序的偏好键。
    static let dateOrderKey = "historySortByDate"

    /// 日期分组方式的偏好键。
    static let groupingKey = "historyGrouping"

    /// 是否显示提交图。
    let showsGraph: Bool

    /// 合并提交只沿第一父向前。
    let showsFirstParentOnly: Bool

    /// 是否按拓扑序排列；显示提交图时总是。
    let sortsByTopoOrder: Bool

    /// 是否按日期排列。
    let sortsByDate: Bool

    /// 生效的日期分组；不按日期排序时不分组。
    let grouping: HistoryGrouping

    /// 交给 Git 的排序：两项都勾选时以日期为准，都不勾选时用 Git 默认的顺序。
    var order: HistoryQuery.Order {
        if sortsByDate {
            return .date
        }

        return sortsByTopoOrder ? .topological : .default
    }

    /// 读取偏好；测试传入临时的偏好域。
    init(defaults: UserDefaults = .standard) {
        #warning("TODO: Sort By 的 Date 与 Group By 的默认值未核实，目前默认不按日期排序、不分组；只影响没有改过这两项设置时的历史顺序与分组")

        showsGraph = defaults.object(forKey: Self.showGraphKey) as? Bool ?? true
        showsFirstParentOnly = defaults.bool(forKey: Self.firstParentKey)
        sortsByTopoOrder = showsGraph || defaults.bool(forKey: Self.topoOrderKey)
        sortsByDate = defaults.bool(forKey: Self.dateOrderKey)

        let stored = HistoryGrouping(rawValue: defaults.integer(forKey: Self.groupingKey)) ?? .ungrouped
        grouping = sortsByDate ? stored : .ungrouped
    }

    /// 按当前设置与搜索条件组成历史查询。
    func query(conditions: [HistorySearchCondition]) -> HistoryQuery {
        HistoryQuery(order: order, firstParentOnly: showsFirstParentOnly, conditions: conditions)
    }
}
