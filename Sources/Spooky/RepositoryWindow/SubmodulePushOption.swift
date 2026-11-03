import SpookyKit
import SwiftUI

// MARK: - SubmodulePushOption

/// 推送与同步对话框的 “Recurse Submodules” 选项：勾选项、说明，以及只在勾选时可用的处理方式。
///
/// 放在对话框的表单里，占两行：勾选项与说明是一行 `DialogFormOption`，方式菜单在下一行。
struct SubmodulePushOption: View {
    /// 是否递归处理子模块。
    @Binding
    var enabled: Bool

    /// 处理方式，存 `SubmodulePushMode` 的原始值。
    @Binding
    var mode: String

    /// 勾选项、说明与方式菜单依次相隔 8 pt，说明与方式菜单都与勾选项的标题文字对齐。
    var body: some View {
        DialogFormOption(
            title: AppLocalization.text("sync.pushSubmodules"),
            help: AppLocalization.text("sync.pushSubmodules.help"),
            isOn: $enabled
        )

        GridRow {
            Color.clear
                .frame(width: DialogMetrics.labelWidth, height: 0)
                .gridCellUnsizedAxes(.vertical)

            Picker("", selection: $mode) {
                Text(AppLocalization.text("sync.pushSubmodules.onDemand"))
                    .tag(SubmodulePushMode.onDemand.rawValue)

                Text(AppLocalization.text("sync.pushSubmodules.check"))
                    .tag(SubmodulePushMode.check.rawValue)
            }
            .labelsHidden()
            .buttonSizing(.flexible)
            .padding(.leading, 19)
            .disabled(!enabled)
            .accessibilityLabel(AppLocalization.text("sync.pushSubmodules"))
        }
    }
}
