import Foundation
import SpookyKit

// MARK: - Finder

extension RepositoryMountState {
    /// 仓库目录不能直接在 Finder 中显示的原因：还没连上 B 或还没有查找结果、没有挂载、指定的文件夹不在，或 Spooky 上次挂载失败的原因；
    /// 能直接显示与没有打开服务器仓库时为 nil。
    var unavailableReason: String? {
        guard let repository, let host = repository.host else {
            return nil
        }

        switch status {
        case .available:
            return nil

        case .folderMissing(let folder):
            return AppLocalization.text("action.revealFinder.folderMissing", HomePath.abbreviated(folder.path))

        case .failed(let failure):
            return failure.reason

        case .notMounted, .mounting:
            return AppLocalization.text("action.revealFinder.notMounted", repository.displayPath)

        case .unknown, .searching:
            return AppLocalization.text("action.revealFinder.notConnected", host)
        }
    }

    /// Show in Finder 的查找：先等进行中的挂载结束；自动查找与 SMB 挂载重新查找仓库目录一次，不沿用之前 “没有挂载” 的结果，
    /// 已在查找时等它的结果；sshfs 挂载与指定文件夹重新查看文件夹。
    ///
    /// - Parameters:
    ///   - host: 主机别名。
    ///   - runner: 仓库的执行器，核对用的标记文件经它写进 B 的 Git 目录。
    func relocateRepository(host: String, runner: GitRunner) async {
        await mountTask?.value

        guard let path = repository?.path else {
            return
        }

        guard location.folder == nil else {
            await checkFolder()
            return
        }

        if lookups[path] != .searching {
            locate([path], host: host, runner: runner, refreshes: true)
        }

        await waitForSearch(of: path)
    }

    /// 重新查看方式带的文件夹并等结果：指定的文件夹看在不在，sshfs 挂载到的文件夹看是不是正挂着；自动查找与 SMB 挂载不用查看。
    ///
    /// 不经连接 B，仓库管理与最近克隆据此决定能否直接打开 Finder。
    func checkFolder() async {
        switch location {
        case .chosenFolder:
            refreshFolder()

        case .sshfsMount(let folder):
            let mounted = await Self.isVolumeRoot(folder)

            // 查看期间改换了本机位置时，结果不再采用
            if location == .sshfsMount(folder: folder) {
                setFolderAvailable(mounted)
            }

        case .automatic, .smbMount:
            return
        }
    }
}
