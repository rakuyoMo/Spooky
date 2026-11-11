import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - AppIconSettingsTests

/// Appearance 页的应用图标一行与图标列表：VoiceOver 把这一行读成 “App Icon” 与组名；
/// 列表打开时选中当前所选的组，换组失败时错误区写出原因、对话框不关，所选的组与偏好都不变。
///
/// 经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct AppIconSettingsTests {
    /// 偏好里选的是午夜；临时 App 里没有图标资源，换组时取不到图标而失败，与写不进 App 包时一样抛出 `AppIconWriteError`。
    @Test("应用图标一行的名称，图标列表的初始选中与换组失败", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func rowAndPicker() async throws {
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

        // 这一行：组名读作 “App Icon:” 与组名
        let row = await AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.value == midnight } }
        ) {
            SettingsForm(layout: .appearance) {
                AppIconSettingsRow(controller: controller)
            }
        }

        let name = try #require(row.first { $0.value == midnight })

        #expect(name.name == AppLocalization.text("settings.appIcon.label"))

        // 图标列表：每组一行，选中的只有午夜一行
        var closed = false

        let picker = await AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXRow" && $0.isSelected } }
        ) {
            AppIconPickerDialog(controller: controller) {
                closed = true
            }
        }

        let selectedRows = picker.filter { $0.role == "AXRow" && $0.isSelected }
        let midnightText = try #require(picker.first { $0.role == "AXStaticText" && $0.value == midnight })

        let midnightCenter = CGPoint(
            x: midnightText.frame.midX,
            y: midnightText.frame.midY
        )

        let selectedRow = try #require(selectedRows.first)

        #expect(selectedRows.count == 1)
        #expect(selectedRow.frame.contains(midnightCenter))
        #expect(picker.contains { $0.role == "AXStaticText" && $0.value == AppIconGroup.serverGhost.title })

        // 按 Choose 换组失败：错误区写出原因，Choose 恢复可用，对话框不关，组与偏好仍是午夜
        let choose = AppLocalization.text("appIcon.choose.submit")
        let failure = AppIconWriteError().localizedDescription

        _ = await AccessibilityProbe.elements(
            pressing: [choose],
            until: { elements in
                // 对话框关掉了就不会再出现错误，不再等下去
                closed
                    || elements.contains { $0.value == failure }
                    && elements.contains { $0.role == "AXButton" && $0.name == choose && $0.isEnabled }
            }
        ) {
            AppIconPickerDialog(controller: controller) {
                closed = true
            }
        }

        #expect(!closed)
        #expect(controller.group == .midnight)
        #expect(AppIconGroup.current(in: defaults) == .midnight)
        #expect(dockRestarts == 0)
    }
}
