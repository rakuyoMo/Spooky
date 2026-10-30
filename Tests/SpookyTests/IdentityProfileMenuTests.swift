import Foundation
import Testing

@testable import Spooky

// MARK: - IdentityProfileMenuTests

/// 头像的身份档案菜单：提交区、仓库设置与仓库管理详情列出同样的项，当前身份总能找到，也总能存为档案。
@MainActor
struct IdentityProfileMenuTests {
    /// 同名的工作档案。
    private let work = UserProfile(title: "Work", name: "Ada Lovelace", email: "ada@work.example")

    /// 同名的个人档案，只有邮箱与工作档案不同。
    private let home = UserProfile(title: "Home", name: "Ada Lovelace", email: "ada@home.example")

    /// 当前身份对应某个档案时只勾选它，不再单列身份，也不提供存为档案。
    @Test("当前身份有对应的档案")
    func matchingProfile() {
        let items = IdentityProfileMenu.items(profiles: [work, home], name: "Ada Lovelace", email: "ada@home.example")

        #expect(items == [.profile(work, isCurrent: false), .profile(home, isCurrent: true), .separator, .manage])
    }

    /// 没有对应档案时单列当前身份，分隔线后可以把它存为档案；签名状态不在菜单里。
    @Test("当前身份没有对应的档案")
    func identityWithoutProfile() {
        let empty = IdentityProfileMenu.items(profiles: [], name: "Ada Lovelace", email: "ada@example.com")
        let other = IdentityProfileMenu.items(profiles: [work], name: "Ada Lovelace", email: "ada@example.com")

        #expect(empty == [.identity, .separator, .addCurrent, .manage])
        #expect(other == [.profile(work, isCurrent: false), .identity, .separator, .addCurrent, .manage])
    }

    /// 没有身份也没有档案时只有管理档案，前面不留分隔线。
    @Test("没有身份也没有档案")
    func nothingToList() {
        #expect(IdentityProfileMenu.items(profiles: [], name: "", email: "") == [.manage])
    }
}
