import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - UserProfilesTests

/// 签名密钥菜单里一把密钥的写法：身份档案、Git Config 页与仓库设置看到的文字相同，用户靠它分辨密钥。
struct UserProfilesTests {
    /// GPG 写签名人与指纹末 8 位；没有签名人时括号前只有格式名。
    @Test("GPG 密钥的菜单项")
    func gpgTitle() {
        let fingerprint = "0123456789ABCDEF0123456789ABCDEFBB199F7C"
        let signed = SigningKey(
            format: .openpgp,
            value: fingerprint,
            fingerprint: fingerprint,
            signer: "Valid Signer <valid@example.com>",
            comment: nil
        )
        let anonymous = SigningKey(format: .openpgp, value: fingerprint, fingerprint: fingerprint, signer: nil, comment: nil)

        #expect(UserProfiles.title(of: signed) == "GPG: Valid Signer <valid@example.com> (BB199F7C)")
        #expect(UserProfiles.title(of: anonymous) == "GPG: (BB199F7C)")
    }

    /// SSH 的注释是现有文件时写出路径并把主目录缩写成 `~`；文件不存在或没有注释时只写指纹末 8 位。
    @Test("SSH 密钥的菜单项")
    func sshTitle() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "spooky-home-" + UUID().uuidString)
        let file = home.appending(path: ".ssh/id_ed25519")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: home) }

        let fingerprint = "SHA256:aGVsbG8gd29ybGQgdGhpcyBpcyBhIGtleQ1a2b3c4d"
        let key = { (comment: String?) in
            SigningKey(
                format: .ssh,
                value: "key::ssh-ed25519 AAAA",
                fingerprint: fingerprint,
                signer: nil,
                comment: comment
            )
        }

        #expect(UserProfiles.title(of: key(file.path), home: home.path) == "SSH: ~/.ssh/id_ed25519 (1a2b3c4d)")
        #expect(UserProfiles.title(of: key(home.appending(path: "missing").path), home: home.path) == "SSH: (1a2b3c4d)")
        #expect(UserProfiles.title(of: key("wgy@laptop"), home: home.path) == "SSH: (1a2b3c4d)")
        #expect(UserProfiles.title(of: key(nil), home: home.path) == "SSH: (1a2b3c4d)")
    }
}
