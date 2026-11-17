import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - AppIconSettingsTests

/// Appearance 页的应用图标一行：VoiceOver 把列表读成 “App Icon”，每组一行读出组名、只有所选的一行带选中状态；
/// 点一行换组失败时下方写出原因，各行恢复可用，所选的组与偏好都不变。
///
/// 经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct AppIconSettingsTests {
    /// 偏好里选的是午夜；临时 App 里没有图标资源，换组时取不到图标而失败，与写不进 App 包时一样抛出 `AppIconWriteError`。
    @Test("应用图标一行的名称，列表的选中与换组失败", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func rowAndList() async throws {
        let directory = AppIconControllerTests.makeDirectory()

        defer { try? FileManager.default.removeItem(at: directory) }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let app = try AppIconControllerTests.makeApp(in: directory)

        defaults.set(AppIconGroup.midnight.rawValue, forKey: AppIconGroup.key)

        var dockRestarts = 0

        let controller = try AppIconController(
            defaults: defaults,
            bundle: #require(Bundle(url: app)),
            restartDock: { dockRestarts += 1 }
        )

        let midnight = AppIconGroup.midnight.title
        let serverGhost = AppIconGroup.serverGhost.title

        // 列表读作 “App Icon:”；每组一行，选中的只有午夜一行
        let row = await AccessibilityProbe.elements(
            width: SettingsFormLayout.windowWidth,
            until: { elements in elements.contains { $0.role == "AXButton" && $0.isSelected } }
        ) {
            SettingsForm(layout: .appearance) {
                AppIconSettingsRow(controller: controller)
            }
        }

        let rows = row.filter { $0.role == "AXButton" }

        #expect(row.contains { $0.role == "AXGroup" && $0.name == AppLocalization.text("settings.appIcon.label") })
        #expect(Set(rows.map(\.name)) == Set(AppIconGroup.allCases.map(\.title)))
        #expect(rows.filter(\.isSelected).map(\.name) == [midnight])

        // 点服务器幽灵一行换组失败：下方写出原因，各行恢复可用，组与偏好仍是午夜
        let failure = AppIconWriteError().localizedDescription

        let failed = await AccessibilityProbe.elements(
            width: SettingsFormLayout.windowWidth,
            pressing: [serverGhost],
            until: { elements in
                elements.contains { $0.value == failure }
                    && elements.contains { $0.role == "AXButton" && $0.name == serverGhost && $0.isEnabled }
            }
        ) {
            SettingsForm(layout: .appearance) {
                AppIconSettingsRow(controller: controller)
            }
        }

        #expect(failed.filter { $0.role == "AXButton" && $0.isSelected }.map(\.name) == [midnight])
        #expect(controller.group == .midnight)
        #expect(AppIconGroup.current(in: defaults) == .midnight)
        #expect(dockRestarts == 0)
    }
}
