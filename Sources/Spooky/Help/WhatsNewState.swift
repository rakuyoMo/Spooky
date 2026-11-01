import Foundation

// MARK: - WhatsNewEntry

/// What's New 列表的一条：一个版本的更新说明。
struct WhatsNewEntry: Identifiable, Equatable {
    /// 版本号，同时是条目的标识。
    let version: String

    /// 按用户的语言挑出的一份说明，Markdown 原文。
    let notes: String

    /// 条目按版本号区分。
    var id: String {
        version
    }

    /// 读出目录下各版本的更新说明，按版本号从新到旧排。
    ///
    /// 每个版本一个子目录，目录名是版本号，里面每种语言一份 `<语言>.md`；
    /// 按用户的语言挑一份，没有这种语言时用英文，一种支持的语言都没有的版本不列。
    ///
    /// - Parameters:
    ///   - directory: 各版本说明所在的目录；nil 或不存在时没有条目。
    ///   - preferences: 用户偏好的语言，nil 表示按系统设置。
    /// - Returns: 新的版本在前的条目。
    static func entries(in directory: URL?, preferences: [String]? = nil) -> [Self] {
        guard
            let directory,
            let versions = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else {
            return []
        }

        return versions
            .sorted { $0.compare($1, options: .numeric) == .orderedDescending }
            .compactMap { version in
                entry(version: version, in: directory.appending(path: version), preferences: preferences)
            }
    }

    /// 一个版本目录里按用户的语言挑出的说明；没有支持的语言或读不出时为 nil。
    private static func entry(version: String, in folder: URL, preferences: [String]?) -> Self? {
        let available = AppLocalization.languages.filter {
            FileManager.default.fileExists(atPath: folder.appending(path: $0 + ".md").path)
        }

        guard
            let language = Bundle.preferredLocalizations(from: available, forPreferences: preferences).first,
            let notes = try? String(contentsOf: folder.appending(path: language + ".md"), encoding: .utf8)
        else {
            return nil
        }

        return Self(version: version, notes: notes)
    }
}

// MARK: - WhatsNewState

/// What's New 的条目、已读记录、窗口里选中的版本与新功能卡片的显示状态。
///
/// App 内只有一份，What's New 窗口与所有仓库窗口的侧边栏共用：在任一处读过或关掉，其它地方随之更新。
@MainActor
@Observable
final class WhatsNewState {
    /// 已读的版本号数组。
    static let readVersionsKey = "whatsNewReadVersions"

    /// 上次显示新功能卡片时的版本号。
    static let cardVersionKey = "whatsNewCardVersion"

    /// App 使用的状态：说明取自打包进 App 的 `ReleaseNotes` 资源目录，记录存在标准偏好里。
    static let shared = WhatsNewState(
        entries: WhatsNewEntry.entries(in: Bundle.main.resourceURL?.appending(path: "ReleaseNotes")),
        currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
        defaults: .standard
    )

    /// 历次版本的更新说明，新的在前。
    let entries: [WhatsNewEntry]

    /// App 的对外版本号。
    let currentVersion: String

    /// 已读的版本号。
    private(set) var readVersions: Set<String>

    /// What's New 窗口里选中的版本；选中一条就记为已读。
    var selection: String? = nil {
        didSet {
            if let selection {
                markRead(selection)
            }
        }
    }

    /// 仓库窗口的侧边栏底部是否显示新功能卡片。
    private(set) var showsCard = false

    /// 这个构建打包了当前版本的更新说明；没有时不显示新功能卡片。
    var hasCurrentNotes: Bool {
        entries.contains { $0.version == currentVersion }
    }

    /// 存已读记录与卡片版本的偏好域，测试使用独立的域。
    @ObservationIgnored
    private let defaults: UserDefaults

    /// 读出偏好里的已读记录。
    ///
    /// - Parameters:
    ///   - entries: 历次版本的更新说明，新的在前。
    ///   - currentVersion: App 的对外版本号。
    ///   - defaults: 存已读记录与卡片版本的偏好域。
    init(entries: [WhatsNewEntry], currentVersion: String, defaults: UserDefaults) {
        self.entries = entries
        self.currentVersion = currentVersion
        self.defaults = defaults
        readVersions = Set(defaults.stringArray(forKey: Self.readVersionsKey) ?? [])
    }

    /// 启动时调用一次。
    ///
    /// 还没有已读记录时（全新安装，或从没有这项记录的版本升级上来），把当前版本以外的版本都记为已读，只有当前版本带蓝点；
    /// 打包了当前版本的说明、且这个版本还没显示过卡片时显示卡片，并立即记下版本号，下次启动不再出现。
    func start() {
        if defaults.object(forKey: Self.readVersionsKey) == nil {
            readVersions = Set(entries.map(\.version)).subtracting([currentVersion])
            saveReadVersions()
        }

        guard
            hasCurrentNotes,
            defaults.string(forKey: Self.cardVersionKey) != currentVersion
        else {
            return
        }

        showsCard = true
        defaults.set(currentVersion, forKey: Self.cardVersionKey)
    }

    /// 这个版本的说明还没读过。
    func isUnread(_ entry: WhatsNewEntry) -> Bool {
        !readVersions.contains(entry.version)
    }

    /// 卡片的 Learn More…：当前版本记为已读，卡片消失；窗口由调用方打开。
    func learnMore() {
        markRead(currentVersion)
        showsCard = false
    }

    /// 卡片的 ×：卡片消失，不记已读。
    func dismissCard() {
        showsCard = false
    }

    /// Developer 菜单的 Show What's New Card：清掉显示过卡片的版本记录，按启动时的条件重新显示卡片。
    func showCardAgain() {
        defaults.removeObject(forKey: Self.cardVersionKey)
        start()
    }

    /// 把一个版本记为已读并写进偏好；已经读过时不动。
    private func markRead(_ version: String) {
        guard readVersions.insert(version).inserted else {
            return
        }

        saveReadVersions()
    }

    /// 已读记录按版本号从新到旧写进偏好。
    private func saveReadVersions() {
        let versions = readVersions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
        defaults.set(versions, forKey: Self.readVersionsKey)
    }
}
