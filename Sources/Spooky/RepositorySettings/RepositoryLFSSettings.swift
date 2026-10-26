import SpookyKit
import SwiftUI

// MARK: - RepositoryLFSSettings

/// 仓库设置的 Git LFS 段：仓库所在机器上的 Git LFS 版本，以及根目录 `.gitattributes` 里交给 Git LFS 的规则。
///
/// 找不到 Git LFS 或版本过低时写出 PATH 的修复方向，需要执行 Git LFS 的按钮都不可用；
/// 仓库没有启用 Git LFS 时规则组只有 “Enable Git LFS”，启用后是 “Create Tracking Pattern” 与 “Open in Editor”。
struct RepositoryLFSSettings: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// `.gitattributes` 与其中交给 Git LFS 的规则。
    let file: RuleFile

    /// Git LFS 的版本与启用情况。
    let status: LFSStatus

    /// 版本组与规则组。
    var body: some View {
        RemoteSettingsGroup(title: AppLocalization.text("repositorySettings.lfs"))

        RemoteSettingRow(
            label: AppLocalization.text("lfs.version"),
            value: status.version ?? AppLocalization.text("lfs.version.missing")
        )

        if !status.isSupported {
            SettingWarningRow(
                text: AppLocalization.text(session.repository?.host == nil ? "lfs.unavailable.local" : "lfs.unavailable.remote")
            )
        }

        RemoteSettingsGroup(title: AppLocalization.text("repositorySettings.lfs.patterns"), actions: groupActions)

        if file.patterns.isEmpty {
            RemoteSettingRow(label: AppLocalization.text("repositorySettings.noPatterns"), value: "")
        }

        ForEach(Array(file.patterns.enumerated()), id: \.offset) { _, pattern in
            RemoteSettingRow(
                label: "",
                value: pattern,
                actions: [
                    RemoteSettingAction(
                        title: AppLocalization.text("lfs.remove"),
                        isEnabled: session.canWrite && status.isSupported
                    ) { session.untrackLFS(pattern) },
                ]
            )
            .monospaced()
        }
    }

    /// 规则组的按钮：没有启用时只能启用，启用后可以新建规则或直接编辑 `.gitattributes`。
    private var groupActions: [RemoteSettingAction] {
        guard status.isEnabled else {
            return [
                RemoteSettingAction(
                    title: AppLocalization.text("lfs.enable"),
                    isEnabled: session.canWrite && status.isSupported,
                    perform: session.enableLFS
                ),
            ]
        }

        return [
            RemoteSettingAction(
                title: AppLocalization.text("lfs.createPattern"),
                isEnabled: session.canWrite && status.isSupported
            ) { session.onFileRequest?(.form(.lfsPattern([]))) },
            RemoteSettingAction(
                title: AppLocalization.text("repositorySettings.openInEditor"),
                isEnabled: session.repository != nil
            ) { session.edit(file) },
        ]
    }
}
