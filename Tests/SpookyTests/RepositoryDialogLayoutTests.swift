import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryDialogLayoutTests

/// 仓库操作对话框的骨架：输入列至少从对齐线开始，头部与错误文字对齐输入列；服务器仓库写出位置，仓库不可写时说明原因。
///
/// 位置经辅助功能接口读取，进程没有辅助功能权限时跳过。
@MainActor
struct RepositoryDialogLayoutTests {
    /// 标签长时输入列右移，标签短时输入列从 120 的对齐线开始，只有勾选框时勾选框从对齐线开始，标题、说明与错误文字都对齐它们；
    /// 本机仓库没有位置一行，仓库可写、内容合法时错误区收起，主按钮可用；
    /// 服务器仓库在标题下写出带主机前缀的位置，没连上时仓库不可写，错误区说明原因，主按钮不可用。
    @Test("头部对齐、位置一行与不可写的说明", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func layout() async throws {
        let local = Self.session(.local(path: "/tmp/spooky-dialog"))

        // 长标签
        let long = await AccessibilityProbe.elements(until: Self.hasField) {
            Self.layout(session: local, error: "Error") {
                Self.field("Personal Access Token:")
            }
        }

        let longField = try #require(long.first { $0.role == "AXTextField" })

        #expect(longField.frame.minX > DialogMetrics.alignment + 1)
        try Self.expectTexts(["Title", "Message", "Error"], in: long, startingAt: longField.frame.minX)

        // 只有勾选框
        let options = await AccessibilityProbe.elements(until: Self.hasCheckBox) {
            Self.layout(session: local, error: "Error") {
                DialogFormOption(title: "Force", isOn: .constant(false))
            }
        }

        let option = try #require(options.first { $0.role == "AXCheckBox" })

        #expect(abs(option.frame.minX - DialogMetrics.alignment) <= 1)
        try Self.expectTexts(["Title", "Message", "Error"], in: options, startingAt: option.frame.minX)

        // 本机仓库，短标签，没有错误
        let short = await AccessibilityProbe.elements(until: Self.hasField) {
            Self.layout(session: local, error: "") {
                Self.field("Name:")
            }
        }

        let shortField = try #require(short.first { $0.role == "AXTextField" })

        #expect(abs(shortField.frame.minX - DialogMetrics.alignment) <= 1)
        try Self.expectTexts(["Title", "Message"], in: short, startingAt: shortField.frame.minX)
        #expect(!short.contains { $0.value.contains("/tmp/spooky-dialog") })
        #expect(!short.contains { $0.value == AppLocalization.text("dialog.blocked") })
        #expect(try Self.submit(in: short).isEnabled)

        // 服务器仓库
        let remote = await AccessibilityProbe.elements(until: Self.hasField) {
            Self.layout(session: Self.session(.remote(host: "spooky-test", path: "/srv/repo")), error: "") {
                Self.field("Name:")
            }
        }

        #expect(remote.contains { $0.role == "AXStaticText" && $0.value == "spooky-test:/srv/repo" })
        #expect(remote.contains { $0.role == "AXStaticText" && $0.value == AppLocalization.text("dialog.blocked") })
        #expect(try !Self.submit(in: remote).isEnabled)
    }

    /// Options 开关上方的间距由骨架统一决定：内容区最后一个控件与开关一行相隔 8，没有内容区时头部的说明与它也相隔 8；
    /// 没有选项区时最后一个控件到底栏是表单的 12；表单末尾没有内容的状态行（这里是没有版本可查的合并可行性预览）
    /// 不占高度，也不多出一份行距。
    @Test("内容区与 Options 开关的间距", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func optionsSpacing() async throws {
        let session = Self.session(.local(path: "/tmp/spooky-dialog"))
        let hasHelp: ([AccessibilityProbe.Element]) -> Bool = { elements in
            Self.hasCheckBox(elements) && elements.contains { $0.value == "Help" }
        }

        // 有选项区：说明文字的底边与开关一行相隔 8，开关一行高 34
        let options = await AccessibilityProbe.elements(until: hasHelp) {
            RepositoryDialogLayout(
                session: session,
                title: "Title",
                message: "Message",
                submitTitle: "Submit",
                error: "",
                isValid: true,
                cancel: { },
                submit: { }
            ) {
                Self.lastRows(session: session)
            } options: {
                DialogFormOption(title: "Skip Hooks", isOn: .constant(false))
            }
        }

        let help = try #require(options.first { $0.role == "AXStaticText" && $0.value == "Help" })
        let toggle = try #require(
            options.first { $0.role == "AXCheckBox" && $0.name == AppLocalization.text("dialog.options") }
        )

        #expect(abs(toggle.frame.midY - help.frame.maxY - (8 + 34 / 2)) <= 1)

        // 没有选项区：说明文字的底边到底栏按钮是表单的 12 加按钮距底栏顶的 12
        let plain = await AccessibilityProbe.elements(until: hasHelp) {
            Self.layout(session: session, error: "") {
                Self.lastRows(session: session)
            }
        }

        let plainHelp = try #require(plain.first { $0.role == "AXStaticText" && $0.value == "Help" })
        let cancel = try #require(
            plain.first { $0.role == "AXButton" && $0.name == AppLocalization.text("action.cancel") }
        )

        #expect(abs(cancel.frame.minY - plainHelp.frame.maxY - (12 + 12)) <= 1)

        // 没有内容区：头部的说明折成几行、比图标高时，说明的底边与开关一行同样相隔 8
        let message = String(repeating: "Saves a patch file with all changes of the revision. ", count: 4)
        let headerOnly = await AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.value == message } && Self.hasButtons(elements) }
        ) {
            DialogLayout(
                title: "Title",
                message: message,
                submitTitle: "Submit",
                cancel: { },
                submit: { },
                options: { DialogFormOption(title: "Omit Prefixes", isOn: .constant(false)) }
            )
        }

        let text = try #require(headerOnly.first { $0.role == "AXStaticText" && $0.value == message })
        let headerToggle = try #require(
            headerOnly.first { $0.role == "AXCheckBox" && $0.name == AppLocalization.text("dialog.options") }
        )

        #expect(text.frame.maxY > 20 + 64)
        #expect(abs(headerToggle.frame.midY - text.frame.maxY - (8 + 34 / 2)) <= 1)
    }
}

// MARK: - Helpers

extension RepositoryDialogLayoutTests {
    /// 显示给定仓库的会话；只设置仓库，不读取它。
    private static func session(_ location: RepositoryLocation) -> RepositorySession {
        let session = RepositorySession(loadStatus: { _ in throw CancellationError() })
        session.display(location)

        return session
    }

    /// 给定会话与错误说明的对话框。
    private static func layout(
        session: RepositorySession,
        error: String,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        RepositoryDialogLayout(
            session: session,
            title: "Title",
            message: "Message",
            submitTitle: "Submit",
            error: error,
            isValid: true,
            cancel: { },
            submit: { },
            content: content
        )
    }

    /// 表单最后是带说明的勾选框，再接一行没有版本可查、不显示内容的合并可行性预览。
    @ViewBuilder
    private static func lastRows(session: RepositorySession) -> some View {
        DialogFormOption(title: "Squash", help: "Help", isOn: .constant(false))

        MergeabilityPreview(session: session, revision: "", showsCleanResults: false)
    }

    /// 带这个标签的一行输入框。
    private static func field(_ label: String) -> some View {
        RepositoryDialogRows.row(label) {
            TextField("", text: .constant(""))
        }
    }

    /// 主按钮 Submit。
    private static func submit(in elements: [AccessibilityProbe.Element]) throws -> AccessibilityProbe.Element {
        try #require(elements.first { $0.role == "AXButton" && $0.name == "Submit" })
    }

    /// 这几段文字的左缘都在这个位置。
    private static func expectTexts(
        _ texts: [String],
        in elements: [AccessibilityProbe.Element],
        startingAt x: CGFloat
    ) throws {
        for text in texts {
            let element = try #require(elements.first { $0.role == "AXStaticText" && $0.value == text })

            #expect(abs(element.frame.minX - x) <= 1, "\(text)")
        }
    }

    /// 输入框与标题都读到了。
    private static func hasField(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.contains { $0.role == "AXTextField" } && elements.contains { $0.value == "Title" }
    }

    /// 底栏的两个按钮都读到了。
    private static func hasButtons(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.filter { $0.role == "AXButton" }.count >= 2
    }

    /// 勾选框与标题都读到了。
    private static func hasCheckBox(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.contains { $0.role == "AXCheckBox" } && elements.contains { $0.value == "Title" }
    }
}
