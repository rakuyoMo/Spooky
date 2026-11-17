import Foundation
import SpookyKit

// MARK: - LocalLocationFailure

/// Spooky 挂载仓库目录失败的原因，写在本机位置一行、Show in Finder 的提示与对话框的错误区里。
struct LocalLocationFailure: Error, Equatable {
    /// 本地化的原因，或 sshfs 原样的标准错误。
    let reason: String

    /// 原始输出，如 NetFS 返回的状态码；没有时为 nil。
    let output: String?

    /// 错误区的说明：原因与原始输出之间空一行。
    var message: String {
        output.map { reason + "\n\n" + $0 } ?? reason
    }

    /// 由挂载的失败换成说明：SMB 写系统对状态的说明与状态码；sshfs 照原样写标准错误，没有输出时写退出状态。
    ///
    /// - Parameter failure: 挂载的失败。
    init(_ failure: RemoteMountFailure) {
        switch failure {
        case .smb(let status):
            reason = RemoteMountFailure.description(ofSMBStatus: status)
            output = String(status)

        case .sshfs(let status, let standardError):
            reason = standardError.isEmpty
                ? AppLocalization.text("localLocation.sshfsFailed", Int(status))
                : standardError
            output = nil

        case .launch(let description):
            reason = description
            output = nil
        }
    }

    /// 直接给出原因。
    ///
    /// - Parameters:
    ///   - reason: 本地化的原因。
    ///   - output: 原始输出。
    init(reason: String, output: String? = nil) {
        self.reason = reason
        self.output = output
    }
}

// MARK: - Mount

extension RepositoryMountState {
    /// 挂载仓库目录并核对：SMB 挂上后在卷里找到仓库并记下所在的共享；sshfs 挂上后经标记文件核对选定的文件夹。
    ///
    /// 只做挂载与核对，不改这次运行里的本机位置，也不记偏好；SMB 找到的位置记进查找结果。任何结果都不卸载。
    ///
    /// - Parameters:
    ///   - location: 要挂载的本机位置，只有 SMB 与 sshfs 挂载有意义；SMB 带共享时挂它，没有时从共享列表选。
    ///   - host: 主机别名。
    ///   - runner: 仓库的执行器，核对用的标记文件经它写进 B 的 Git 目录。
    ///   - interactive: 用户发起时为 true，允许系统的登录框、共享列表与口令询问。
    /// - Returns: 挂上并核对通过时是要记下的本机位置（SMB 带上所在的共享），否则是失败的原因。
    func mount(
        _ location: ServerLocalLocation,
        host: String,
        runner: GitRunner,
        interactive: Bool
    ) async -> Result<ServerLocalLocation, LocalLocationFailure> {
        guard let path = repository?.path else {
            return .failure(LocalLocationFailure(reason: AppLocalization.text("localLocation.notInShare")))
        }

        switch location {
        case .smbMount(let share):
            return await mountSMB(path, share: share, host: host, runner: runner, interactive: interactive)

        case .sshfsMount(let folder):
            return await mountSSHFS(path, at: folder, host: host, runner: runner, interactive: interactive)

        case .automatic, .chosenFolder:
            return .success(location)
        }
    }

    /// 按现在的本机位置挂载仓库目录，期间是 “正在挂载”；成功后记下新的本机位置，失败时记下原因。已在挂载时等那一次的结果。
    ///
    /// SMB 有记下的共享时直接挂它；Mount Again 与 Show in Finder 是用户发起的，后台挂载不是。
    ///
    /// - Parameters:
    ///   - host: 主机别名。
    ///   - runner: 仓库的执行器。
    ///   - interactive: 用户发起时为 true，允许询问。
    func mountRepository(host: String, runner: GitRunner, interactive: Bool) async {
        if let mountTask {
            await mountTask.value
            return
        }

        guard let repository, [.smbMount, .sshfsMount].contains(location.method) else {
            return
        }

        let location = location
        let defaults = defaults

        let task = Task { [weak self] in
            guard let self else { return }

            let result = await mount(location, host: host, runner: runner, interactive: interactive)

            // 挂载期间换了仓库或改了本机位置时，结果不再采用
            guard self.repository == repository, self.location.method == location.method else {
                return
            }

            switch result {
            case .success(let mounted):
                ServerLocalLocation.store(mounted, for: repository, defaults: defaults)
                setMounting(nil)
                apply(mounted)

                // sshfs 挂上并核对过，文件夹此刻就能用
                if mounted.method == .sshfsMount {
                    setFolderAvailable(true)
                }

            case .failure(let failure):
                setMounting(nil, failure: failure)
            }
        }

        setMounting(task)
        await task.value

        // 被换掉的挂载不会自己清除 “正在挂载”
        if mountTask == task {
            setMounting(nil, failure: failure)
        }
    }

    /// 打开仓库、连上 B 之后在后台挂载一次：先查找或查看是否已经挂着，没有时检测可用条件，可用才挂载；不询问，失败只记下原因。
    ///
    /// 仓库开着时卷被推出，不再自动挂载。
    ///
    /// - Parameters:
    ///   - host: 主机别名。
    ///   - runner: 仓库的执行器。
    func mountInBackground(host: String, runner: GitRunner) {
        guard backgroundMountPending, let path = repository?.path else {
            return
        }

        backgroundMountPending = false

        Task {
            await RemoteCallbackRequest.$allowsInteraction.withValue(false) {
                guard await needsBackgroundMount(of: path), await isAvailable(on: host) else {
                    return
                }

                await mountRepository(host: host, runner: runner, interactive: false)
            }
        }
    }
}

// MARK: - Private

extension RepositoryMountState {
    /// 后台挂载前的判断：SMB 等仓库目录的查找结束、确认没有挂着且有记下的共享；sshfs 看文件夹是不是正挂着。
    private func needsBackgroundMount(of path: String) async -> Bool {
        switch location {
        case .smbMount(let share):
            await waitForSearch(of: path)
            return share != nil && lookups[path] == .notMounted

        case .sshfsMount(let folder):
            return await !Self.isVolumeRoot(folder)

        case .automatic, .chosenFolder:
            return false
        }
    }

    /// 现在的方式在这台 Mac 上可用。
    private func isAvailable(on host: String) async -> Bool {
        let methods = await mounter.methods(host)

        switch location.method {
        case .smbMount: return methods.contains(.smb)
        case .sshfsMount: return methods.contains(.sshfs)
        case .automatic, .chosenFolder: return false
        }
    }

    /// 挂载 SMB 共享，再按自动查找的办法在挂着的卷里找这个仓库；找不到时算失败，卷保持挂载。
    private func mountSMB(
        _ path: String,
        share: URL?,
        host: String,
        runner: GitRunner,
        interactive: Bool
    ) async -> Result<ServerLocalLocation, LocalLocationFailure> {
        if case .failure(let failure) = await mounter.mountSMB(host, share, interactive) {
            return .failure(LocalLocationFailure(failure))
        }

        guard let found = await makeLocator(host).locate(path, runner: runner) else {
            return .failure(LocalLocationFailure(reason: AppLocalization.text("localLocation.notInShare")))
        }

        if repository?.path == path {
            record(found)
        }

        let remount = await Task.detached { RemoteMountLocator.remountURL(of: found.localURL) }.value

        return .success(.smbMount(share: remount ?? share))
    }

    /// 用 sshfs 挂到选定的文件夹，再经标记文件核对它就是 B 上的这个仓库。
    private func mountSSHFS(
        _ path: String,
        at folder: URL,
        host: String,
        runner: GitRunner,
        interactive: Bool
    ) async -> Result<ServerLocalLocation, LocalLocationFailure> {
        var handler: RemoteCallbackHandler? = nil

        // 用户发起时经 askpass 询问私钥口令
        if interactive {
            handler = { await RemoteCallbackPresenter.shared.respond(to: $0) }
        }

        if case .failure(let failure) = await mounter.mountSSHFS(host, path, folder, handler) {
            return .failure(LocalLocationFailure(failure))
        }

        let mount = RemoteMount(remotePath: path, localURL: folder)

        guard await RemoteMountLocator.verify(path, through: mount, runner: runner) else {
            let reason = AppLocalization.text(
                "repositorySettings.localFolder.rejected.message",
                HomePath.abbreviated(folder.path),
                repository?.displayPath ?? path
            )

            return .failure(LocalLocationFailure(reason: reason))
        }

        return .success(.sshfsMount(folder: folder))
    }
}
