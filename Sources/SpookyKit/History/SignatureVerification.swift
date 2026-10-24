import Foundation

// MARK: - SignatureVerification

/// 校验签名时使用的 gpg：经包装器的 gpg 入口关闭自动取钥与信任库检查，校验不会卡在网络上。
///
/// 服务器仓库的每条命令都已把 gpg 程序配置为包装器；本机仓库为这次校验临时安装同一个包装器。
enum SignatureVerification {
    /// 准备好 gpg 程序后执行校验命令。
    ///
    /// - Parameter body: 接收要加在命令前面的全局参数；服务器仓库为空。
    static func run<T>(on runner: GitRunner, _ body: ([String]) async throws -> T) async throws -> T {
        guard runner.remote == nil else {
            return try await body([])
        }

        let directory = URL(fileURLWithPath: "/tmp/spooky-verify-" + UUID().uuidString.lowercased())

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        defer { try? FileManager.default.removeItem(at: directory) }

        guard let source = Bundle.module.url(forResource: "spooky-remote", withExtension: "pl") else {
            throw RemoteConnectionError(.deployment)
        }

        let wrapper = directory.appendingPathComponent("callback")
        try FileManager.default.copyItem(at: source, to: wrapper)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: wrapper.path)

        // 包装器按调用名区分模式，gpg 入口是指向它的链接；Git 直接执行这个程序，路径不经 shell
        let program = wrapper.path + "-gpg"
        try FileManager.default.createSymbolicLink(atPath: program, withDestinationPath: wrapper.path)

        return try await body(["-c", "gpg.program=" + program])
    }
}

// MARK: - CommitObjects

/// `cat-file --batch` 读出的提交对象。
enum CommitObjects {
    /// 解析 `cat-file --batch` 的输出：每个对象一行 “哈希 类型 大小”，随后是内容与一个换行；不存在的对象只有 “哈希 missing”。
    static func parse(_ data: Data) throws -> [(id: String, content: Data)] {
        var objects: [(id: String, content: Data)] = []
        var cursor = data.startIndex

        while cursor < data.endIndex {
            guard let newline = data[cursor...].firstIndex(of: 10) else {
                throw RepositoryReadError.malformedOutput("cat-file")
            }

            let header = String(decoding: data[cursor ..< newline], as: UTF8.self).split(separator: " ")
            cursor = data.index(after: newline)

            if header.count == 2, header[1] == "missing" {
                continue
            }

            guard
                header.count == 3,
                GitObjectID.isValid(String(header[0])),
                let size = Int(header[2]), size >= 0,
                data.distance(from: cursor, to: data.endIndex) > size
            else { throw RepositoryReadError.malformedOutput("cat-file") }

            let end = data.index(cursor, offsetBy: size)

            guard data[end] == 10 else {
                throw RepositoryReadError.malformedOutput("cat-file")
            }

            objects.append((String(header[0]), Data(data[cursor ..< end])))
            cursor = data.index(after: end)
        }

        return objects
    }

    /// 提交头部（第一个空行之前）带有签名头。
    static func hasSignature(_ content: Data) -> Bool {
        let head = content.range(of: Data("\n\n".utf8)).map { content[..<$0.lowerBound] } ?? content[...]

        return head.split(separator: 10).contains {
            $0.starts(with: Data("gpgsig ".utf8)) || $0.starts(with: Data("gpgsig-sha256 ".utf8))
        }
    }
}

// MARK: - Tag Signatures

extension RepositoryReferences {
    /// 校验标签的签名；轻量标签与没有签名的附注标签都记为没有签名。
    ///
    /// - Parameter reference: 完整引用名，如 `refs/tags/v1.0`。
    public func signature(ofTag reference: String) async throws -> CommitSignature {
        guard
            reference.hasPrefix("refs/tags/"),
            !reference.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
        else { throw RepositoryReadError.invalidQuery }

        // 签名无效或无法校验时 verify-tag 以 1 退出，结果写在标准错误里
        let result = try await SignatureVerification.run(on: runner) { options in
            try await runner.execute(options + ["verify-tag", "--raw", "--", reference], acceptedExitCodes: [0, 1])
        }

        return TagVerification.parse(result)
    }
}

// MARK: - TagVerification

/// `verify-tag --raw` 的结果：OpenPGP 为 `[GNUPG:]` 状态行，SSH 为 ssh-keygen 的说明。
enum TagVerification {
    /// OpenPGP 状态关键字对应的结果，与提交的 `%G?` 使用同一套字母。
    private static let statuses: [String: SignatureStatus] = [
        "GOODSIG": .good, "BADSIG": .bad, "EXPSIG": .expiredSignature,
        "EXPKEYSIG": .expiredKey, "REVKEYSIG": .revokedKey, "ERRSIG": .cannotCheck,
    ]

    /// 按标准错误的内容归类；没有可识别的签名输出时，退出码为 0 也不当作有效签名。
    static func parse(_ result: GitCommandResult) -> CommitSignature {
        let text = String(decoding: result.standardError, as: UTF8.self)

        if text.contains("[GNUPG:] ") {
            return openPGP(text)
        }

        return ssh(text)
    }

    /// OpenPGP：好签名在信任级别未定义或为 never 时与 Git 一样记为可信度未知。
    private static func openPGP(_ text: String) -> CommitSignature {
        var status = SignatureStatus.cannotCheck
        var signer = ""
        var key = ""
        var fingerprint = ""
        var trusted = false

        for line in text.split(separator: "\n") where line.hasPrefix("[GNUPG:] ") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: false).map(String.init)

            guard parts.count > 1 else {
                continue
            }

            if let value = statuses[parts[1]], parts.count > 2 {
                status = value
                key = parts[2]
                signer = parts[1] == "ERRSIG" ? "" : parts.dropFirst(3).joined(separator: " ")
            } else if parts[1] == "VALIDSIG", parts.count > 11 {
                fingerprint = parts[11]
            } else if ["TRUST_MARGINAL", "TRUST_FULLY", "TRUST_ULTIMATE"].contains(parts[1]) {
                trusted = true
            }
        }

        if status == .good, !trusted {
            status = .unknownValidity
        }

        return CommitSignature(status: status, signer: signer, key: key, primaryFingerprint: fingerprint)
    }

    /// SSH：“Good "git" signature for <身份> with <类型> key <指纹>” 有效；没有 “for” 的是不在 allowed signers 里的密钥。
    private static func ssh(_ text: String) -> CommitSignature {
        let lines = text.split(separator: "\n").map(String.init)
        let good = "Good \"git\" signature "

        if let line = lines.first(where: { $0.hasPrefix(good) }) {
            let key = line.split(separator: " ").last.map(String.init) ?? ""
            let rest = line.dropFirst(good.count)

            guard
                rest.hasPrefix("for "),
                let with = rest.range(of: " with ", options: .backwards)
            else { return CommitSignature(status: .unknownValidity, key: key) }

            return CommitSignature(
                status: .good,
                signer: String(rest[rest.index(rest.startIndex, offsetBy: 4) ..< with.lowerBound]),
                key: key
            )
        }

        if text.contains("no signature found") || text.contains("cannot verify a non-tag object") {
            return CommitSignature(status: .unsigned)
        }

        if text.contains("incorrect signature") || text.contains("Signature verification failed") {
            return CommitSignature(status: .bad)
        }

        return CommitSignature(status: .cannotCheck)
    }
}
