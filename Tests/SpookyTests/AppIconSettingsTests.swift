import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - AppIconSettingsTests

/// Appearance 页的应用图标一行：VoiceOver 把图标选择区读成 “App Icon”，每组一枚图标读出组名、只有所选的一枚带选中状态；
/// 界面上写出来的只有系列名，没有组名。点一枚换组失败时下方写出原因，各枚恢复可用，所选的组与偏好都不变。
///
/// 经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct AppIconSettingsTests {
    /// 偏好里选的是午夜；临时 App 里没有图标资源，换组时取不到图标而失败，与写不进 App 包时一样抛出 `AppIconWriteError`。
    @Test("应用图标一行的名称，图标的选中与换组失败", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
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
        let front = AppIconGroup.front.title

        // 图标选择区读作 “App Icon:”；每组一枚，自上而下、从左到右按系列与组的先后排开，选中的只有午夜一枚；
        // 写出来的文字有各系列名，没有组名
        let row = await AccessibilityProbe.elements(
            width: SettingsFormLayout.windowWidth,
            until: { elements in elements.contains { $0.role == "AXButton" && $0.isSelected } }
        ) {
            SettingsForm(layout: .appearance) {
                AppIconSettingsRow(controller: controller)
            }
        }

        let tiles = row
            .filter { $0.role == "AXButton" }
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }

        let texts = Set(row.filter { $0.role == "AXStaticText" }.map(\.value))

        #expect(row.contains { $0.role == "AXScrollArea" && $0.name == AppLocalization.text("settings.appIcon.label") })
        #expect(tiles.map(\.name) == AppIconSeries.allCases.flatMap(\.groups).map(\.title))
        #expect(tiles.filter(\.isSelected).map(\.name) == [midnight])
        #expect(texts.isSuperset(of: AppIconSeries.allCases.map(\.title)))
        #expect(texts.isDisjoint(with: AppIconGroup.allCases.map(\.title)))

        // 点身前一枚换组失败：下方写出原因，各枚恢复可用，组与偏好仍是午夜
        let failure = AppIconWriteError().localizedDescription

        let failed = await AccessibilityProbe.elements(
            width: SettingsFormLayout.windowWidth,
            pressing: [front],
            until: { elements in
                elements.contains { $0.value == failure }
                    && elements.contains { $0.role == "AXButton" && $0.name == front && $0.isEnabled }
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
