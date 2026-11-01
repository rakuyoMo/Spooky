import AppKit
import SpookyKit
import SwiftUI

// MARK: - RepositoryLocalFolderRow

/// 仓库设置 General 段的 Local Folder 一行，只有服务器仓库有：B 上的仓库目录在这台 Mac 上对应的本机目录，自动找不到挂载时手动指定。
///
/// Choose… 要连着 B，选定目录后经标记文件核对一次，通过才保存；Clear 删掉记录，恢复自动查找。
struct RepositoryLocalFolderRow: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 核对没有通过的目录，用来说明它不是这个仓库；没有时不显示提示。
    @State
    private var rejected: URL?

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
        .alert(
            AppLocalization.text("repositorySettings.localFolder.rejected"),
            isPresented: Binding(
                get: { rejected != nil },
                set: { if !$0 { rejected = nil } }
            )
        ) { } message: {
            Text(rejectedMessage)
        }
    }
}

// MARK: - Private

extension RepositoryLocalFolderRow {
    /// 核对失败的说明：选的目录不是 B 上的这个仓库。
    private var rejectedMessage: String {
        AppLocalization.text(
            "repositorySettings.localFolder.rejected.message",
            rejected.map { HomePath.abbreviated($0.path) } ?? "",
            session.repository?.displayPath ?? ""
        )
    }

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
                    rejected = url
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
