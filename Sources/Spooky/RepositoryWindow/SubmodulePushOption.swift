import SpookyKit
import SwiftUI

// MARK: - SubmodulePushOption

/// 推送与同步对话框的 “Recurse Submodules” 选项：勾选项、说明，以及只在勾选时可用的处理方式。
struct SubmodulePushOption: View {
    /// 是否递归处理子模块。
    @Binding
    var enabled: Bool

    /// 处理方式，存 `SubmodulePushMode` 的原始值。
    @Binding
    var mode: String

    /// 勾选项下方依次是 11 pt 说明与方式菜单，都与勾选项的标题文字对齐。
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(AppLocalization.text("sync.pushSubmodules"), isOn: $enabled)

            Text(AppLocalization.text("sync.pushSubmodules.help"))
                .font(.system(size: 11))
                .padding(.leading, 19)
                .fixedSize(horizontal: false, vertical: true)

            Picker("", selection: $mode) {
                Text(AppLocalization.text("sync.pushSubmodules.onDemand"))
                    .tag(SubmodulePushMode.onDemand.rawValue)

                Text(AppLocalization.text("sync.pushSubmodules.check"))
                    .tag(SubmodulePushMode.check.rawValue)
            }
            .labelsHidden()
            .frame(width: 280)
            .padding(.leading, 19)
            .disabled(!enabled)
            .accessibilityLabel(AppLocalization.text("sync.pushSubmodules"))
        }
    }
}
