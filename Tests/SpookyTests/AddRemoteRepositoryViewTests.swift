import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - AddRemoteRepositoryViewTests

/// 添加服务器仓库的表单：体检失败时错误区写出修复方向与原始输出，路径不存在或不是工作区时可以在那里新建仓库；
/// 环境变量提醒是只有 Close 的提示版。
@MainActor
struct AddRemoteRepositoryViewTests {
    /// 错误区先写修复方向，空一行后是 ssh 的原始输出，没有失败时错误区收起；
    /// 只有路径不存在或还不是工作区时才能在那里新建仓库。
    @Test("体检失败的错误区与新建仓库的条件")
    func failure() throws {
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

        // 新建仓库的条件
        #expect(AddRemoteRepositoryView.canCreateRepository(after: .pathUnavailable))
        #expect(AddRemoteRepositoryView.canCreateRepository(after: .notWorkingTree))
        #expect(!AddRemoteRepositoryView.canCreateRepository(after: .authentication))
        #expect(!AddRemoteRepositoryView.canCreateRepository(after: nil))
    }

    /// 环境变量提醒的底栏只有 Close，说明写出主机与变量名。
    @Test("环境变量提醒是提示版", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func environmentNotice() async throws {
        let close = AppLocalization.text("action.close")

        let elements = await AccessibilityProbe.elements(
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
