import AppKit
import SpookyKit
import SwiftUI

// MARK: - RepositoryLocalFolderRow

/// 仓库设置 General 段的 Local Folder 一行，只有服务器仓库有：B 上的仓库目录在这台 Mac 上对应的本机目录，自动找不到挂载时手动指定。
///
/// Choose… 要连着 B，选定目录后经标记文件核对一次，通过才保存，没通过时以提示版说明；Clear 删掉记录，恢复自动查找。
struct RepositoryLocalFolderRow: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 指定的目录（主目录缩写成 `~`）或 “Not set”，悬停时出现 Choose… 与 Clear。
    var body: some View {
        let folder = session.mounts.designation?.mount.localURL

        RemoteSettingRow(
            label: AppLocalization.text("repositorySettings.localFolder"),
            value: folder.map { HomePath.abbreviated($0.path) }
                ?? AppLocalization.text("repositorySettings.localFolder.none"),
            small: true,
            actions: actions(folder: folder)
        )
    }

    /// 核对没有通过时，以提示版挂在仓库窗口上说明选的目录不是 B 上的这个仓库；只有 Close。
    ///
    /// - Parameter folder: 没有通过核对的目录。
    func showRejection(of folder: URL) {
        let message = AppLocalization.text(
            "repositorySettings.localFolder.rejected.message",
            HomePath.abbreviated(folder.path),
            session.repository?.displayPath ?? ""
        )

        DialogWindow.present(on: session.presentingWindow) { close in
            DialogLayout(
                title: AppLocalization.text("repositorySettings.localFolder.rejected"),
                message: message,
                submitTitle: AppLocalization.text("action.close"),
                cancel: nil,
                submit: close
            )
        }
    }
}

// MARK: - Private

extension RepositoryLocalFolderRow {
    /// Choose… 在没连上 B 时禁用；指定了目录时另有 Clear。
    private func actions(folder: URL?) -> [RemoteSettingAction] {
        let choose = RemoteSettingAction(
            title: AppLocalization.text("repositorySettings.localFolder.choose"),
            isEnabled: session.connectionState == .connected,
            perform: chooseFolder
        )

        guard folder != nil else {
            return [choose]
        }

        let clear = RemoteSettingAction(
            title: AppLocalization.text("repositorySettings.localFolder.clear"),
            isEnabled: true,
            perform: session.clearLocalFolder
        )

        return [choose, clear]
    }

    /// 在仓库窗口上以 sheet 打开目录选择面板；选定后核对，没通过时说明原因，原来的记录不变。
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.directoryURL = session.mounts.designation?.mount.localURL

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else {
                return
            }

            Task {
                if await !session.chooseLocalFolder(url) {
                    showRejection(of: url)
                }
            }
        }

        guard let window = NSApp.keyWindow else {
            finish(panel.runModal())
            return
        }

        panel.beginSheetModal(for: window, completionHandler: finish)
    }
}
