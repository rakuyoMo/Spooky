import Foundation
import Testing

@testable import SpookyKit

// MARK: - SigningKeysTests

/// 编辑身份档案时列出的签名密钥：只列能签名的密钥，写入的值要让 Git 选中同一把密钥。
struct SigningKeysTests {
    /// 两把私钥：第一把能签名，用户标识含转义的冒号与中文；第二把只能加密，不能用来签名。
    static let secretKeys = """
        sec:u:255:22:0123456789ABCDEF:1700000000:::u:::scESC:::+:::ed25519:::0:
        fpr:::::::::0A1B2C3D4E5F60718293A4B50123456789ABCDEF:
        grp:::::::::FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF:
        uid:r::::1690000000::AAAA::旧 名字 <old@example.invalid>::::::::::0:
        uid:u::::1700000000::BBBB::签名 人 (工作\\x3a 主力) <sign@example.invalid>::::::::::0:
        ssb:u:255:18:1111222233334444:1700000000::::::e:::+:::cv25519::
        fpr:::::::::9999999999999999999999991111222233334444:
        sec:e:255:22:FEDCBA9876543210:1500000000:1600000000::u:::sc:::+:::ed25519:::0:
        fpr:::::::::FEDCBA9876543210FEDCBA9876543210FEDCBA98:
        uid:e::::1500000000::CCCC::过期 <expired@example.invalid>::::::::::0:

        """

    /// 能签名的私钥按主密钥指纹写入，签名人取第一条未吊销的用户标识并还原转义；子密钥的指纹不会顶替主密钥。
    @Test("解析 gpg 的签名私钥")
    func parsesSecretKeys() {
        let keys = SigningKeys.parseSecretKeys(Data(Self.secretKeys.utf8))

        #expect(keys.count == 1)
        #expect(keys.first?.format == .openpgp)
        #expect(keys.first?.value == "0A1B2C3D4E5F60718293A4B50123456789ABCDEF")
        #expect(keys.first?.fingerprint == keys.first?.value)
        #expect(keys.first?.signer == "签名 人 (工作: 主力) <sign@example.invalid>")
    }

    /// 截断的记录、出现在密钥之前的指纹与不是十六进制的指纹都不会产生密钥，也不会让解析中断。
    @Test("gpg 输出格式错误时不列出密钥")
    func ignoresMalformedSecretKeys() {
        let output = """
            fpr:::::::::0A1B2C3D4E5F60718293A4B5C6D7E8F901234567:
            sec:u:255
            fpr:::::::::0A1B2C3D4E5F60718293A4B5C6D7E8F901234567:
            sec:u:255:22:0123456789ABCDEF:1700000000:::u:::scESC:::+:::ed25519:::0:
            fpr:::::::::不是指纹:
            """

        #expect(SigningKeys.parseSecretKeys(Data(output.utf8)).isEmpty)
        #expect(SigningKeys.parseSecretKeys(Data()).isEmpty)
    }

    /// agent 的每行公钥写成 `key::` 字面值，注释里的空格与中文原样保留；没有密钥的提示与损坏的行跳过。
    @Test("解析 ssh-add 列出的公钥")
    func parsesAgentKeys() throws {
        let literal = Self.publicKey()
        let output = literal + " /Users/测试/.ssh/签名 key\n"
            + literal + "\n"
            + "The agent has no identities.\n"
            + "ssh-rsa " + literal.split(separator: " ")[1] + " 类型不符\n"
            + "ssh-ed25519 !!!不是Base64 坏行\n"

        let keys = SigningKeys.parseAgentKeys(Data(output.utf8))
        let first = try #require(keys.first)

        #expect(keys.count == 2)
        #expect(keys.allSatisfy { $0.format == .ssh && $0.value == "key::" + literal })
        #expect(first.comment == "/Users/测试/.ssh/签名 key")
        #expect(keys.last?.comment == nil)

        // 写入的值按 Git 的写法会被认成 SSH 格式。
        #expect(SigningFormat(key: first.value) == .ssh)
    }

    /// 字面公钥的指纹与 ssh-keygen 读同一个公钥文件给出的指纹一致。
    @Test("SSH 指纹与 ssh-keygen 一致")
    func fingerprintMatchesSSHKeygen() async throws {
        let literal = Self.publicKey()
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-keys-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appending(path: "测试 key.pub")
        try Data((literal + " comment\n").utf8).write(to: file)

        let result = try await CommandExecutor.execute(
            executable: "/usr/bin/ssh-keygen",
            processArguments: ["-l", "-E", "sha256", "-f", file.path],
            arguments: ["ssh-keygen", "-l"]
        )
        let reported = String(decoding: result.standardOutput, as: UTF8.self).split(separator: " ")[1]

        #expect(SigningKeys.fingerprint(ofLiteral: "key::" + literal) == String(reported))
        #expect(SigningKeys.fingerprint(ofLiteral: literal + " 注释") == String(reported))
        #expect(SigningKeys.fingerprint(ofLiteral: "~/.ssh/id_ed25519.pub") == nil)
    }

    /// 配置里写的指纹、长短 ID、`0x` 前缀与 `!` 后缀都指向同一把 OpenPGP 密钥；SSH 只认类型与公钥。
    @Test("配置值与密钥的对应")
    func matchesConfiguredValues() throws {
        let openPGP = try #require(SigningKeys.parseSecretKeys(Data(Self.secretKeys.utf8)).first)

        for value in ["0a1b2c3d4e5f60718293a4b50123456789abcdef", "0x89ABCDEF", "0123456789ABCDEF!"] {
            #expect(openPGP.matches(value))
        }

        for value in ["ABCDEF", "sign@example.invalid", "11112222"] {
            #expect(!openPGP.matches(value))
        }

        let literal = Self.publicKey()
        let ssh = try #require(SigningKeys.parseAgentKeys(Data(literal.utf8)).first)

        #expect(ssh.matches("key::" + literal + " 别的注释"))
        #expect(ssh.matches(literal))
        #expect(!ssh.matches("key::" + Self.publicKey(seed: 7)))
        #expect(!ssh.matches("~/.ssh/id_ed25519.pub"))
        #expect(!openPGP.matches("key::" + literal))
    }

    /// gpg 从查找目录里找到并以批处理方式列出私钥，排在 agent 的 SSH 密钥之前；找不到 gpg 时没有 OpenPGP 密钥。
    @Test("列出本机密钥")
    func listsLocalKeys() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-gpg-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        // 模拟的 gpg 只在批处理列出私钥时输出，参数不对就失败。
        let script = "#!/bin/sh\n"
            + "case \" $* \" in *\" --batch \"*\" --list-secret-keys \"*) cat <<'EOF'\n"
            + Self.secretKeys
            + "EOF\n;; *) exit 2;; esac\n"
        let gpg = directory.appending(path: "gpg")
        try Data(script.utf8).write(to: gpg)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: gpg.path)

        let keys = await SigningKeys.local(searchPaths: ["/nonexistent", directory.path])
        let expected = SigningKeys.parseSecretKeys(Data(Self.secretKeys.utf8))

        #expect(Array(keys.prefix(expected.count)) == expected)
        #expect(keys.dropFirst(expected.count).allSatisfy { $0.format == .ssh })

        let withoutGPG = await SigningKeys.local(searchPaths: ["/nonexistent"])
        #expect(withoutGPG.allSatisfy { $0.format == .ssh })
    }
}

// MARK: - Helpers

extension SigningKeysTests {
    /// 按 OpenSSH 的线格式拼出一把 ed25519 公钥：类型名与 32 字节公钥各带 4 字节长度。
    ///
    /// 只用于解析与指纹计算，不是任何人在用的密钥，也不对应私钥。
    static func publicKey(seed: UInt8 = 1) -> String {
        let type = Array("ssh-ed25519".utf8)
        let key = (0 ..< 32).map { UInt8($0) &+ seed }

        func field(_ bytes: [UInt8]) -> [UInt8] {
            withUnsafeBytes(of: UInt32(bytes.count).bigEndian, Array.init) + bytes
        }

        return "ssh-ed25519 " + Data(field(type) + field(key)).base64EncodedString()
    }
}
