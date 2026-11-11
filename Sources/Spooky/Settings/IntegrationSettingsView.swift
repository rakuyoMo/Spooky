import SwiftUI

// MARK: - IntegrationSettingsView

/// Integration 页：github.com 仓库链接由哪个 App 打开、本机使用的 SSH agent，以及崩溃报告是否直接打开问题页。
struct IntegrationSettingsView: View {
    /// 上次运行崩溃时不再询问，直接打开预填的问题页。
    @AppStorage(CrashReporter.alwaysSendKey)
    private var alwaysSendsCrashReports = false

    /// 标签右对齐、控件列从 562 pt 起宽 254 pt 的表单，组间以分隔线隔开。
    var body: some View {
        SettingsForm(layout: .integration) {
            GitHubLinksSettingsRow()

            SettingsSeparator()

            SSHAgentSettingsRow()

            SettingsSeparator(next: .checkbox)

            crashReportsRow
        }
    }
}

// MARK: - Private

extension IntegrationSettingsView {
    /// 崩溃报告的勾选框，下方 4 pt 是比勾选框缩进 20 pt 的 11 pt 说明；说明可以排到窗口右边距。
    private var crashReportsRow: some View {
        SettingsRow {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(AppLocalization.text("settings.crashReports.always"), isOn: $alwaysSendsCrashReports)
                    .fixedSize(horizontal: false, vertical: true)

                // 说明与勾选框的文字对齐
                Text(AppLocalization.text("settings.crashReports.help"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 20)
            }
        }
    }
}
