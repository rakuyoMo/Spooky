import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - UserProfilesTests

/// 签名密钥菜单里一把密钥的写法：身份档案、Git Config 页与仓库设置看到的文字相同，用户靠它分辨密钥；
/// 菜单里哪一项可选、提示什么；以及保存档案前的重复检查，重复的档案会让身份菜单分不清该勾哪一个。
struct UserProfilesTests {
    /// GPG 写签名人与指纹末 8 位，没有签名人时括号前只有格式名；
    /// SSH 写注释与指纹末 8 位，注释是现有文件时把主目录缩写成 `~`，没有注释或注释只有空白时只写指纹末 8 位；
    /// 本机找不到的已配置密钥显示配置的值，超过 60 个字符时截掉中间。
    @Test("签名密钥的菜单项")
    func keyTitles() throws {
        // GPG 写签名人与指纹末 8 位。
        let gpgFingerprint = "0123456789ABCDEF0123456789ABCDEFBB199F7C"
        let gpg = { (signer: String?) in
            SigningKey(
                format: .openpgp,
                value: gpgFingerprint,
                fingerprint: gpgFingerprint,
                signer: signer,
                comment: nil
            )
        }

        #expect(
            UserProfiles.title(of: gpg("Valid Signer <valid@example.com>"))
                == "GPG: Valid Signer <valid@example.com> (BB199F7C)"
        )
        #expect(UserProfiles.title(of: gpg(nil)) == "GPG: (BB199F7C)")

        // SSH 的注释指向临时主目录里的密钥文件。
        let home = FileManager.default.temporaryDirectory.appending(path: "spooky-home-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }

        let file = home.appending(path: ".ssh/id_ed25519")

        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: file)

        let ssh = { (comment: String?) in
            SigningKey(
                format: .ssh,
                value: "key::ssh-ed25519 AAAA",
                fingerprint: "SHA256:aGVsbG8gd29ybGQgdGhpcyBpcyBhIGtleQ1a2b3c4d",
                signer: nil,
                comment: comment
            )
        }

        let missing = home.appending(path: "missing").path
        #expect(UserProfiles.title(of: ssh(file.path), home: home.path) == "SSH: ~/.ssh/id_ed25519 (1a2b3c4d)")
        #expect(UserProfiles.title(of: ssh(missing), home: home.path) == "SSH: \(missing) (1a2b3c4d)")
        #expect(UserProfiles.title(of: ssh("wgy@laptop"), home: home.path) == "SSH: wgy@laptop (1a2b3c4d)")

        for comment in [" ", nil] {
            #expect(UserProfiles.title(of: ssh(comment), home: home.path) == "SSH: (1a2b3c4d)")
        }

        // 找不到的已配置密钥：60 个字符以内原样显示，更长的只留前 28 个与后 31 个字符
        let literal = "key::ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIo4+UbY6DMZSypkin/0RL8In2rBSK0vVDyQLPbO7VuK"
        let sixty = String(repeating: "a", count: 60)
        let trimmed = String(repeating: "a", count: 28) + "..." + String(repeating: "a", count: 30) + "b"

        #expect(UserProfiles.unknownKeyTitle(sixty) == sixty)
        #expect(UserProfiles.unknownKeyTitle(sixty + "b") == trimmed)
        #expect(UserProfiles.unknownKeyTitle(literal) == "key::ssh-ed25519 AAAAC3NzaC1...ypkin/0RL8In2rBSK0vVDyQLPbO7VuK")
    }

    /// 菜单依次是本机的密钥、找不到的已配置密钥与 No Signing Key；找不到的已配置密钥只显示当前的配置，不可选。
    /// 带提示时 OpenPGP 密钥提示完整指纹，SSH 密钥提示 ssh-add 列出的那一行，找不到的已配置密钥提示配置的值；
    /// 身份档案的菜单不带提示。
    @Test("签名密钥菜单的各项与提示")
    @MainActor
    func popUpItems() {
        let fingerprint = "0123456789ABCDEF0123456789ABCDEFBB199F7C"
        let gpg = SigningKey(format: .openpgp, value: fingerprint, fingerprint: fingerprint, signer: nil, comment: nil)
        let unknown = "key::ssh-ed25519 BBBB"

        let ssh = SigningKey(
            format: .ssh,
            value: "key::ssh-ed25519 AAAA wgy@laptop",
            fingerprint: "SHA256:aGVsbG8gd29ybGQgdGhpcyBpcyBhIGtleQ1a2b3c4d",
            signer: nil,
            comment: "wgy@laptop"
        )

        let items = SigningKeyPopUp.items(keys: [gpg, ssh], unknown: unknown, showsToolTips: true)

        #expect(items.map(\.value) == [fingerprint, ssh.value, unknown, nil])
        #expect(items.map(\.toolTip) == [fingerprint, "ssh-ed25519 AAAA wgy@laptop", unknown, nil])
        #expect(items.map(\.isEnabled) == [true, true, false, true])

        // 身份档案的菜单不带提示，找不到的已配置密钥同样不可选
        let plain = SigningKeyPopUp.items(keys: [ssh], unknown: unknown, showsToolTips: false)

        #expect(plain.allSatisfy { $0.toolTip == nil })
        #expect(plain.map(\.isEnabled) == [true, false, true])
    }

    /// 标题去掉首尾空格后重名即重复；姓名与邮箱按原字符串同时相同也重复，只是邮箱相同不算，签名密钥不参与；编辑时不和自己比较。
    @Test("档案的重复检查")
    func duplicateProfiles() {
        let work = UserProfile(title: "Work", name: "Ada Lovelace", email: "ada@work.example")
        let home = UserProfile(title: "Home", name: "Grace Hopper", email: "grace@example.com")

        let duplicate = { (title: String, name: String, email: String) in
            UserProfiles.duplicate(of: UserProfile(title: title, name: name, email: email), in: [work])
        }

        #expect(duplicate(" Work ", "Grace Hopper", "grace@example.com") == .title)
        #expect(duplicate("Home", "Ada Lovelace", "ada@work.example") == .identity)
        #expect(duplicate("Home", "Grace Hopper", "ada@work.example") == nil)
        #expect(duplicate("Home", "ada lovelace", "ada@work.example") == nil)

        // 签名密钥不参与：只差密钥的同一身份仍然重复
        let signed = UserProfile(title: "Signed", name: work.name, email: work.email, signingKey: "BB199F7C")
        #expect(UserProfiles.duplicate(of: signed, in: [work]) == .identity)

        // 编辑已有档案：不改动时不和自己比较；改成另一个档案的标题才重复
        #expect(UserProfiles.duplicate(of: work, in: [work, home]) == nil)

        var edited = work
        edited.title = "Home"
        #expect(UserProfiles.duplicate(of: edited, in: [work, home]) == .title)
    }
}
