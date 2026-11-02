import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - CloneRepositoryDialogTests

/// 克隆对话框的选项区：展开后两个勾选框从表单的输入列开始。
///
/// 经辅助功能接口读本进程的窗口；进程没有辅助功能权限时跳过。
@MainActor
struct CloneRepositoryDialogTests {
    /// 展开 Options 后，LFS 与子模块两个勾选框的左缘与 Remote URL 输入框的左缘相同。
    @Test("选项区的勾选框对齐输入列", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func options() throws {
        let elements = AccessibilityProbe.elements(
            pressing: AppLocalization.text("clone.options"),
            until: { elements in elements.count { $0.role == "AXCheckBox" } == 2 }
        ) {
            CloneRepositoryDialog(hosts: [], close: { }, submit: { _ in })
        }

        let field = try #require(elements.first { $0.role == "AXTextField" })
        let checkBoxes = elements.filter { $0.role == "AXCheckBox" }

        try #require(checkBoxes.count == 2)

        for checkBox in checkBoxes {
            #expect(abs(checkBox.frame.minX - field.frame.minX) <= 1)
        }
    }
}
