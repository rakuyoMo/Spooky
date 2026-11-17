import AppKit
import Observation
import SpookyKit

// MARK: - RepositoryMountState

/// 服务器仓库与仓库目录以外的工作树在这台 Mac 上的位置：仓库目录按本机位置的方式确定，其余目录自动查找；结果只在本次运行里保留。
///
/// 自动查找与 SMB 挂载在已挂载的卷里找仓库目录；sshfs 挂载与指定文件夹的位置就是那个文件夹。
/// 工作树清单读到新的目录、重新连上 B，以及这台 Mac 挂载或卸载卷时在后台查找。
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

    /// 仓库目录现在的本机位置，或拿不到它的原因。
    enum Status: Equatable {
        /// 已知本机位置且这个路径在。
        case available(URL)

        /// 还没有查找结果：还没连上 B，或还没开始查找。
        case unknown

        /// 正在查找。
        case searching

        /// Spooky 正在挂载。
        case mounting

        /// 没有挂载。
        case notMounted

        /// Spooky 上次挂载失败。
        case failed(LocalLocationFailure)

        /// 指定的文件夹不在。
        case folderMissing(URL)
    }

    /// 按 B 上的目录记下的查找结果；还没开始查找的目录，以及本机位置带文件夹时的仓库目录不在其中。
    private(set) var lookups: [String: Lookup] = [:]

    /// 打开的服务器仓库；没有打开时为 nil。
    private(set) var repository: RepositoryLocation? = nil

    /// 仓库目录的本机位置。
    private(set) var location = ServerLocalLocation.automatic

    /// 方式带的文件夹现在能不能用：指定的文件夹在，或 sshfs 挂载到的文件夹正挂着；其余方式为 false。
    private(set) var isFolderAvailable = false

    /// Spooky 正在挂载仓库目录。
    private(set) var isMounting = false

    /// Spooky 上次挂载仓库目录失败的原因；再次挂载或改换本机位置时清除。
    private(set) var failure: LocalLocationFailure? = nil

    /// 检测与执行挂载；测试换成不做真实挂载的实现。
    @ObservationIgnored
    var mounter = RemoteMounter.live

    /// 按主机别名建出查找器；测试换成用临时目录代替挂载卷的。
    @ObservationIgnored
    var makeLocator: @Sendable (String) -> RemoteMountLocator = { RemoteMountLocator(host: $0) }

    /// 记本机位置的偏好；测试使用独立的偏好。
    @ObservationIgnored
    var defaults = UserDefaults.standard

    /// 进行中的挂载；Show in Finder 与后台挂载等它的结果。
    @ObservationIgnored
    private(set) var mountTask: Task<Void, Never>? = nil

    /// 打开仓库后还没做过的后台挂载：方式是 SMB 或 sshfs 挂载时，连上 B 后挂载一次。
    @ObservationIgnored
    var backgroundMountPending = false

    /// 最近一次查找所在的主机与执行器，卷变化与重新连上 B 时用它重新查找。
    @ObservationIgnored
    private(set) var source: (host: String, runner: GitRunner)? = nil

    /// 各目录最近一次查找的标识与任务；同一目录重新查找后，先前那次的结果不再采用。
    @ObservationIgnored
    private var searches: [String: (id: UUID, task: Task<Void, Never>)] = [:]

    /// 最近一次查看文件夹的标识；文件夹换了以后，先前那次的结果不再采用。
    @ObservationIgnored
    private var folderCheck = UUID()

    /// 挂载与卸载卷的通知。
    @ObservationIgnored
    private var observers: [any NSObjectProtocol] = []

    /// 仓库目录的本机位置或拿不到它的原因。
    var status: Status {
        guard let path = repository?.path else {
            return .unknown
        }

        switch location {
        case .chosenFolder(let folder):
            return isFolderAvailable ? .available(folder) : .folderMissing(folder)

        case .sshfsMount(let folder):
            if isFolderAvailable {
                return .available(folder)
            }

            return isMounting ? .mounting : failure.map(Status.failed) ?? .notMounted

        case .automatic, .smbMount:
            return Self.status(of: lookups[path], isMounting: isMounting, failure: failure)
        }
    }

    /// 窗口关闭时移除卷变化的通知。
    isolated deinit {
        stopObserving()
    }

    /// 本机文件夹是不是一个卷的根，也就是正挂着；在后台取。
    ///
    /// - Parameter folder: 本机文件夹。
    nonisolated static func isVolumeRoot(_ folder: URL) async -> Bool {
        await Task.detached {
            let volume = try? folder.resourceValues(forKeys: [.volumeURLKey]).volume

            return volume?.standardizedFileURL.path == folder.resolvingSymlinksInPath().standardizedFileURL.path
        }.value
    }

    /// 读入打开的服务器仓库记下的本机位置。
    ///
    /// - Parameters:
    ///   - location: 本机位置。
    ///   - repository: 打开的服务器仓库。
    ///   - mountsInBackground: 打开仓库时为 true：方式是 SMB 或 sshfs 挂载时，连上 B 后在后台挂载一次。
    func load(_ location: ServerLocalLocation, for repository: RepositoryLocation, mountsInBackground: Bool) {
        self.repository = repository
        backgroundMountPending = mountsInBackground && location.method.mounting != nil
        apply(location)
    }

    /// 改换仓库目录的本机位置：上次挂载失败的原因清除；带文件夹时仓库目录先前与进行中的自动查找结果不再采用，并查看文件夹能不能用。
    ///
    /// 只改这次运行里的状态；记进偏好由调用方负责。
    ///
    /// - Parameter location: 新的本机位置。
    func apply(_ location: ServerLocalLocation) {
        if location != self.location {
            self.location = location
        }

        failure = nil
        refreshFolder()

        guard let path = repository?.path, location.folder != nil else {
            return
        }

        searches[path] = nil

        if lookups[path] != nil {
            lookups[path] = nil
        }

        // 文件夹随卷的挂载与卸载出现或消失
        startObserving()
    }

    /// 在后台查找这些 B 上的目录，并开始观察卷的变化。
    ///
    /// - Parameters:
    ///   - paths: B 上带 `.git` 的目录。
    ///   - host: 主机别名。
    ///   - runner: 仓库的执行器，核对用的标记文件经它写进 B 的 Git 目录。
    ///   - refreshes: 为 true 时已有结果的目录也重新查找；否则只查还没有结果的。本机位置带文件夹时仓库目录不查找。
    func locate(_ paths: [String], host: String, runner: GitRunner, refreshes: Bool) {
        source = (host, runner)
        startObserving()

        let locator = makeLocator(host)
        let pending = paths.filter { path in
            !(path == repository?.path && location.folder != nil) && (refreshes || lookups[path] == nil)
        }

        for path in pending {
            let id = UUID()
            lookups[path] = .searching

            let task = Task { [weak self] in
                let mount = await locator.locate(path, runner: runner)

                guard let self, searches[path]?.id == id else { return }

                lookups[path] = mount.map(Lookup.found) ?? .notMounted
            }

            searches[path] = (id, task)
        }
    }

    /// 重新连上 B 后，之前记为没有挂载的目录重新查找一次，不论本机位置是哪种方式。
    func relocateUnmounted() {
        guard let source else {
            return
        }

        let paths = lookups.filter { $0.value == .notMounted }.map(\.key)

        guard !paths.isEmpty else {
            return
        }

        locate(paths, host: source.host, runner: source.runner, refreshes: true)
    }

    /// 等这个目录进行中的查找结束；没有进行中的查找时立即返回。
    ///
    /// - Parameter path: B 上的目录。
    func waitForSearch(of path: String) async {
        await searches[path]?.task.value
    }

    /// 服务器上仓库目录在这台 Mac 上的位置；拿不到时为 nil。
    func repositoryMount() -> RemoteMount? {
        guard let path = repository?.path, case .available(let url) = status else {
            return nil
        }

        return RemoteMount(remotePath: path, localURL: url)
    }

    /// 关闭仓库时清除全部结果，停止观察卷的变化；进行中的查找与挂载照常结束，结果不再采用。
    func reset() {
        lookups = [:]
        repository = nil
        location = .automatic
        isFolderAvailable = false
        isMounting = false
        failure = nil
        mountTask = nil
        backgroundMountPending = false
        searches = [:]
        source = nil
        folderCheck = UUID()
        stopObserving()
    }

    /// 挂载开始与结束时更新状态：开始时清除上次失败的原因，结束时记下这次失败的原因。
    ///
    /// - Parameters:
    ///   - task: 进行中的挂载；nil 表示已结束。
    ///   - failure: 结束时这次失败的原因。
    func setMounting(_ task: Task<Void, Never>?, failure: LocalLocationFailure? = nil) {
        mountTask = task
        isMounting = task != nil
        self.failure = failure
    }

    /// 记下仓库目录查找或挂载后找到的位置。
    ///
    /// - Parameter mount: 找到并核对过的位置。
    func record(_ mount: RemoteMount) {
        searches[mount.remotePath] = nil
        lookups[mount.remotePath] = .found(mount)
    }

    /// 记下方式带的文件夹现在能不能用；只在值变化时写入，避免无谓的界面更新。
    ///
    /// - Parameter available: 指定的文件夹在，或 sshfs 挂载到的文件夹正挂着。
    func setFolderAvailable(_ available: Bool) {
        if isFolderAvailable != available {
            isFolderAvailable = available
        }
    }

    /// 重新查看方式带的文件夹能不能用：指定的文件夹看在不在；sshfs 挂载的文件夹在后台看是不是一个卷的根，不在主线程上取。
    func refreshFolder() {
        let check = UUID()
        folderCheck = check

        switch location {
        case .chosenFolder(let folder):
            setFolderAvailable(Self.directoryExists(folder))

        case .sshfsMount(let folder):
            Task { [weak self] in
                let mounted = await Self.isVolumeRoot(folder)

                guard let self, folderCheck == check else { return }

                setFolderAvailable(mounted)
            }

        case .automatic, .smbMount:
            setFolderAvailable(false)
        }
    }

}

// MARK: - Private

extension RepositoryMountState {
    /// 自动查找与 SMB 挂载时仓库目录的状态：找到了就是位置，其次是正在挂载、正在查找、上次失败与没有挂载。
    private static func status(of lookup: Lookup?, isMounting: Bool, failure: LocalLocationFailure?) -> Status {
        if case .found(let mount) = lookup {
            return .available(mount.localURL)
        }

        if isMounting {
            return .mounting
        }

        if lookup == .searching {
            return .searching
        }

        if let failure {
            return .failed(failure)
        }

        return lookup == .notMounted ? .notMounted : .unknown
    }

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

    /// 卷有变化时，重新查看方式带的文件夹，已经查过的目录全部重新查找。
    private func volumesChanged() {
        refreshFolder()

        guard let source else {
            return
        }

        locate(Array(lookups.keys), host: source.host, runner: source.runner, refreshes: true)
    }
}
