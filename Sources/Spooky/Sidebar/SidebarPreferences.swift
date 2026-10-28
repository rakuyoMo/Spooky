import Foundation

// MARK: - SidebarPreferences

/// 侧边栏的视图设置：所有仓库窗口共用，存在偏好里，界面以 `@AppStorage` 读取同一组键。
enum SidebarPreferences {
    /// 标签的排列顺序，原始值存进偏好。
    enum TagOrder: Int, CaseIterable {
        /// 按名称升序。
        case nameAscending = 1

        /// 按名称降序。
        case nameDescending = 2
    }

    /// Workspace 分组显示 Reflog 入口。
    static let showReflogKey = "showReflogInSidebar"

    /// Stashes 入口显示储藏个数。
    static let showStashCountKey = "showNumberOfStashesInSidebar"

    /// 本地分支、远端分支与标签按 “/” 折叠成文件夹。
    static let groupRefsKey = "groupRefsInSidebar"

    /// 同一级里文件夹排在引用前面，只在折叠开启时生效。
    static let groupedRefsOnTopKey = "groupedRefsOnTop"

    /// 陈旧的分支在名称后注明多久没有更新。
    static let showStaleInfoKey = "showStaleInfoInSidebar"

    /// 判定陈旧的月数。
    static let staleIntervalKey = "staleBranchInterval"

    /// 自动归档分支的开关。
    static let autoArchiveKey = "autoArchiveBranches"

    /// 每个远端只显示最新的若干个远端分支，0 表示全部。
    static let newestRemoteBranchesKey = "numberOfNewestRemoteBranches"

    /// 标签的排列顺序。
    static let tagOrderKey = "tagsSortMode"

    /// 只显示最新的若干个标签，0 表示全部。
    static let newestTagsKey = "numberOfNewestTags"

    /// 陈旧阈值可选的月数。
    static let staleIntervals = [1, 2, 3, 4, 6, 9, 12, 18, 24]

    /// 远端分支与标签数量的档位，0 表示全部。
    static let newestChoices = [0, 10, 15, 25, 50, 100, 250, 500]

    /// 开关没有记录时的取值。
    #warning(
        "TODO: 除 Group Refs in Sidebar 默认开启、数量默认全部外，其余默认值是选定的：显示储藏个数、文件夹置前与陈旧信息开启，陈旧阈值 3 个月，Reflog 与自动归档关闭，标签按名称升序；核实方式：在全新的偏好里打开视图设置菜单比对勾选状态；影响首次打开时侧边栏显示哪些信息"
    )
    static let defaultFlags: [String: Bool] = [
        showReflogKey: false,
        showStashCountKey: true,
        groupRefsKey: true,
        groupedRefsOnTopKey: true,
        showStaleInfoKey: true,
        autoArchiveKey: false,
    ]

    /// 数值项没有记录时的取值。
    static let defaultNumbers: [String: Int] = [
        staleIntervalKey: 3,
        newestRemoteBranchesKey: 0,
        tagOrderKey: TagOrder.nameAscending.rawValue,
        newestTagsKey: 0,
    ]

    /// 开关没有记录时的取值，供 `@AppStorage` 的初值使用。
    static func defaultFlag(_ key: String) -> Bool {
        defaultFlags[key] ?? false
    }

    /// 数值项没有记录时的取值，供 `@AppStorage` 的初值使用。
    static func defaultNumber(_ key: String) -> Int {
        defaultNumbers[key] ?? 0
    }

    /// 开关的当前值；没有记录时取默认值。
    static func isOn(_ key: String, in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultFlag(key)
    }

    /// 数值项的当前值；没有记录或记录不在可选范围内时取默认值。
    static func integer(_ key: String, in defaults: UserDefaults = .standard) -> Int {
        guard let value = defaults.object(forKey: key) as? Int, isValid(value, for: key) else {
            return defaultNumber(key)
        }

        return value
    }

    /// 数值是否在该项的可选范围内；界面读到范围外的记录时按默认值显示。
    static func isValid(_ value: Int, for key: String) -> Bool {
        switch key {
        case staleIntervalKey:
            staleIntervals.contains(value)

        case newestRemoteBranchesKey, newestTagsKey:
            newestChoices.contains(value)

        case tagOrderKey:
            TagOrder(rawValue: value) != nil

        default:
            true
        }
    }
}
