import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - AddRemoteRepositoryViewTests

/// 添加服务器仓库的表单是 480 宽的对话框骨架：标题不带省略号；体检失败时错误区写出修复方向与原始输出，
/// 路径不存在或不是工作区时可以在那里新建仓库；环境变量提醒是只有 Close 的提示版。
@MainActor
struct AddRemoteRepositoryViewTests {
    /// 表单与环境变量提醒都宽 480。
    @Test("宽度")
    func widths() {
        let form = AddRemoteRepositoryView(opened: { _ in }, cancelled: { })
        let notice = ServerEnvironmentNotice(host: "spooky-test", variables: ["GIT_DIR"], close: { })

        #expect(DialogLayoutTests.hosting(form).frame.width == 480)
        #expect(DialogLayoutTests.hosting(notice).frame.width == 480)
    }

    /// 标题是 Add Server Repository，不带菜单项的省略号；主按钮是 Open。
    @Test("标题与主按钮", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func title() throws {
        let open = AppLocalization.text("action.open")

        let elements = AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXButton" && $0.name == open } }
        ) {
            AddRemoteRepositoryView(opened: { _ in }, cancelled: { })
        }

        let title = AppLocalization.text("remote.form.title")

        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == title })
        #expect(!title.hasSuffix("…"))
    }

    /// 错误区先写修复方向，空一行后是 ssh 的原始输出；没有失败时错误区收起。
    @Test("体检失败的错误区")
    func notice() throws {
        let result = GitCommandResult(
            arguments: ["ssh", "spooky-test"],
            standardOutput: Data(),
            standardError: Data("ls: /srv/missing: No such file or directory".utf8),
            terminationStatus: .exited(2),
            isCancelled: false
        )

        let failure = AppFailure(
            error: RemoteConnectionError(.pathUnavailable, result: result),
            opening: true,
            location: .remote(host: "spooky-test", path: "/srv/missing")
        )

        let notice = try #require(AddRemoteRepositoryView.notice(for: failure))

        #expect(notice.hasPrefix(failure.message + "\n\n"))
        #expect(notice.contains("No such file or directory"))
        #expect(AddRemoteRepositoryView.notice(for: nil) == nil)
    }

    /// 只有路径不存在或还不是工作区时才能在那里新建仓库。
    @Test("新建仓库的条件")
    func createRepository() {
        #expect(AddRemoteRepositoryView.canCreateRepository(after: .pathUnavailable))
        #expect(AddRemoteRepositoryView.canCreateRepository(after: .notWorkingTree))
        #expect(!AddRemoteRepositoryView.canCreateRepository(after: .authentication))
        #expect(!AddRemoteRepositoryView.canCreateRepository(after: .pathPermission))
        #expect(!AddRemoteRepositoryView.canCreateRepository(after: nil))
    }

    /// 环境变量提醒的底栏只有 Close，说明写出主机与变量名。
    @Test("环境变量提醒是提示版", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func environmentNotice() throws {
        let close = AppLocalization.text("action.close")

        let elements = AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXButton" && $0.name == close } }
        ) {
            ServerEnvironmentNotice(host: "spooky-test", variables: ["GIT_DIR"], close: { })
        }

        let buttons = elements.filter { $0.role == "AXButton" }
        let message = AppLocalization.text("remote.environment.message", "spooky-test", "GIT_DIR")

        #expect(buttons.map(\.name) == [close])
        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == message })
    }
}
