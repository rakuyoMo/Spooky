import Foundation
import SpookyKit

// MARK: - Finder

extension RepositorySession {
    /// 工作树能否在 Finder 中显示；失效的工作树不能。
    func canShowInFinder(_ worktree: Worktree) -> Bool {
        finderURL(of: worktree) != nil
    }

    /// 工作树不能在 Finder 中显示时的提示；仓库目录里的工作树沿用仓库目录的提示，其余只说明没有挂载。
    func finderUnavailableTip(of worktree: Worktree) -> String? {
        guard
            let repository,
            repository.host != nil,
            let location = location(of: worktree)
        else { return nil }

        if Self.path(worktree.path, isInside: repository.path) {
            return mounts.unavailableReason
        }

        guard mounts.lookups[worktree.path] == .notMounted else {
            return nil
        }

        return AppLocalization.text("action.revealFinder.notMounted", location.displayPath)
    }

    /// 仓库里的路径在这台 Mac 上的位置：本机仓库直接拼接；服务器仓库按手动指定的目录或查到的挂载换算，没有挂载或还在查找时为 nil。
    ///
    /// - Parameter path: 仓库里的相对路径；nil 表示仓库目录本身。
    func finderURL(_ path: String? = nil) -> URL? {
        guard let repository else {
            return nil
        }

        let full = path.map { repository.path + "/" + $0 } ?? repository.path

        guard repository.host != nil else {
            return URL(filePath: full)
        }

        return mounts.repositoryMount()?.localURL(for: full)
    }

    /// 工作树在这台 Mac 上的位置；失效的工作树为 nil。服务器上仓库目录里的工作树按仓库目录换算，其余按各自查到的挂载。
    func finderURL(of worktree: Worktree) -> URL? {
        guard worktree.isValid, let repository else {
            return nil
        }

        guard repository.host != nil else {
            return URL(filePath: worktree.path)
        }

        let mount = Self.path(worktree.path, isInside: repository.path)
            ? mounts.repositoryMount()
            : foundMount(of: worktree.path)

        return mount?.localURL(for: worktree.path)
    }

    /// 服务器仓库的目录或其中的文件不能直接在 Finder 中显示时的流程：用本会话的本机位置状态，连接经本会话；本机仓库为 nil。
    ///
    /// - Parameter paths: 仓库里的相对路径；为空时是仓库目录。
    func showInFinderFlow(_ paths: [String]) -> ShowInFinderFlow? {
        guard let repository, let host = repository.host else {
            return nil
        }

        let targets = paths.isEmpty ? [repository.path] : paths.map { repository.path + "/" + $0 }

        return ShowInFinderFlow(
            mounts: mounts,
            host: host,
            paths: targets,
            isConnected: connectionState == .connected
        ) { [weak self] in
            guard let self else { return .ended }

            if let failure = await connectNow() {
                return .failed(failure)
            }

            // 等待期间关闭或换了仓库时流程不再继续
            guard self.repository == repository, let runner else { return .ended }

            return .connected(runner)
        }
    }

    /// 打开服务器仓库时读入这台 Mac 偏好里记下的本机位置；方式是 SMB 或 sshfs 挂载时，连上 B 后在后台挂载一次。
    func loadLocalLocation() {
        guard let repository, repository.host != nil else {
            return
        }

        mounts.load(
            ServerLocalLocation.stored(for: repository, defaults: mounts.defaults),
            for: repository,
            mountsInBackground: true
        )
    }

    /// 添加服务器仓库时选了挂载方式：仓库打开后本机位置记为这种方式，随即挂载。
    ///
    /// 用户发起，允许系统的登录框与共享列表；这一次代替打开仓库后的后台挂载。失败不弹提示，原因记进本机位置状态。
    ///
    /// - Parameter location: 选的 SMB 或 sshfs 挂载。
    func mountAddedRepository(_ location: ServerLocalLocation) {
        guard let repository, let host = repository.host, let runner else {
            return
        }

        // sshfs 的文件夹此刻还没挂上，只记下方式，不标成能用
        ServerLocalLocation.store(location, for: repository, defaults: mounts.defaults)
        mounts.backgroundMountPending = false
        mounts.apply(location)

        Task {
            await mounts.mountRepository(host: host, runner: runner, interactive: true)
        }
    }

    /// 在后台查找服务器仓库的目录与仓库目录以外的工作树，已经有结果的目录不再查找；本机仓库与本机位置带文件夹的仓库目录不用查找。
    /// 随后做打开仓库后还没做过的那一次后台挂载。
    ///
    /// 读到工作树清单时调用：这时连得上 B，要查的目录也都知道了；这台 Mac 挂载或卸载卷时由 ``RepositoryMountState`` 重新查找。
    func locateMounts() {
        guard let repository, let host = repository.host, let runner else {
            return
        }

        let worktreePaths = worktrees.items
            .filter { $0.isValid && !$0.isBare && !Self.path($0.path, isInside: repository.path) }
            .map(\.path)

        mounts.locate(
            [repository.path] + worktreePaths,
            host: host,
            runner: runner,
            refreshes: false
        )

        mounts.mountInBackground(host: host, runner: runner)
    }
}

// MARK: - Private

extension RepositorySession {
    /// 路径是不是这个目录本身或在它里面。
    private static func path(_ path: String, isInside directory: String) -> Bool {
        path == directory || path.hasPrefix(directory.hasSuffix("/") ? directory : directory + "/")
    }

    /// B 上的这个目录已经找到并核对过的挂载。
    private func foundMount(of path: String) -> RemoteMount? {
        guard case .found(let mount) = mounts.lookups[path] else {
            return nil
        }

        return mount
    }
}
