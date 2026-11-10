import AppKit
import SwiftUI

// MARK: - AppIconSettingsRow

/// Appearance 页的 “App Icon:” 一行：所选的组的图标与组名，“Change…” 在 Settings 窗口上以 sheet 打开图标列表。
struct AppIconSettingsRow: View {
    /// App 图标的控制器；App 不是经 `SpookyApplicationController` 启动时为 nil，这一行不显示。
    let controller: AppIconController?

    /// 图标列表是否打开。
    @State
    private var isChoosing = false

    /// 右对齐的标签，控件列里依次是 64 pt 的图标、组名与 “Change…”，与上方的外观一行相距 8 pt；
    /// VoiceOver 把图标与组名读成 “App Icon” 与组名。
    var body: some View {
        if let controller {
            SettingsRow(AppLocalization.text("settings.appIcon.label")) {
                HStack(spacing: 8) {
                    Image(nsImage: controller.unlitIcon ?? NSImage())
                        .resizable()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)

                    Text(controller.group.title)
                        .accessibilityLabel(AppLocalization.text("settings.appIcon.label"))
                        .accessibilityValue(controller.group.title)

                    Button(AppLocalization.text("settings.appIcon.change")) {
                        isChoosing = true
                    }
                    .sheet(isPresented: $isChoosing) {
                        AppIconPickerDialog(controller: controller) {
                            isChoosing = false
                        }
                    }
                }
            }
            .padding(.top, SettingsFormLayout.rowSpacing)
        }
    }

    /// 创建这一行。
    /// - Parameter controller: App 图标的控制器，默认取 App 自己的；测试传入指向临时 App 的控制器
    init(
        controller: AppIconController? = (NSApp.delegate as? SpookyApplicationController)?.appIconController
    ) {
        self.controller = controller
    }
}
