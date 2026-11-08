import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - DialogFormRowAccessibilityTests

/// 表单行在辅助功能里的名称：标签是控件的标题，只读的文字同时读得出标签与文字本身，一组控件各自保留自己的名称。
///
/// 经辅助功能接口读本进程的窗口；进程没有辅助功能权限时跳过。
@MainActor
struct DialogFormRowAccessibilityTests {
    /// 对话框骨架的表单行与引用对话框的表格行：只读文字、输入框与一组控件都读出标签与值。
    @Test("DialogFormRow 与 RepositoryDialogRows.row 读出标签与值", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func rows() async throws {
        let form = await AccessibilityProbe.elements(until: Self.hasControls) {
            DialogForm {
                DialogFormRow(label: "Merge Strategy:") {
                    Text(verbatim: "Merge Commit")
                }

                DialogFormRow(label: "Project:") {
                    TextField("", text: .constant("group/project"))
                }

                DialogFormRow(label: "Code:") {
                    VStack {
                        Text(verbatim: "ABCD-1234")
                        Button("Open Page") { }
                    }
                }
            }
        }

        try Self.expectPairs(in: form)

        // 引用对话框的表格行
        let grid = await AccessibilityProbe.elements(until: Self.hasControls) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 8) {
                RepositoryDialogRows.row("Merge Strategy:") {
                    Text(verbatim: "Merge Commit")
                }

                RepositoryDialogRows.row("Project:") {
                    TextField("", text: .constant("group/project"))
                }

                RepositoryDialogRows.row("Code:") {
                    VStack {
                        Text(verbatim: "ABCD-1234")
                        Button("Open Page") { }
                    }
                }
            }
        }

        try Self.expectPairs(in: grid)
    }
}

// MARK: - Helpers

extension DialogFormRowAccessibilityTests {
    /// 输入框与按钮都读到了。
    private static func hasControls(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.contains { $0.role == "AXTextField" } && elements.contains { $0.role == "AXButton" }
    }

    /// 三行都配对：只读文字保留自己的文字、以标签为标题；输入框以标签为标题；一组控件里的文字与按钮各自保留名称。
    private static func expectPairs(in elements: [AccessibilityProbe.Element]) throws {
        let strategy = try #require(elements.first { $0.role == "AXStaticText" && $0.value == "Merge Commit" })

        #expect(strategy.title == "Merge Strategy:")

        let project = try #require(elements.first { $0.role == "AXTextField" })

        #expect(project.value == "group/project")
        #expect(project.title == "Project:")

        let code = try #require(elements.first { $0.role == "AXStaticText" && $0.value == "ABCD-1234" })

        #expect(code.title == "Code:")

        let button = try #require(elements.first { $0.role == "AXButton" })

        #expect(button.name == "Open Page")
    }
}
