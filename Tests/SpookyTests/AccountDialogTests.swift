import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - AccountDialogTests

/// 账号对话框：错误区只写地址不合法与重复添加两种原因。
@MainActor
struct AccountDialogTests {
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
