import AppKit
import SpookyKit

// MARK: - Show in Finder

extension SpookyApplicationController {
    /// 仓库管理与最近克隆里在 Finder 中显示仓库目录。
    ///
    /// 本机仓库直接打开；服务器仓库有窗口开着时交给那个会话的流程，沿用它的连接与查找结果；
    /// 没有时为这次建一份本机位置状态，用完不留：能不经连接确定位置时直接打开，否则挂 sheet，先连接再查找、挂载或设置，不打开仓库。
    ///
    /// - Parameters:
    ///   - location: 仓库。
    ///   - source: 发起的窗口，sheet 挂在它上面。
    func showInFinder(_ location: RepositoryLocation, from source: RepositoryWindowController) {
        if let url = location.localURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }

        guard let session = windows.first(where: { $0.session.repository == location })?.session else {
            Task {
                await showUnopened(location, from: source)
            }

            return
        }

        if let url = session.finderURL() {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else if let flow = session.showInFinderFlow([]) {
            present(flow, for: location, on: source)
        }
    }
}

// MARK: - Private

extension SpookyApplicationController {
    /// 没有窗口开着的服务器仓库：读入偏好里记下的本机位置，指定的文件夹在、或 sshfs 挂载到的文件夹正挂着时直接打开；
    /// 否则流程按添加服务器仓库的体检建立连接。
    private func showUnopened(_ location: RepositoryLocation, from source: RepositoryWindowController) async {
        guard let host = location.host, let remote = GitRunner(location: location).remote else {
            return
        }

        let mounts = RepositoryMountState()
        mounts.load(ServerLocalLocation.stored(for: location), for: location, mountsInBackground: false)
        await mounts.checkFolder()

        if let mount = mounts.repositoryMount() {
            NSWorkspace.shared.activateFileViewerSelecting([mount.localURL])
            return
        }

        let flow = ShowInFinderFlow(
            mounts: mounts,
            host: host,
            paths: [location.path],
            isConnected: await remote.state == .connected
        ) {
            do {
                return try await .connected(RepositoryManagerController.openedRunner(for: location))
            } catch {
                return .failed(AppFailure(error: error, opening: true, location: location))
            }
        }

        present(flow, for: location, on: source)
    }

    /// 在发起的窗口上挂 Show in Finder 的 sheet，先关闭最近克隆的弹出框；流程进行期间登记这个仓库，结束后撤销登记再交还连接。
    private func present(_ flow: ShowInFinderFlow, for location: RepositoryLocation, on source: RepositoryWindowController) {
        guard let window = source.window, window.attachedSheet == nil else {
            return
        }

        source.clonePopover?.close()
        finderFlows[location, default: 0] += 1

        flow.onFinish = { [weak self, weak source] in
            self?.endFinderFlow(location, in: source)
        }

        DialogWindow.present(on: window) { close in
            ShowInFinderDialog(flow: flow, close: close)
        }
    }

    /// Show in Finder 的流程结束：撤销登记后交还连接；所在窗口的仓库管理详情区正显示这个仓库时，留给详情区换选中或离开时交还。
    private func endFinderFlow(_ location: RepositoryLocation, in source: RepositoryWindowController?) {
        let remaining = (finderFlows[location] ?? 1) - 1
        finderFlows[location] = remaining > 0 ? remaining : nil

        if let source, source.showsManager, source.session.selectedRecentLocation == location {
            return
        }

        releaseConnection(location)
    }
}
