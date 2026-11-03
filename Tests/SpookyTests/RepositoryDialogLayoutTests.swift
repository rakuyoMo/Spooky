import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryDialogLayoutTests

/// 仓库操作对话框的骨架：输入列至少从对齐线开始，头部与错误文字对齐输入列；服务器仓库写出位置，仓库不可写时说明原因。
///
/// 位置经辅助功能接口读取，进程没有辅助功能权限时整组跳过。
@MainActor
@Suite(.enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
struct RepositoryDialogLayoutTests {
    /// 标签长时输入列右移，标签短时输入列从 120 的对齐线开始；两种情况下标题、说明与错误文字都对齐输入列。
    @Test("头部与错误文字对齐输入列")
    func rows() throws {
        for label in ["Personal Access Token:", "Name:"] {
            let elements = AccessibilityProbe.elements(until: Self.hasField) {
                Self.layout(session: Self.session(.local(path: "/tmp/spooky-dialog"))) {
                    RepositoryDialogRows.row(label) {
                        TextField("", text: .constant(""))
                    }
                }
            }

            let field = try #require(elements.first { $0.role == "AXTextField" })

            #expect(field.frame.minX >= DialogMetrics.alignment - 1, "\(label)")
            try Self.expectTexts(["Title", "Message", "Error"], in: elements, startingAt: field.frame.minX)
        }
    }

    /// 只有勾选框时，勾选框从 120 的对齐线开始，头部文字对齐它。
    @Test("只有勾选框时对齐勾选框")
    func options() throws {
        let elements = AccessibilityProbe.elements(until: Self.hasCheckBox) {
            Self.layout(session: Self.session(.local(path: "/tmp/spooky-dialog"))) {
                DialogFormOption(title: "Force", isOn: .constant(false))
            }
        }

        let option = try #require(elements.first { $0.role == "AXCheckBox" })

        #expect(abs(option.frame.minX - DialogMetrics.alignment) <= 1)
        try Self.expectTexts(["Title", "Message", "Error"], in: elements, startingAt: option.frame.minX)
    }

    /// 服务器仓库在标题下写出带主机前缀的位置；没连上时仓库不可写，错误区说明原因，主按钮不可用。
    @Test("服务器仓库的位置与不可写的说明")
    func remote() throws {
        let elements = AccessibilityProbe.elements(until: Self.hasField) {
            Self.layout(session: Self.session(.remote(host: "spooky-test", path: "/srv/repo")), error: "") {
                RepositoryDialogRows.row("Name:") {
                    TextField("", text: .constant(""))
                }
            }
        }

        let blocked = AppLocalization.text("dialog.blocked")
        let submit = try #require(elements.first { $0.role == "AXButton" && $0.name == "Submit" })

        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == "spooky-test:/srv/repo" })
        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == blocked })
        #expect(!submit.isEnabled)
    }

    /// 本机仓库没有位置一行；仓库可写、内容合法时错误区收起，主按钮可用。
    @Test("本机仓库没有位置一行")
    func local() throws {
        let elements = AccessibilityProbe.elements(until: Self.hasField) {
            Self.layout(session: Self.session(.local(path: "/tmp/spooky-dialog")), error: "") {
                RepositoryDialogRows.row("Name:") {
                    TextField("", text: .constant(""))
                }
            }
        }

        let submit = try #require(elements.first { $0.role == "AXButton" && $0.name == "Submit" })

        #expect(!elements.contains { $0.value.contains("/tmp/spooky-dialog") })
        #expect(!elements.contains { $0.value == AppLocalization.text("dialog.blocked") })
        #expect(submit.isEnabled)
    }

    /// 删除一个远端分支时标题是 Delete Remote Branch、主按钮是 Delete Branch，两个时是 Delete Remote Branches 与 Delete Branches。
    @Test("删除远端分支的标题与主按钮", arguments: [1, 2])
    func deleteRemoteBranches(count: Int) throws {
        let session = Self.session(.local(path: "/tmp/spooky-dialog"))
        let branches = (1 ... count).map { Self.remoteBranch("origin/feature-\($0)") }
        let title = AppLocalization.text(count == 1 ? "branch.deleteRemote" : "branch.deleteRemoteMultiple")
        let submit = AppLocalization.text(count == 1 ? "branch.delete" : "branch.deleteMultiple")

        let elements = AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXButton" && $0.name == submit } }
        ) {
            DeleteReferencesDialog(session: session, target: .remoteBranches(branches), close: { })
        }

        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == title })
        #expect(elements.contains { $0.role == "AXButton" && $0.name == submit })
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

    /// 一个远端分支。
    private static func remoteBranch(_ name: String) -> RepositoryReference {
        RepositoryReference(
            id: "refs/remotes/" + name,
            objectID: String(repeating: "a", count: 40),
            objectType: "commit",
            upstream: nil,
            upstreamRemote: nil,
            upstreamBranch: nil,
            symbolicTarget: nil
        )
    }

    /// 给定会话与错误说明的对话框。
    private static func layout(
        session: RepositorySession,
        error: String = "Error",
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

    /// 勾选框与标题都读到了。
    private static func hasCheckBox(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.contains { $0.role == "AXCheckBox" } && elements.contains { $0.value == "Title" }
    }
}
