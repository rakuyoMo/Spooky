import AppKit
import Observation
import SpookyKit

// MARK: - RepositoryMountState

/// 服务器仓库与仓库目录以外的工作树在这台 Mac 上的挂载位置，按 B 上的目录记下查找结果；结果只在本次运行里保留。
///
/// 连上 B、工作树清单读到新的目录，以及这台 Mac 挂载或卸载卷时在后台查找。
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

    /// 按 B 上的目录记下的查找结果；还没开始查找的目录不在其中。
    private(set) var lookups: [String: Lookup] = [:]

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
    ///   - refreshes: 为 true 时已有结果的目录也重新查找；否则只查还没有结果的。
    func locate(_ paths: [String], host: String, runner: GitRunner, refreshes: Bool) {
        source = (host, runner)
        startObserving()

        let locator = makeLocator(host)

        for path in paths where refreshes || lookups[path] == nil {
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

    /// 关闭仓库时清除全部结果，停止观察卷的变化；进行中的查找照常结束并删掉标记，结果不再采用。
    func reset() {
        lookups = [:]
        requests = [:]
        source = nil
        stopObserving()
    }
}

// MARK: - Private

extension RepositoryMountState {
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

    /// 卷有变化时，已经查过的目录全部重新查找。
    private func volumesChanged() {
        guard let source else {
            return
        }

        locate(Array(lookups.keys), host: source.host, runner: source.runner, refreshes: true)
    }
}
