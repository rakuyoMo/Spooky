import CryptoKit
import Foundation

// MARK: - SigningKey

/// 本机一把可以为提交签名的密钥：gpg 钥匙环里的私钥，或 SSH agent 里的密钥。
public struct SigningKey: Sendable, Hashable {
    /// 签名格式，只会是 OpenPGP 或 SSH。
    public let format: SigningFormat

    /// 写入 `user.signingkey` 的值：OpenPGP 为主密钥的完整指纹，SSH 为 `key::` 加类型与公钥。
    public let value: String

    /// 指纹：OpenPGP 为大写十六进制的主密钥指纹，SSH 为 `SHA256:` 开头的公钥指纹。
    public let fingerprint: String

    /// OpenPGP 密钥的主用户标识，如 “姓名 <邮箱>”；SSH 密钥没有。
    public let signer: String?

    /// SSH 公钥的注释，ssh-add 加入的密钥通常是私钥路径；OpenPGP 密钥没有。
    public let comment: String?

    /// 创建一把签名密钥。
    public init(format: SigningFormat, value: String, fingerprint: String, signer: String?, comment: String?) {
        self.format = format
        self.value = value
        self.fingerprint = fingerprint
        self.signer = signer
        self.comment = comment
    }

    /// 判断 `user.signingkey` 的值是否指向这把密钥。
    ///
    /// OpenPGP 认完整指纹与长短密钥 ID，允许 `0x` 前缀与表示 “就用这把子密钥” 的 `!` 后缀；
    /// SSH 认类型与公钥都相同的字面值，注释不同也算同一把。路径等其它写法无法在本机判断，一律不匹配。
    ///
    /// - Parameter configured: 配置里的签名密钥。
    public func matches(_ configured: String) -> Bool {
        switch format {
        case .ssh:
            guard let literal = SigningKeys.literal(configured) else { return false }
            return literal.type + " " + literal.base64 == String(value.dropFirst(SigningKeys.literalPrefix.count))

        case .openpgp, .x509:
            var identifier = configured.trimmingCharacters(in: .whitespaces).uppercased()

            if identifier.hasPrefix("0X") {
                identifier.removeFirst(2)
            }

            if identifier.hasSuffix("!") {
                identifier.removeLast()
            }

            // 短 ID 是 8 位，再短就会误配其它密钥。
            guard identifier.count >= 8, identifier.allSatisfy(\.isHexDigit) else { return false }
            return fingerprint.hasSuffix(identifier)
        }
    }
}

// MARK: - SigningKeys

/// 列出本机可用的签名密钥；身份档案是本机的全局设置，选择密钥时只列本机的密钥。
public enum SigningKeys {
    /// `user.signingkey` 中字面 SSH 公钥的前缀。
    static let literalPrefix = "key::"

    /// 查找 gpg 的目录：先是进程的 PATH，再是常见的安装位置；从访达启动的 App 只有系统自带的 PATH。
    public static var searchPaths: [String] {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let installs = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/local/MacGPG2/bin"]
        return path.split(separator: ":").map(String.init) + installs
    }

    /// 本机的 OpenPGP 签名私钥在前，SSH agent 里的密钥在后；程序缺失或读取失败的一类为空。
    ///
    /// - Parameter searchPaths: 依次查找 gpg 的目录。
    public static func local(searchPaths: [String] = searchPaths) async -> [SigningKey] {
        #warning(
            "TODO: 列出的密钥范围是推断：OpenPGP 只列能签名、未过期未吊销的私钥，SSH 只列 agent 里现有的密钥。核实方式：在钥匙环里放一把过期密钥、一把只能加密的密钥，并让 agent 卸下档案正在用的 SSH 密钥，再打开编辑档案的签名密钥菜单比对；只影响菜单列出哪些密钥。"
        )

        async let openPGP = secretKeys(searchPaths: searchPaths)
        async let ssh = agentKeys()

        return await openPGP + ssh
    }

    /// 由字面 SSH 公钥算出 `SHA256:` 指纹；不是字面公钥或公钥无法解码时为 nil。
    ///
    /// - Parameter configured: `key::` 开头或直接以密钥类型开头的公钥。
    public static func fingerprint(ofLiteral configured: String) -> String? {
        literal(configured).map { fingerprint(of: $0.blob) }
    }

    /// 解析 `gpg --with-colons --list-secret-keys` 的输出，只保留整体能签名的密钥。
    ///
    /// 每把密钥从 `sec` 记录开始：第 12 个字段出现大写的 `S` 表示整把密钥（含子密钥）可用于签名，
    /// 过期、吊销或禁用的密钥不会有它；其后第一条 `fpr` 是主密钥指纹，第一条未吊销的 `uid` 是签名人。
    /// 子密钥（`ssb`）之后的 `fpr` 属于子密钥，不用。
    static func parseSecretKeys(_ data: Data) -> [SigningKey] {
        var keys: [SigningKey] = []
        var current: PendingKey? = nil

        for line in String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

            switch fields.first {
            case "sec":
                if let key = current?.key {
                    keys.append(key)
                }

                current = PendingKey(canSign: fields.count > 11 && fields[11].contains("S"))

            case "ssb":
                current?.inSubkey = true

            case "fpr" where (current?.wantsFingerprint ?? false) && fields.count > 9:
                current?.fingerprint = fields[9].uppercased()

            case "uid" where current?.signer == nil && fields.count > 9 && fields[1] != "r":
                current?.signer = unescaped(fields[9])

            default:
                break
            }
        }

        if let key = current?.key {
            keys.append(key)
        }

        return keys
    }

    /// 解析 `ssh-add -L` 的输出：每行是类型、Base64 公钥与可选的注释；公钥里的类型与行首不符的行跳过。
    static func parseAgentKeys(_ data: Data) -> [SigningKey] {
        String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let parts = line.split(separator: " ", maxSplits: 2).map(String.init)

                guard parts.count >= 2, let literal = literal(parts[0] + " " + parts[1]) else { return nil }

                return SigningKey(
                    format: .ssh,
                    value: literalPrefix + literal.type + " " + literal.base64,
                    fingerprint: fingerprint(of: literal.blob),
                    signer: nil,
                    comment: parts.count > 2 ? parts[2] : nil
                )
            }
    }

    /// 拆出字面 SSH 公钥的类型与 Base64 公钥，并核对公钥开头的类型名。
    static func literal(_ configured: String) -> (type: String, base64: String, blob: Data)? {
        let text = configured.hasPrefix(literalPrefix)
            ? String(configured.dropFirst(literalPrefix.count))
            : configured
        let parts = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

        guard
            parts.count >= 2,
            let blob = Data(base64Encoded: parts[1]),
            embeddedType(of: blob) == parts[0]
        else { return nil }

        return (parts[0], parts[1], blob)
    }
}

// MARK: - Private

extension SigningKeys {
    /// 解析 `sec` 记录到下一把密钥之间收集到的信息。
    private struct PendingKey {
        /// 整把密钥能否签名。
        let canSign: Bool

        /// 主密钥指纹。
        var fingerprint: String? = nil

        /// 第一条未吊销的用户标识。
        var signer: String? = nil

        /// 已经读到子密钥，之后的指纹不属于主密钥。
        var inSubkey = false

        /// 还没读到主密钥指纹，下一条 `fpr` 就是它。
        var wantsFingerprint: Bool {
            !inSubkey && fingerprint == nil
        }

        /// 能签名且有十六进制指纹时成为一把密钥。
        var key: SigningKey? {
            guard canSign, let fingerprint, !fingerprint.isEmpty, fingerprint.allSatisfy(\.isHexDigit) else {
                return nil
            }

            return SigningKey(format: .openpgp, value: fingerprint, fingerprint: fingerprint, signer: signer, comment: nil)
        }
    }

    /// 在查找目录里找到可执行的 gpg，列出本机的签名私钥。
    private static func secretKeys(searchPaths: [String]) async -> [SigningKey] {
        let program = searchPaths
            .map { URL(fileURLWithPath: $0).appending(path: "gpg").path }
            .first { FileManager.default.isExecutableFile(atPath: $0) }

        guard let program else { return [] }

        // 批处理模式不会弹出 pinentry，也不会顺带更新信任数据库。
        let arguments = [
            "--batch", "--no-tty", "--no-auto-check-trustdb",
            "--with-colons", "--with-fingerprint", "--list-secret-keys",
        ]

        let result = try? await CommandExecutor.execute(
            executable: program,
            processArguments: arguments,
            arguments: ["gpg"] + arguments
        )

        return result.map { parseSecretKeys($0.standardOutput) } ?? []
    }

    /// 列出所选 SSH agent 里的公钥；agent 没有密钥时 ssh-add 以 1 退出，连不上 agent 时以 2 退出，都视为没有。
    private static func agentKeys() async -> [SigningKey] {
        let result = try? await CommandExecutor.execute(
            executable: "/usr/bin/ssh-add",
            processArguments: ["-L"],
            arguments: ["ssh-add", "-L"],
            environment: .inherit.updating(LocalExecutionSettings.current.sshOverrides),
            acceptedExitCodes: [0, 1]
        )

        return result.map { parseAgentKeys($0.standardOutput) } ?? []
    }

    /// 与 ssh-keygen 相同的写法：公钥的 SHA-256 摘要，Base64 去掉末尾的填充。
    private static func fingerprint(of blob: Data) -> String {
        let digest = Data(SHA256.hash(data: blob)).base64EncodedString()
        return "SHA256:" + digest.trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    /// 公钥开头以 4 字节大端长度标出的类型名；长度不对时为 nil。
    private static func embeddedType(of blob: Data) -> String? {
        let bytes = [UInt8](blob)

        guard bytes.count >= 4 else { return nil }

        let length = bytes[0 ..< 4].reduce(0) { $0 << 8 | Int($1) }

        guard length > 0, bytes.count >= 4 + length else { return nil }

        return String(bytes: bytes[4 ..< 4 + length], encoding: .utf8)
    }

    /// 还原 gpg 冒号格式里转义成 `\xHH` 的字节，如冒号写作 `\x3a`；其余内容按 UTF-8 原样保留。
    private static func unescaped(_ field: String) -> String {
        let bytes = [UInt8](field.utf8)
        var result: [UInt8] = []
        var index = 0

        while index < bytes.count {
            let escape = index + 3 < bytes.count
                && bytes[index] == UInt8(ascii: "\\")
                && bytes[index + 1] == UInt8(ascii: "x")

            let value = escape
                ? UInt8(String(decoding: bytes[index + 2 ... index + 3], as: UTF8.self), radix: 16)
                : nil

            if let value {
                result.append(value)
                index += 4
            } else {
                result.append(bytes[index])
                index += 1
            }
        }

        return String(decoding: result, as: UTF8.self)
    }
}
