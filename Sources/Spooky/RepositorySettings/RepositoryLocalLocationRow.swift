import SpookyKit
import SwiftUI

// MARK: - RepositoryLocalLocationRow

/// 仓库设置 General 段的 Location on This Mac 一行，只有服务器仓库有：仓库目录在这台 Mac 上的本机位置怎样确定、现在在哪。
///
/// Change… 打开本机位置对话框，要连着 B；方式是 SMB 或 sshfs 挂载又没有挂着时另有 Mount Again。
struct RepositoryLocalLocationRow: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// `<方式>：<本机路径>`，没有本机路径时冒号后写状态；悬停时出现 Change… 与 Mount Again。
    var body: some View {
        let mounts = session.mounts

        RemoteSettingRow(
            label: AppLocalization.text("repositorySettings.localLocation"),
            value: AppLocalization.text(
                "localLocation.value",
                mounts.location.method.title,
                Self.detail(of: mounts.status)
            ),
            actions: actions
        )
    }

    /// 方式后面的本机路径（主目录缩写成 `~`）或拿不到它的状态。
    ///
    /// - Parameter status: 仓库目录的本机位置或拿不到它的原因。
    static func detail(of status: RepositoryMountState.Status) -> String {
        switch status {
        case .available(let url):
            return HomePath.abbreviated(url.path)

        case .unknown:
            #warning("TODO: 核实还没有查找结果（如还没连上 B）时这一行写什么；目前与正在查找相同")
            return AppLocalization.text("localLocation.searching")

        case .searching:
            return AppLocalization.text("localLocation.searching")

        case .mounting:
            return AppLocalization.text("localLocation.mounting")

        case .notMounted:
            return AppLocalization.text("localLocation.notMounted")

        case .failed(let failure):
            return failure.reason

        case .folderMissing(let folder):
            return AppLocalization.text("localLocation.folderMissing", HomePath.abbreviated(folder.path))
        }
    }
}

// MARK: - Private

extension RepositoryLocalLocationRow {
    /// Change… 在没连上 B 时禁用；方式是 SMB 或 sshfs 挂载、又没有挂着时另有 Mount Again。
    private var actions: [RemoteSettingAction] {
        let change = RemoteSettingAction(
            title: AppLocalization.text("localLocation.change"),
            isEnabled: session.connectionState == .connected,
            perform: showDialog
        )

        let mounts = session.mounts

        guard mounts.location.method.mounting != nil, mounts.repositoryMount() == nil else {
            return [change]
        }

        let mountAgain = RemoteSettingAction(
            title: AppLocalization.text("localLocation.mountAgain"),
            isEnabled: true,
            perform: mountAgain
        )

        return [change, mountAgain]
    }

    /// 以 sheet 在仓库窗口上打开本机位置对话框。
    private func showDialog() {
        guard let host = session.repository?.host, let runner = session.runner else {
            return
        }

        let form = LocalLocationForm(mounts: session.mounts, host: host, runner: runner)

        DialogWindow.present(on: session.presentingWindow) { close in
            LocalLocationDialog(form: form) { _ in close() }
        }
    }

    /// 用户发起的重新挂载：允许系统的登录框与口令询问，结果写回这一行。
    private func mountAgain() {
        guard let host = session.repository?.host, let runner = session.runner else {
            return
        }

        Task {
            await session.mounts.mountRepository(host: host, runner: runner, interactive: true)
        }
    }
}
