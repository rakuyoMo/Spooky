import SpookyKit
import SwiftUI

// MARK: - SSHAgentSettingsRow

/// Settings → Integration 里 SSH Agent 的两行：弹出菜单与 11 pt 的说明；所选 agent 没有运行时，菜单旁出现警告按钮。
struct SSHAgentSettingsRow: View {
    /// 所选的 agent 与它是否在运行。
    let preferences: LocalExecutionPreferences

    /// 是否正在显示警告的说明。
    @State
    private var showsWarning = false

    /// 右对齐的标签加 278 pt 宽的弹出菜单，下一行是说明。
    var body: some View {
        GridRow {
            Text(AppLocalization.text("settings.sshAgent"))
                .gridColumnAlignment(.trailing)

            HStack(spacing: 8) {
                picker

                if preferences.sshAgentRunning == .some(false) {
                    warningButton
                }
            }
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Text(AppLocalization.text("settings.sshAgent.description"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 278, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 创建 SSH Agent 一行。
    ///
    /// - Parameter preferences: 读写的偏好；测试使用独立偏好域的实例。
    init(preferences: LocalExecutionPreferences = .shared) {
        self.preferences = preferences
    }
}

// MARK: - Private

extension SSHAgentSettingsRow {
    /// 候选的 agent，选中即保存并重新检查。
    private var picker: some View {
        Picker(
            "",
            selection: Binding(
                get: { preferences.sshAgent },
                set: { preferences.selectSSHAgent($0) }
            )
        ) {
            ForEach(SSHAgent.allCases, id: \.self) { agent in
                Text(Self.title(agent)).tag(agent)
            }
        }
        .labelsHidden()
        .frame(width: 278)
        .accessibilityLabel(AppLocalization.text("settings.sshAgent"))
    }

    /// 16 pt 的警告按钮，点击后说明 agent 没有运行的原因与解决办法。
    private var warningButton: some View {
        Button {
            showsWarning = true
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.borderless)
        .help(AppLocalization.text("settings.sshAgent.warning"))
        .accessibilityLabel(AppLocalization.text("settings.sshAgent.warning"))
        .alert(AppLocalization.text("settings.sshAgent.warning"), isPresented: $showsWarning) { } message: {
            Text(Self.warning(preferences.sshAgent))
        }
    }

    /// 菜单里 agent 的名称。
    private static func title(_ agent: SSHAgent) -> String {
        switch agent {
        case .system: AppLocalization.text("settings.sshAgent.system")
        case .onePassword: AppLocalization.text("settings.sshAgent.onePassword")
        }
    }

    /// agent 没有运行时的说明。
    private static func warning(_ agent: SSHAgent) -> String {
        switch agent {
        case .system: AppLocalization.text("settings.sshAgent.warning.system")
        case .onePassword: AppLocalization.text("settings.sshAgent.warning.onePassword")
        }
    }
}
