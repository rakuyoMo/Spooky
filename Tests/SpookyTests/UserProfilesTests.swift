import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - UserProfilesTests

/// 签名密钥菜单里一把密钥的写法：身份档案、Git Config 页与仓库设置看到的文字相同，用户靠它分辨密钥；
/// 以及保存档案前的重复检查，重复的档案会让身份菜单分不清该勾哪一个。
struct UserProfilesTests {
    /// GPG 写签名人与指纹末 8 位，没有签名人时括号前只有格式名；
    /// SSH 的注释是现有文件时写出路径并把主目录缩写成 `~`，文件不存在或没有注释时只写指纹末 8 位。
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

        for comment in [missing, "wgy@laptop", nil] {
            #expect(UserProfiles.title(of: ssh(comment), home: home.path) == "SSH: (1a2b3c4d)")
        }
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
