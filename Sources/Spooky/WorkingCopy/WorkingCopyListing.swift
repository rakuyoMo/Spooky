import AppKit
import SpookyKit

// MARK: - WorkingCopyListMode

/// 工作区文件列表的显示模式，所有仓库共用一个选择并跨重启保留。
enum WorkingCopyListMode: Int {
    /// 平铺：每行一个文件，显示仓库内的相对路径。
    case list = 0

    /// 树形：按目录组织文件，只显示末级名称。
    case tree = 1

    /// 全部文件：树形里同时显示没有改动的已跟踪文件。
    case allFiles = 2

    /// 保存显示模式的偏好键，值是模式的原始值。
    private static let storageKey = "workingCopyViewMode"

    /// 是否按目录组织。
    var isTree: Bool { self != .list }

    /// 所有仓库共用的显示模式；没有记录或记录无法识别时为平铺。
    ///
    /// - Parameter defaults: 保存偏好的位置，测试使用独立的偏好域。
    static func stored(defaults: UserDefaults = .standard) -> Self {
        Self(rawValue: defaults.integer(forKey: storageKey)) ?? .list
    }

    /// 记住显示模式，之后打开的每个仓库都沿用它。
    ///
    /// - Parameter defaults: 保存偏好的位置，测试使用独立的偏好域。
    static func store(_ mode: Self, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: storageKey)
    }
}

// MARK: - WorkingCopyPreferences

/// 工作区列表的全局偏好：显示被忽略与 assume-unchanged 文件、双击与空格的动作、字号与截断方式。
enum WorkingCopyPreferences {
    /// 双击文件的动作。
    enum DoubleClickAction: String, CaseIterable {
        /// 用默认程序打开。
        case openFile

        /// 用比较工具对比 HEAD 版本与工作区文件。
        case openDiff
    }

    /// 文件列表里空格键的动作。
    enum SpacebarAction: String, CaseIterable {
        /// 切换所选文件的暂存状态。
        case toggleStaging

        /// 打开 Quick Look 预览。
        case quickLook
    }

    /// 文件列表的字号档位。
    enum FontSize: String, CaseIterable {
        /// 系统正文字号。
        case regular

        /// 12 pt。
        case medium

        /// 对应的字号。
        var pointSize: CGFloat {
            self == .regular ? NSFont.systemFontSize : 12
        }
    }

    /// 长文件名的截断位置。
    enum Truncation: String, CaseIterable {
        /// 截掉开头，保留文件名。
        case beginning

        /// 截掉中间，保留首尾。
        case middle

        /// 对应的换行模式。
        var lineBreakMode: NSLineBreakMode {
            self == .beginning ? .byTruncatingHead : .byTruncatingMiddle
        }
    }

    /// 是否显示被忽略的文件。
    static let showIgnored = "workingCopyShowIgnored"

    /// 是否显示 assume-unchanged 文件。
    static let showAssumeUnchanged = "workingCopyShowAssumeUnchanged"

    /// 双击文件的动作，取值见 ``DoubleClickAction``。
    static let doubleClickAction = "workingCopyDoubleClickAction"

    /// 双击子模块时在 Spooky 里把它当仓库打开，而不是执行双击文件的动作；默认开。
    static let doubleClickOpensSubmodules = "workingCopyDoubleClickOpensSubmodules"

    /// 空格键的动作，取值见 ``SpacebarAction``。
    static let spacebarAction = "workingCopySpacebarAction"

    /// 文件列表字号，取值见 ``FontSize``。
    static let fontSize = "workingCopyFontSize"

    /// 长文件名的截断位置，取值见 ``Truncation``。
    static let truncation = "workingCopyTruncation"

    /// 丢弃块或行之前是否先确认；没有记录时确认。
    static let warnsDiscardingChunks = "workingCopyWarnDiscardingChunks"
}

// MARK: - WorkingTreeFileListing

/// 工作区列表在 Git 状态之外补充的文件清单；只在打开对应的显示选项时读取，未读取的部分为 nil。
struct WorkingTreeFileListing: Equatable {
    /// 暂存区里的全部文件；显示全部文件或 assume-unchanged 文件时读取。
    let index: [IndexFile]?

    /// 被忽略的文件与目录；显示被忽略文件时读取。
    let ignored: [String]?

    /// 暂存区里的路径，供逐行查询。
    let indexPaths: Set<String>

    /// 标记了 assume-unchanged 的路径，供逐行查询。
    let assumeUnchanged: Set<String>

    /// 被忽略的路径，供逐行查询。
    let ignoredPaths: Set<String>

    /// 由读取到的清单创建；没有读取的部分传 nil。
    init(index: [IndexFile]? = nil, ignored: [String]? = nil) {
        self.index = index
        self.ignored = ignored
        indexPaths = Set((index ?? []).map(\.path))
        assumeUnchanged = Set((index ?? []).filter(\.assumeUnchanged).map(\.path))
        ignoredPaths = Set(ignored ?? [])
    }
}

// MARK: - WorkingCopyListing

/// 由 Git 状态、补充清单与显示选项算出列表里的条目；只决定显示，不改变 Git 状态模型。
struct WorkingCopyListing: Equatable {
    /// 当前显示模式。
    var mode = WorkingCopyListMode.list

    /// 是否显示被忽略的文件。
    var showsIgnored = false

    /// 是否显示 assume-unchanged 文件。
    var showsAssumeUnchanged = false

    /// 是否只显示冲突文件。
    var onlyConflicts = false

    /// 工具栏搜索框的内容，按路径或文件名过滤。
    var filter = ""

    /// 路径包含搜索内容时匹配；不区分大小写，组合与分解两种 Unicode 写法视为相同。
    static func matches(_ entry: StatusEntry, query: String) -> Bool {
        [entry.path, entry.originalPath]
            .compactMap { $0 }
            .contains { $0.range(of: query, options: .caseInsensitive) != nil }
    }

    /// 列表条目：状态里的改动在前，按选项补出的被忽略、未改动与 assume-unchanged 文件在后，再按搜索过滤。
    func entries(status: [StatusEntry], files: WorkingTreeFileListing) -> [StatusEntry] {
        var entries = status.filter { !onlyConflicts || $0.kind == .conflicted }

        // 只看冲突时不补其它文件
        if !onlyConflicts {
            entries += supplementaryEntries(status: status, files: files)
        }

        #warning("TODO: 核实搜索过滤后全部暂存、丢弃全部等动作是否只作用于可见的文件，目前作用于整个工作区；只影响过滤状态下的全部动作")
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return entries
        }

        return entries.filter { Self.matches($0, query: query) }
    }

    /// 按显示选项补出的条目，状态里已有的路径不再重复列出。
    private func supplementaryEntries(status: [StatusEntry], files: WorkingTreeFileListing) -> [StatusEntry] {
        let listed = Set(status.map(\.path))
        var entries: [StatusEntry] = []

        if showsIgnored {
            entries += (files.ignored ?? [])
                .filter { !listed.contains($0) }
                .map { StatusEntry(kind: .ignored, path: $0) }
        }

        // 全部文件模式补出整个暂存区；否则只在要求时补出 assume-unchanged 文件
        let index = (files.index ?? []).filter { file in
            !listed.contains(file.path) && (mode == .allFiles || (showsAssumeUnchanged && file.assumeUnchanged))
        }

        entries += index.map { StatusEntry(kind: .unchanged, path: $0.path) }
        return entries
    }
}
