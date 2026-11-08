import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - AccountDialogTests

/// 账号对话框：认证方式的下拉占满输入列，错误区只写地址不合法与重复添加两种原因。
///
/// 下拉的位置经辅助功能接口读取，进程没有辅助功能权限时跳过这一项。
@MainActor
struct AccountDialogTests {
    /// 认证方式的下拉占满输入列：左缘与输入列对齐，右缘距对话框右边 20；只有下拉一行时输入列从对齐线开始。
    @Test("认证方式的下拉占满输入列", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func authenticationPopUp() async throws {
        let github = try await Self.elements(of: .add(.github), until: ["AXPopUpButton"])
        let githubPopUp = try #require(github.first { $0.role == "AXPopUpButton" })

        #expect(abs(githubPopUp.frame.minX - DialogMetrics.alignment) <= 1)
        #expect(abs(githubPopUp.frame.maxX - 460) <= 1)

        // 私有部署的令牌标签比标签列的最小宽度长，输入列随之右移，下拉与地址框仍在同一列
        let gitlab = try await Self.elements(
            of: .add(.gitlabSelfManaged),
            until: ["AXPopUpButton", "AXTextField"]
        )

        let gitlabPopUp = try #require(gitlab.first { $0.role == "AXPopUpButton" })
        let hostLabel = AppLocalization.text("accounts.host")
        let host = try #require(gitlab.first { $0.role == "AXTextField" && $0.title == hostLabel })

        #expect(abs(gitlabPopUp.frame.minX - host.frame.minX) <= 1)
        #expect(abs(gitlabPopUp.frame.maxX - 460) <= 1)
    }

    /// 错误区的两种原因。
    ///
    /// 私有部署的地址为空时只禁用主按钮，不写原因；不为空而认不出时写 Host is not valid；合法的地址没有错误。
    /// 添加时同一实例上的同名账号算重复；别的实例或别的用户名不算；重新认证换的就是已有账号的令牌，不算。
    @Test("地址不合法与重复添加的判断")
    func errors() throws {
        let invalid = AppLocalization.text("accounts.host.invalid")

        #expect(AccountDialog.hostError("  ") == nil)
        #expect(AccountDialog.hostError("git.example.com") == invalid)
        #expect(AccountDialog.hostError("ssh://git.example.com") == invalid)
        #expect(AccountDialog.hostError("https://git.example.com:8443/gitlab/") == nil)

        // 重复添加
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com"))
        let other = try #require(HostingInstance.gitlab(address: "https://other.example.com"))
        let account = HostingAccount(instance: instance, username: "me", authentication: .personalAccessToken)
        let add = AccountDialog.Purpose.add(.gitlabSelfManaged)

        #expect(AccountDialog.isExisting("me", on: instance, for: add, among: [account]))
        #expect(!AccountDialog.isExisting("me", on: other, for: add, among: [account]))
        #expect(!AccountDialog.isExisting("you", on: instance, for: add, among: [account]))
        #expect(!AccountDialog.isExisting("me", on: instance, for: .reauthenticate(account), among: [account]))
    }
}

// MARK: - Helpers

extension AccountDialogTests {
    /// 对话框在辅助功能里的元素，读到这几种角色为止；账号列表为空，偏好是没有内容的临时域，令牌存在内存里。
    private static func elements(
        of purpose: AccountDialog.Purpose,
        until roles: Set<String>
    ) async throws -> [AccessibilityProbe.Element] {
        let defaults = try #require(UserDefaults(suiteName: "spooky-account-dialog-" + UUID().uuidString))
        let accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials())
        let dialog = AccountDialog(purpose: purpose, accounts: accounts, close: { })

        return await AccessibilityProbe.elements(
            until: { elements in roles.isSubset(of: elements.map(\.role)) }
        ) {
            dialog
        }
    }
}
