import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - IdentityProfileMenuTests

/// 头像的身份档案菜单：提交区、仓库设置与仓库管理详情列出同样的项，当前身份总能找到，也总能存为档案；
/// 每项写出签名密钥，用户靠它分辨同名的身份。
@MainActor
struct IdentityProfileMenuTests {
    /// 同名的工作档案。
    private let work = UserProfile(title: "Work", name: "Ada Lovelace", email: "ada@work.example")

    /// 同名的个人档案，只有邮箱与工作档案不同。
    private let home = UserProfile(title: "Home", name: "Ada Lovelace", email: "ada@home.example")

    /// 当前身份对应某个档案时只勾选它，不单列身份，也不提供存为档案；没有对应档案时单列当前身份，分隔线后可以把它存为档案；
    /// 没有身份也没有档案时只有管理档案，前面不留分隔线；签名密钥也要相同才是当前档案。
    @Test("菜单列出的档案与当前身份")
    func menuItems() {
        let matching = IdentityProfileMenu.items(
            profiles: [work, home],
            name: "Ada Lovelace",
            email: "ada@home.example",
            signingKey: nil
        )

        #expect(matching == [.profile(work, isCurrent: false), .profile(home, isCurrent: true), .separator, .manage])

        // 当前身份没有对应的档案
        let empty = IdentityProfileMenu.items(
            profiles: [],
            name: "Ada Lovelace",
            email: "ada@example.com",
            signingKey: nil
        )

        let other = IdentityProfileMenu.items(
            profiles: [work],
            name: "Ada Lovelace",
            email: "ada@example.com",
            signingKey: nil
        )

        #expect(empty == [.identity, .separator, .addCurrent, .manage])
        #expect(other == [.profile(work, isCurrent: false), .identity, .separator, .addCurrent, .manage])

        // 没有身份也没有档案
        #expect(IdentityProfileMenu.items(profiles: [], name: "", email: "", signingKey: nil) == [.manage])

        // 签名密钥只差大小写仍然匹配，换了密钥或去掉密钥就单列当前身份
        var signed = work

        signed.signingKey = "0123456789ABCDEFBB199F7C"

        let items = { (key: String?) in
            IdentityProfileMenu.items(
                profiles: [signed],
                name: signed.name,
                email: signed.email,
                signingKey: key
            )
        }

        #expect(items("0123456789abcdefbb199f7c") == [.profile(signed, isCurrent: true), .separator, .manage])

        for key in ["FEDCBA9876543210BB199F7C", nil] {
            #expect(items(key) == [.profile(signed, isCurrent: false), .identity, .separator, .addCurrent, .manage])
        }
    }

    /// 括号里写本机密钥的格式与指纹末 8 位；没有密钥与本机认不出的密钥各有固定的写法，不写档案标题。
    @Test("菜单项写出签名密钥")
    func signingKeyTitle() {
        let fingerprint = "0123456789ABCDEF0123456789ABCDEFBB199F7C"

        let gpg = SigningKey(
            format: .openpgp,
            value: fingerprint,
            fingerprint: fingerprint,
            signer: nil,
            comment: nil
        )

        // 字面 SSH 公钥：长度前缀的类型名与 32 字节的 Ed25519 公钥
        let blob = [0, 0, 0, 11] + Array("ssh-ed25519".utf8) + [0, 0, 0, 32] + Array(repeating: 1, count: 32)
        let literal = "ssh-ed25519 " + Data(blob).base64EncodedString()

        let ssh = SigningKey(
            format: .ssh,
            value: "key::" + literal,
            fingerprint: "SHA256:aGVsbG8gd29ybGQgdGhpcyBpcyBhIGtleQ1a2b3c4d",
            signer: nil,
            comment: "ada@laptop"
        )

        let title = { (key: String?) in
            IdentityProfileMenu.title(
                name: "Ada Lovelace",
                email: "ada@work.example",
                signingKey: key,
                keys: [gpg, ssh]
            )
        }

        #expect(title("BB199F7C") == "Ada Lovelace <ada@work.example> (GPG: BB199F7C)")
        #expect(title("key::" + literal + " other@host") == "Ada Lovelace <ada@work.example> (SSH: 1a2b3c4d)")

        let none = AppLocalization.text("signing.none")
        let unknown = AppLocalization.text("signing.unknown")

        #expect(title(nil) == "Ada Lovelace <ada@work.example> (\(none))")
        #expect(title("~/.ssh/id_ed25519.pub") == "Ada Lovelace <ada@work.example> (\(unknown))")
    }
}
