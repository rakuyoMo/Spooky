import SpookyKit
import SwiftUI

// MARK: - GitConfigSettingsView

/// Git Config 页：本机使用的 Git 程序、本机全局配置里的提交人身份、提交签名，以及外部比较、合并工具，组间以分隔线隔开；修改立即生效。
struct GitConfigSettingsView: View {
    /// 全局配置的读写状态。
    @State
    private var model = GlobalGitConfigModel()

    /// 标签右对齐、控件列从 490 pt 起宽 310 pt 的表单，读写失败时在底部说明。
    var body: some View {
        SettingsForm(layout: .gitConfig) {
            GitProgramSettingsRow()

            SettingsSeparator()

            GitIdentityRows(model: model)

            SettingsSeparator()

            GitSigningRows(model: model)

            SettingsSeparator()

            ExternalToolSettingsRows()

            // 说明与分隔线左右对齐
            if let failure = model.failure {
                GitConfigFailureView(failure: failure)
                    .padding(.top, 16)
                    .padding(.horizontal, SettingsFormLayout.separatorInset)
            }
        }
        .task {
            await model.reload()
            await model.reloadKeys()
        }
    }
}

// MARK: - GitConfigFailureView

/// 读写全局配置失败时的说明：黄色警告图标、标题与可选中的 Git 原文。
struct GitConfigFailureView: View {
    /// 失败的标题与原文。
    let failure: GlobalGitConfigModel.Failure

    /// 图标挂在左侧，标题与原文上下排列。
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(failure.title)
                    .font(.system(size: 12, weight: .semibold))

                Text(failure.details)
                    .font(.system(size: 11).monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
