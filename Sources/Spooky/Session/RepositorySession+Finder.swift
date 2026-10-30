import Foundation
import SpookyKit

// MARK: - Finder

extension RepositorySession {
    /// 菜单、工具栏、右键菜单与快捷操作共用的规则：仓库目录能否在 Finder 中显示；服务器仓库要找到 B 上这个目录在本机的挂载。
    var canShowInFinder: Bool {
        finderURL() != nil
    }

    /// 仓库目录不能在 Finder 中显示时的提示：手动指定的目录现在找不到，或 B 上的这个目录没有挂载到这台 Mac、可以在仓库设置里手动指定；
    /// 能显示或还在查找时为 nil。
    var finderUnavailableTip: String? {
        guard let repository, repository.host != nil else {
            return nil
        }

        // 手动指定了目录时只看它在不在
        if let designation = mounts.designation {
            return designation.exists
                ? nil
                : AppLocalization.text(
                    "action.revealFinder.folderMissing",
                    HomePath.abbreviated(designation.mount.localURL.path)
                )
        }

        guard mounts.lookups[repository.path] == .notMounted else {
            return nil
        }

        return AppLocalization.text("action.revealFinder.notMounted", repository.displayPath)
    }

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
            return finderUnavailableTip
        }

        guard mounts.lookups[worktree.path] == .notMounted else {
            return nil
        }

        return AppLocalization.text("action.revealFinder.worktreeNotMounted", location.displayPath)
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

        return mounts.repositoryMount(of: repository.path)?.localURL(for: full)
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
            ? mounts.repositoryMount(of: repository.path)
            : foundMount(of: worktree.path)

        return mount?.localURL(for: worktree.path)
    }

    /// 核对选定的本机目录确实是 B 上的仓库目录，通过后记进这台 Mac 的偏好，仓库目录此后按它换算、不再自动查找。
    ///
    /// 核对经 SSH 在仓库的 Git 目录里临时放一个随机命名的标记文件，经本机目录看得到才算，随后删掉。
    ///
    /// - Parameter folder: 选定的本机目录。
    /// - Returns: 核对通过时为 true。
    func chooseLocalFolder(_ folder: URL) async -> Bool {
        guard let repository, repository.host != nil, let runner else {
            return false
        }

        let mount = RemoteMount(remotePath: repository.path, localURL: folder)

        guard await RemoteMountLocator.verify(repository.path, through: mount, runner: runner) else {
            return false
        }

        ServerLocalFolders.set(folder, for: repository)

        // 核对期间窗口换了仓库时只记进偏好
        if self.repository == repository {
            mounts.designate(folder, for: repository.path)
        }

        return true
    }

    /// 清除手动指定的本机目录，仓库目录恢复自动查找。
    func clearLocalFolder() {
        guard let repository else {
            return
        }

        ServerLocalFolders.set(nil, for: repository)
        mounts.designate(nil, for: repository.path)
        locateMounts()
    }

    /// 在后台查找服务器仓库的目录与仓库目录以外的工作树，已经有结果的目录不再查找；本机仓库与手动指定了本机目录的仓库目录不用查找。
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
