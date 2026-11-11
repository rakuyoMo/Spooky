import AppKit
import SwiftUI

// MARK: - AppIconSettingsRow

/// Appearance 页的 “App Icon:” 一行：所选的组的图标与组名，“Change…” 在 Settings 窗口上以 sheet 打开图标列表。
struct AppIconSettingsRow: View {
    /// 图标的边长。
    private static let iconSize: CGFloat = 64

    /// App 图标的控制器；App 不是经 `SpookyApplicationController` 启动时为 nil，这一行不显示。
    let controller: AppIconController?

    /// 图标列表是否打开。
    @State
    private var isChoosing = false

    /// 右对齐的标签，控件列里依次是 64 pt 的图标、组名与 “Change…”，与上方的外观一行相距 8 pt；
    /// 组名到图标底板与到按钮看上去一样远。VoiceOver 把图标与组名读成 “App Icon” 与组名。
    var body: some View {
        if let controller {
            SettingsRow(AppLocalization.text("settings.appIcon.label")) {
                HStack(spacing: 8) {
                    Image(nsImage: controller.unlitIcon ?? NSImage())
                        .resizable()
                        .frame(width: Self.iconSize, height: Self.iconSize)
                        .accessibilityHidden(true)

                    Text(controller.group.title)
                        .accessibilityLabel(AppLocalization.text("settings.appIcon.label"))
                        .accessibilityValue(controller.group.title)

                    // 图标四周是透明边，组名到底板比到图标的边框远；按钮前补上同样宽的一段
                    Button(AppLocalization.text("settings.appIcon.change")) {
                        isChoosing = true
                    }
                    .padding(.leading, Self.iconSize * AppIconGroup.plateInset)
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
