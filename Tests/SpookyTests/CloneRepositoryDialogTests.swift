import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - CloneRepositoryDialogTests

/// 克隆对话框的两个勾选框：在表单的输入列里，排在 Folder 一行之后，Initialize Submodules 默认勾上、在上，Use LFS Clone 默认不勾、在下。
///
/// 经辅助功能接口读本进程的窗口；进程没有辅助功能权限时跳过。
@MainActor
struct CloneRepositoryDialogTests {
    /// 两个勾选框的左缘与 Remote URL 输入框的相同；与 Folder 一行相隔 10，彼此相隔 8。
    @Test("勾选框的顺序、默认值与位置", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func options() async throws {
        let elements = await AccessibilityProbe.elements(
            until: { elements in elements.count { $0.role == "AXCheckBox" } == 2 }
        ) {
            CloneRepositoryDialog(hosts: [], close: { }, submit: { _ in })
        }

        let chooseTitle = AppLocalization.text("bookmarks.create.choose")
        let field = try #require(elements.first { $0.role == "AXTextField" })
        let choose = try #require(elements.first { $0.role == "AXButton" && $0.name == chooseTitle })

        let checkBoxes = elements
            .filter { $0.role == "AXCheckBox" }
            .sorted { $0.frame.minY < $1.frame.minY }

        try #require(checkBoxes.count == 2)

        let titles = [AppLocalization.text("clone.submodules"), AppLocalization.text("clone.lfs")]

        #expect(checkBoxes.map(\.name) == titles)
        #expect(checkBoxes.map(\.value) == ["1", "0"])

        for checkBox in checkBoxes {
            #expect(abs(checkBox.frame.minX - field.frame.minX) <= 1)
        }

        #expect(abs(checkBoxes[0].frame.minY - choose.frame.maxY - 10) <= 1.5)
        #expect(abs(checkBoxes[1].frame.minY - checkBoxes[0].frame.maxY - 8) <= 1.5)
    }
}
