import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - CommitSignatureDisplayTests

/// 详情头部的签名行按签名的种类与内容选择标签，密钥只写短标识。
@MainActor
struct CommitSignatureDisplayTests {
    /// 有身份的 OpenPGP 签名三行 GPG，SSH 签名两行 Signing；无法校验时仍有状态行，缺短标识时不写密钥行；没有签名时没有签名行。
    @Test("详情头部的签名行")
    func signatureRows() {
        let openPGP = CommitSignature(
            status: .expiredKey,
            signer: "Spooky Test <spooky@example.invalid>",
            key: "0123456789ABCDEF",
            primaryFingerprint: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFDC76241",
            fingerprint: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB01234567"
        )

        #expect(Self.rows(openPGP) == [
            ["history.gpgUser", "Spooky Test <spooky@example.invalid>"],
            ["history.gpgKey", "FDC76241"],
            ["history.gpgStatus", SignatureStatus.expiredKey.title],
        ])

        // SSH 的身份即使写成 “姓名 <邮箱>” 也用 Signing 两行，短标识取 SHA-256 指纹
        let ssh = CommitSignature(
            status: .good,
            signer: "Spooky Test <spooky@example.invalid>",
            key: "SHA256:abcdefghijklmnopqrstuvwxyzoyKcyYZc",
            fingerprint: "SHA256:abcdefghijklmnopqrstuvwxyzoyKcyYZc"
        )

        #expect(Self.rows(ssh) == [
            ["history.signingKey", "oyKcyYZc"],
            ["history.signingStatus", SignatureStatus.good.title],
        ])

        // 缺公钥的 OpenPGP 只有密钥 ID，不拿它当短标识
        let missingKey = CommitSignature(status: .cannotCheck, key: "0123456789ABCDEF")

        #expect(Self.rows(missingKey) == [["history.signingStatus", SignatureStatus.cannotCheck.title]])
        #expect(Self.rows(CommitSignature(status: .unsigned)).isEmpty)
        #expect(Self.rows(nil).isEmpty)
    }
}

// MARK: - Helpers

extension CommitSignatureDisplayTests {
    /// 签名行展开成 “标签键、值” 两项的数组，便于整体比较。
    private static func rows(_ signature: CommitSignature?) -> [[String]] {
        CommitMetadataView.signatureRows(signature).map { [$0.key, $0.value] }
    }
}
