import SpookyKit
import SwiftUI

// MARK: - IntegrationSettingsView

/// Integration 页：github.com 仓库链接由哪个 App 打开、Gerrit 推送的开关、本机全局配置里 Issue 追踪的地址模板与编号前缀、本机使用的 SSH agent，以及崩溃报告是否直接打开问题页。
struct IntegrationSettingsView: View {
    /// 全局配置的读写状态。
    @State
    private var model = GlobalGitConfigModel()

    /// 分支右键菜单与工具栏提供推送到 Gerrit 的入口。
    @AppStorage(GerritPush.key)
    private var enablesGerrit = false

    /// 上次运行崩溃时不再询问，直接打开预填的问题页。
    @AppStorage(CrashReporter.alwaysSendKey)
    private var alwaysSendsCrashReports = false

    /// 正在编辑 Issue 追踪。
    @State
    private var editingIssueTracking = false

    /// 正在显示的模板不合法的原因。
    @State
    private var shownProblem: String?

    /// 标签右对齐、控件列 278 pt 的表单，组间以分隔线隔开；读写失败时在底部说明。
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GitHubLinksSettingsRow()

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                GridRow {
                    Text(AppLocalization.text("settings.gerrit"))
                        .gridColumnAlignment(.trailing)

                    Toggle(AppLocalization.text("settings.gerrit.enable"), isOn: $enablesGerrit)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 278, alignment: .leading)
                }

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                issueTrackingRows

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                SSHAgentSettingsRow()

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                GridRow {
                    Text(AppLocalization.text("settings.crashReports"))
                        .gridColumnAlignment(.trailing)

                    Toggle(AppLocalization.text("settings.crashReports.always"), isOn: $alwaysSendsCrashReports)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 278, alignment: .leading)
                }
            }

            if let failure = model.failure {
                GitConfigFailureView(failure: failure)
            }
        }
        .padding(40)
        .frame(width: 900, alignment: .top)
        .task { await model.reload() }
        .sheet(isPresented: $editingIssueTracking) {
            IssueTrackingDialog(
                template: model.configuration.issueTrackerTemplate ?? "",
                prefix: model.configuration.issueNumberPrefix ?? "",
                save: saveIssueTracking,
                close: { editingIssueTracking = false }
            )
        }
    }
}

// MARK: - Private

extension IntegrationSettingsView {
    /// 地址模板与编号前缀两行只读的值，下面是编辑按钮；模板不合法时右侧出现警告按钮。
    @ViewBuilder
    private var issueTrackingRows: some View {
        let template = model.configuration.issueTrackerTemplate
        let problem = template.flatMap(IssueTracking.templateProblem)

        GridRow {
            Text(AppLocalization.text("issueTracking.url"))
                .gridColumnAlignment(.trailing)

            value(template)
                .overlay(alignment: .trailing) {
                    if let problem {
                        Button {
                            shownProblem = problem
                        } label: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.borderless)
                        .help(AppLocalization.text("issueTracking.invalid"))
                        .accessibilityLabel(AppLocalization.text("issueTracking.invalid"))
                        .alignmentGuide(.trailing) { $0[.leading] - 8 }
                    }
                }
        }

        GridRow {
            Text(AppLocalization.text("issueTracking.prefix"))
                .gridColumnAlignment(.trailing)

            value(model.configuration.issueNumberPrefix)
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Button(AppLocalization.text("issueTracking.edit")) { editingIssueTracking = true }
                .disabled(!model.isLoaded)
                .frame(width: 278, alignment: .leading)
        }
        .alert(
            AppLocalization.text("issueTracking.invalid"),
            isPresented: Binding(get: { shownProblem != nil }, set: { if !$0 { shownProblem = nil } }),
            presenting: shownProblem
        ) { _ in
            Button(AppLocalization.text("action.ok")) { shownProblem = nil }
        } message: { problem in
            Text(problem)
        }
    }

    /// 一个可选中的只读值；没有配置时写明未配置。
    private func value(_ text: String?) -> some View {
        Text(text ?? AppLocalization.text("issueTracking.notConfigured"))
            .foregroundStyle(text == nil ? .secondary : .primary)
            .textSelection(.enabled)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: 278, alignment: .leading)
    }

    /// 两项写进本机全局配置；空值删除对应的键。
    private func saveIssueTracking(_ template: String, _ prefix: String) {
        Task {
            await model.write([
                (GlobalGitConfiguration.Key.issueTrackerTemplate, template.isEmpty ? nil : template),
                (GlobalGitConfiguration.Key.issueNumberPrefix, prefix.isEmpty ? nil : prefix),
            ])
        }
    }
}
