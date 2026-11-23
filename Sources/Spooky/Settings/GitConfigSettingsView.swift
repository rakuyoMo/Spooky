import SpookyKit
import SwiftUI

// MARK: - GitConfigSettingsView

/// Git Config 页：本机使用的 Git 程序、本机全局配置里的提交人身份、提交签名，以及外部比较、合并工具，组间以分隔线隔开；修改立即生效。
struct GitConfigSettingsView: View {
    /// 全局配置的读写状态。
    @State
    private var model = GlobalGitConfigModel()

    /// 标签右对齐、控件列宽 310 pt 的表单，读写失败时在底部说明。
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
                SettingsFailureView(title: failure.title, details: failure.details, isOutput: true)
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
