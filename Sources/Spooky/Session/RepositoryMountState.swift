import AppKit
import Observation
import SpookyKit

// MARK: - RepositoryMountState

/// 服务器仓库与仓库目录以外的工作树在这台 Mac 上的挂载位置，按 B 上的目录记下查找结果；结果只在本次运行里保留。
///
/// 工作树清单读到新的目录，以及这台 Mac 挂载或卸载卷时在后台查找。仓库目录在仓库设置里手动指定了本机目录时只用它，不再自动查找。
@MainActor
@Observable
final class RepositoryMountState {
    /// 一个 B 上目录的查找结果。
    enum Lookup: Equatable {
        /// 正在查找。
        case searching

        /// 找到并核对过的本机位置。
        case found(RemoteMount)

        /// 这台 Mac 没有挂载这个目录。
        case notMounted
    }

    /// 仓库目录手动指定的本机目录。
    struct Designation: Equatable {
        /// B 上的仓库目录与指定的本机目录。
        let mount: RemoteMount

        /// 指定的目录现在在不在；卷没有挂载时不在。
        let exists: Bool
    }

    /// 按 B 上的目录记下的查找结果；还没开始查找的目录与手动指定了本机目录的仓库目录不在其中。
    private(set) var lookups: [String: Lookup] = [:]

    /// 仓库目录手动指定的本机目录；没有指定时为 nil。
    private(set) var designation: Designation? = nil

    /// 按主机别名建出查找器；测试换成用临时目录代替挂载卷的。
    @ObservationIgnored
    var makeLocator: @Sendable (String) -> RemoteMountLocator = { RemoteMountLocator(host: $0) }

    /// 最近一次查找所在的主机与执行器，卷变化时用它重新查找。
    @ObservationIgnored
    private var source: (host: String, runner: GitRunner)? = nil

    /// 各目录最近一次查找的标识；同一目录重新查找后，先前那次的结果不再采用。
    @ObservationIgnored
    private var requests: [String: UUID] = [:]

    /// 挂载与卸载卷的通知。
    @ObservationIgnored
    private var observers: [any NSObjectProtocol] = []

    /// 窗口关闭时移除卷变化的通知。
    isolated deinit {
        stopObserving()
    }

    /// 在后台查找这些 B 上的目录，并开始观察卷的变化。
    ///
    /// - Parameters:
    ///   - paths: B 上带 `.git` 的目录。
    ///   - host: 主机别名。
    ///   - runner: 仓库的执行器，核对用的标记文件经它写进 B 的 Git 目录。
    ///   - refreshes: 为 true 时已有结果的目录也重新查找；否则只查还没有结果的。手动指定了本机目录的仓库目录都不查找。
    func locate(_ paths: [String], host: String, runner: GitRunner, refreshes: Bool) {
        source = (host, runner)
        startObserving()

        let locator = makeLocator(host)
        let pending = paths.filter { path in
            path != designation?.mount.remotePath && (refreshes || lookups[path] == nil)
        }

        for path in pending {
            let request = UUID()
            requests[path] = request
            lookups[path] = .searching

            Task { [weak self] in
                let mount = await locator.locate(path, runner: runner)

                guard let self, requests[path] == request else { return }

                lookups[path] = mount.map(Lookup.found) ?? .notMounted
            }
        }
    }

    /// 记下仓库目录手动指定的本机目录，并查看它现在在不在；指定了目录后，仓库目录先前与进行中的自动查找结果都不再采用。
    ///
    /// - Parameters:
    ///   - folder: 指定的本机目录；nil 表示没有指定，此后仓库目录照常自动查找。
    ///   - path: B 上的仓库目录。
    func designate(_ folder: URL?, for path: String) {
        let designation = folder.map {
            Designation(mount: RemoteMount(remotePath: path, localURL: $0), exists: Self.directoryExists($0))
        }

        if designation != self.designation {
            self.designation = designation
        }

        guard designation != nil else {
            return
        }

        requests[path] = nil

        if lookups[path] != nil {
            lookups[path] = nil
        }

        // 指定的目录随卷的挂载与卸载出现或消失
        startObserving()
    }

    /// 服务器上仓库目录在这台 Mac 上的位置：手动指定了目录时只用它，它现在不在时为 nil；没有指定时用自动查找并核对过的挂载。
    ///
    /// - Parameter path: B 上的仓库目录。
    func repositoryMount(of path: String) -> RemoteMount? {
        if let designation {
            return designation.exists ? designation.mount : nil
        }

        guard case .found(let mount) = lookups[path] else {
            return nil
        }

        return mount
    }

    /// 关闭仓库时清除全部结果，停止观察卷的变化；进行中的查找照常结束并删掉标记，结果不再采用。
    func reset() {
        lookups = [:]
        designation = nil
        requests = [:]
        source = nil
        stopObserving()
    }
}

// MARK: - Private

extension RepositoryMountState {
    /// 本机的这个目录现在在不在。
    private static func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false

        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// 开始观察这台 Mac 挂载与卸载卷；已在观察时什么也不做。
    private func startObserving() {
        guard observers.isEmpty else {
            return
        }

        let center = NSWorkspace.shared.notificationCenter
        let names = [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification]

        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.volumesChanged()
                }
            }
        }
    }

    /// 停止观察卷的变化。
    private func stopObserving() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }

        observers = []
    }

    /// 卷有变化时，重新查看手动指定的目录在不在，已经查过的目录全部重新查找。
    private func volumesChanged() {
        if let designation {
            designate(designation.mount.localURL, for: designation.mount.remotePath)
        }

        guard let source else {
            return
        }

        locate(Array(lookups.keys), host: source.host, runner: source.runner, refreshes: true)
    }
}

// MARK: - ServerLocalFolders

/// 服务器仓库在仓库设置里手动指定的本机目录，存在这台 Mac 的偏好里，全部窗口共用；不写进 B 的 Git 配置。
enum ServerLocalFolders {
    /// 偏好键，值是仓库的显示路径（`<别名>:<路径>`）到本机目录路径的字典。
    static let key = "serverLocalFolders"

    /// 这个仓库手动指定的本机目录；没有指定时为 nil。
    ///
    /// - Parameters:
    ///   - location: 服务器仓库。
    ///   - defaults: 存放记录的偏好。
    static func folder(for location: RepositoryLocation, in defaults: UserDefaults = .standard) -> URL? {
        (defaults.dictionary(forKey: key)?[location.displayPath] as? String).map { URL(filePath: $0) }
    }

    /// 保存或清除这个仓库手动指定的本机目录。
    ///
    /// - Parameters:
    ///   - folder: 本机目录；nil 表示清除。
    ///   - location: 服务器仓库。
    ///   - defaults: 存放记录的偏好。
    static func set(_ folder: URL?, for location: RepositoryLocation, in defaults: UserDefaults = .standard) {
        var folders = defaults.dictionary(forKey: key) ?? [:]
        folders[location.displayPath] = folder?.path
        defaults.set(folders, forKey: key)
    }
}
