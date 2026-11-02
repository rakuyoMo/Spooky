import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - AccountDialogTests

/// 账号对话框：标题写出服务，认证方式的下拉占满输入列，错误区只写地址不合法与重复添加两种原因。
///
/// 下拉的位置经辅助功能接口读取，进程没有辅助功能权限时跳过这一项。
@MainActor
struct AccountDialogTests {
    /// 私有部署 GitLab 的添加写出 GitLab Self-Managed；两种 GitLab 的重新认证同一个标题。
    @Test("对话框的标题")
    func titles() throws {
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com"))
        let account = HostingAccount(instance: instance, username: "me", authentication: .personalAccessToken)

        let purposes: [AccountDialog.Purpose] = [
            .add(.gitlabSelfManaged),
            .add(.gitlab),
            .add(.github),
            .reauthenticate(account),
        ]

        let titles = try purposes.map { try Self.dialog($0).title }

        #expect(titles == [
            AppLocalization.text("accounts.add.gitlabSelfManaged.title"),
            AppLocalization.text("accounts.add.gitlab.title"),
            AppLocalization.text("accounts.add.github.title"),
            AppLocalization.text("accounts.update.gitlab.title"),
        ])
    }

    /// 认证方式的下拉占满输入列：左缘与输入列对齐，右缘距对话框右边 20；只有下拉一行时输入列从对齐线开始。
    @Test("认证方式的下拉占满输入列", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func authenticationPopUp() throws {
        let github = try Self.elements(of: .add(.github), until: ["AXPopUpButton"])
        let githubPopUp = try #require(github.first { $0.role == "AXPopUpButton" })

        #expect(abs(githubPopUp.frame.minX - DialogMetrics.alignment) <= 1)
        #expect(abs(githubPopUp.frame.maxX - 460) <= 1)

        // 私有部署的令牌标签比标签列的最小宽度长，输入列随之右移，下拉与地址框仍在同一列
        let gitlab = try Self.elements(of: .add(.gitlabSelfManaged), until: ["AXPopUpButton", "AXTextField"])
        let gitlabPopUp = try #require(gitlab.first { $0.role == "AXPopUpButton" })
        let hostLabel = AppLocalization.text("accounts.host")
        let host = try #require(gitlab.first { $0.role == "AXTextField" && $0.title == hostLabel })

        #expect(abs(gitlabPopUp.frame.minX - host.frame.minX) <= 1)
        #expect(abs(gitlabPopUp.frame.maxX - 460) <= 1)
    }

    /// 地址为空时只禁用主按钮，不写原因；不为空而认不出时写 Host is not valid；合法的地址没有错误。
    @Test("私有部署地址的错误区")
    func hostError() {
        let invalid = AppLocalization.text("accounts.host.invalid")

        #expect(AccountDialog.hostError("") == nil)
        #expect(AccountDialog.hostError("  ") == nil)
        #expect(AccountDialog.hostError("not a url") == invalid)
        #expect(AccountDialog.hostError("git.example.com") == invalid)
        #expect(AccountDialog.hostError("ssh://git.example.com") == invalid)
        #expect(AccountDialog.hostError("https://git.example.com:8443/gitlab/") == nil)
    }

    /// 添加时同一实例上的同名账号算重复；别的实例或别的用户名不算；重新认证换的就是已有账号的令牌，不算。
    @Test("重复添加的判断")
    func existing() throws {
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com"))
        let other = try #require(HostingInstance.gitlab(address: "https://other.example.com"))
        let account = HostingAccount(instance: instance, username: "me", authentication: .personalAccessToken)
        let add = AccountDialog.Purpose.add(.gitlabSelfManaged)

        #expect(AccountDialog.isExisting("me", on: instance, for: add, among: [account]))
        #expect(!AccountDialog.isExisting("me", on: other, for: add, among: [account]))
        #expect(!AccountDialog.isExisting("you", on: instance, for: add, among: [account]))
        #expect(!AccountDialog.isExisting("me", on: instance, for: add, among: []))
        #expect(!AccountDialog.isExisting("me", on: instance, for: .reauthenticate(account), among: [account]))
    }
}

// MARK: - Helpers

extension AccountDialogTests {
    /// 账号列表为空的对话框：偏好是没有内容的临时域，令牌存在内存里。
    private static func dialog(_ purpose: AccountDialog.Purpose) throws -> AccountDialog {
        let defaults = try #require(UserDefaults(suiteName: "spooky-account-dialog-" + UUID().uuidString))
        let accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials())

        return AccountDialog(purpose: purpose, accounts: accounts, close: { })
    }

    /// 对话框在辅助功能里的元素，读到这几种角色为止。
    private static func elements(
        of purpose: AccountDialog.Purpose,
        until roles: Set<String>
    ) throws -> [AccessibilityProbe.Element] {
        let dialog = try dialog(purpose)

        return AccessibilityProbe.elements(until: { elements in roles.isSubset(of: elements.map(\.role)) }) {
            dialog
        }
    }
}
