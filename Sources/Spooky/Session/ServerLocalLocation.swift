import Foundation
import SpookyKit

// MARK: - ServerLocalLocation

/// 服务器仓库目录在这台 Mac 上的本机位置怎样确定：自动查找、由 Spooky 经 SMB 或 sshfs 挂载，或指定文件夹。
///
/// 按仓库记在这台 Mac 的偏好里，全部窗口共用，不写进 B 的 Git 配置；仓库目录以外的工作树照旧各自自动查找。
enum ServerLocalLocation: Equatable {
    /// 在这台 Mac 已挂载的网络卷里找。
    case automatic

    /// 位置按自动查找的办法找；没挂着时由 Spooky 挂上记下的共享。
    ///
    /// `share` 是上次挂上后所在卷的重新挂载地址，不含密码；还没有挂上过时为 nil。
    case smbMount(share: URL?)

    /// 由 Spooky 用 sshfs 把仓库目录挂到这个本机文件夹，位置就是它。
    case sshfsMount(folder: URL)

    /// 手动指定的本机文件夹。
    case chosenFolder(URL)

    /// 本机位置的方式，不带各自的数据。
    enum Method: String, CaseIterable {
        /// 自动查找。
        case automatic

        /// SMB 挂载。
        case smbMount

        /// sshfs 挂载。
        case sshfsMount

        /// 指定文件夹。
        case chosenFolder

        /// 由 Spooky 挂载的方式对应的挂载办法；其余方式为 nil。
        var mounting: RemoteMountMethod? {
            switch self {
            case .smbMount: .smb
            case .sshfsMount: .sshfs
            case .automatic, .chosenFolder: nil
            }
        }

        /// 界面上的名称。
        var title: String {
            switch self {
            case .automatic: AppLocalization.text("localLocation.method.automatic")
            case .smbMount: AppLocalization.text("localLocation.method.smbMount")
            case .sshfsMount: AppLocalization.text("localLocation.method.sshfsMount")
            case .chosenFolder: AppLocalization.text("localLocation.method.chosenFolder")
            }
        }
    }

    /// 按仓库记下整条本机位置的偏好键，值以仓库的显示路径（`<别名>:<路径>`）为键。
    static let key = "serverLocalLocations"

    /// 只记手动指定文件夹的旧偏好键，值以仓库的显示路径为键、本机路径为值；读到时迁移进 ``key``。
    static let legacyKey = "serverLocalFolders"

    /// 这条本机位置的方式。
    var method: Method {
        switch self {
        case .automatic: .automatic
        case .smbMount: .smbMount
        case .sshfsMount: .sshfsMount
        case .chosenFolder: .chosenFolder
        }
    }

    /// 方式带的本机文件夹：sshfs 挂载到的文件夹或指定的文件夹；其余方式为 nil。
    var folder: URL? {
        switch self {
        case .sshfsMount(let folder), .chosenFolder(let folder): folder
        case .automatic, .smbMount: nil
        }
    }

    /// 这个服务器仓库记下的本机位置；没有记录时是自动查找。
    ///
    /// 只在旧偏好键里手动指定过文件夹的仓库读作指定文件夹，同时写进新键、删掉旧键里的这一项。
    ///
    /// - Parameters:
    ///   - repository: 服务器仓库。
    ///   - defaults: 存放记录的偏好，测试使用独立的偏好域。
    static func stored(for repository: RepositoryLocation, defaults: UserDefaults = .standard) -> Self {
        let id = repository.displayPath

        if let record = (defaults.dictionary(forKey: key) as? [String: [String: String]])?[id] {
            return Self(record: record) ?? .automatic
        }

        var legacy = defaults.dictionary(forKey: legacyKey) as? [String: String] ?? [:]

        guard let path = legacy.removeValue(forKey: id) else {
            return .automatic
        }

        let location = Self.chosenFolder(URL(filePath: path))
        store(location, for: repository, defaults: defaults)

        // 旧键里的记录迁移完后删掉整个键
        if legacy.isEmpty {
            defaults.removeObject(forKey: legacyKey)
        } else {
            defaults.set(legacy, forKey: legacyKey)
        }

        return location
    }

    /// 记下这个服务器仓库的本机位置；自动查找是默认，记作删掉这一项。
    ///
    /// - Parameters:
    ///   - location: 本机位置。
    ///   - repository: 服务器仓库。
    ///   - defaults: 存放记录的偏好，测试使用独立的偏好域。
    static func store(_ location: Self, for repository: RepositoryLocation, defaults: UserDefaults = .standard) {
        var records = defaults.dictionary(forKey: key) ?? [:]
        records[repository.displayPath] = location == .automatic ? nil : location.record
        defaults.set(records, forKey: key)
    }
}

// MARK: - Private

extension ServerLocalLocation {
    /// 偏好里一条记录的字段名。
    private enum Field {
        /// 方式的原始值。
        static let method = "method"

        /// SMB 记下的共享。
        static let share = "share"

        /// sshfs 挂载到的文件夹或指定的文件夹。
        static let folder = "folder"
    }

    /// 写进偏好的一条记录：方式与它带的共享或文件夹。
    private var record: [String: String] {
        var record = [Field.method: method.rawValue]

        switch self {
        case .smbMount(let share):
            record[Field.share] = share?.absoluteString

        case .sshfsMount(let folder), .chosenFolder(let folder):
            record[Field.folder] = folder.path

        case .automatic:
            break
        }

        return record
    }

    /// 从偏好里的一条记录读出本机位置；方式无法识别或缺少文件夹时为 nil。
    private init?(record: [String: String]) {
        let folder = record[Field.folder].map { URL(filePath: $0) }

        switch record[Field.method].flatMap(Method.init(rawValue:)) {
        case .automatic:
            self = .automatic

        case .smbMount:
            self = .smbMount(share: record[Field.share].flatMap(URL.init(string:)))

        case .sshfsMount:
            guard let folder else { return nil }
            self = .sshfsMount(folder: folder)

        case .chosenFolder:
            guard let folder else { return nil }
            self = .chosenFolder(folder)

        case nil:
            return nil
        }
    }
}
