import Foundation
import Testing

@testable import SpookyKit

// MARK: - SignatureVerificationTests

/// 提交与标签的签名校验：SSH 签名用测试仓库本地配置的 allowed signers；本机没有 gpg 时跳过 OpenPGP 的实测。
struct SignatureVerificationTests {
    /// 有效、不在 allowed signers 里、没有签名与内容被篡改的提交各自得到对应的状态。
    @Test("SSH 签名的提交状态", arguments: ["sha1", "sha256"])
    func commitSignatures(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let keys = try Self.keyDirectory()
        defer { try? FileManager.default.removeItem(at: keys) }

        let runner = fixture.runner
        let trusted = try await Self.makeKey(in: keys, name: "trusted key")
        let other = try await Self.makeKey(in: keys, name: "other key")
        try await Self.configure(fixture, signingKey: trusted, allowed: [("spooky@example.invalid", trusted)], keys: keys)

        let good = try await Self.commit(fixture, message: "signed", sign: true)
        let unsigned = try await Self.commit(fixture, message: "unsigned", sign: false)
        _ = try await runner.run(["config", "--local", "user.signingkey", other.path])
        let unknown = try await Self.commit(fixture, message: "other", sign: true)

        // 改掉已签名提交的说明，签名头原样保留
        let object = try await runner.run(["cat-file", "commit", good])
        let edited = Data(String(decoding: object, as: UTF8.self).replacingOccurrences(of: "signed\n", with: "tampered\n").utf8)
        let tampered = String(
            decoding: try await runner.run(["hash-object", "-t", "commit", "-w", "--stdin"], input: edited),
            as: UTF8.self
        )
        .trimmingCharacters(in: .newlines)

        let history = RepositoryHistory(runner: runner)
        let signatures = try await history.signatures(of: [good, unsigned, unknown, tampered])

        #expect(signatures[good]?.status == .good)
        #expect(signatures[good]?.signer == "spooky@example.invalid")
        #expect(signatures[good]?.key.hasPrefix("SHA256:") ?? false)
        #expect(signatures[good]?.email == nil)
        #expect(signatures[unsigned]?.status == SignatureStatus.unsigned)
        #expect(signatures[unknown]?.status == .unknownValidity)
        #expect(signatures[tampered]?.status == .bad)

        // 没有配置 allowed signers 时 Git 报告为没有签名，带签名头的提交改为无法校验
        _ = try await runner.run(["config", "--local", "--unset", "gpg.ssh.allowedSignersFile"])
        let unconfigured = try await history.signatures(of: [good, unsigned])
        #expect(unconfigured[good]?.status == .cannotCheck)
        #expect(unconfigured[unsigned]?.status == SignatureStatus.unsigned)

        await #expect(throws: RepositoryReadError.self) { try await history.signatures(of: ["HEAD"]) }
    }

    /// 标签：有效签名、不在 allowed signers 里的密钥、未签名的附注标签与轻量标签。
    @Test("SSH 签名的标签状态")
    func tagSignatures() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let keys = try Self.keyDirectory()
        defer { try? FileManager.default.removeItem(at: keys) }

        let runner = fixture.runner
        let trusted = try await Self.makeKey(in: keys, name: "trusted")
        let other = try await Self.makeKey(in: keys, name: "other")
        try await Self.configure(fixture, signingKey: trusted, allowed: [("spooky@example.invalid", trusted)], keys: keys)
        _ = try await Self.commit(fixture, message: "root", sign: false)

        _ = try await runner.run(["tag", "-s", "-m", "good", "签名/v1.0"])
        _ = try await runner.run(["tag", "-a", "-m", "plain", "plain"])
        _ = try await runner.run(["tag", "light"])
        _ = try await runner.run(["config", "--local", "user.signingkey", other.path])
        _ = try await runner.run(["tag", "-s", "-m", "other", "other"])

        let references = RepositoryReferences(runner: runner)
        let good = try await references.signature(ofTag: "refs/tags/签名/v1.0")
        #expect(good.status == .good && good.signer == "spooky@example.invalid")
        #expect(try await references.signature(ofTag: "refs/tags/other").status == .unknownValidity)
        #expect(try await references.signature(ofTag: "refs/tags/plain").status == SignatureStatus.unsigned)
        #expect(try await references.signature(ofTag: "refs/tags/light").status == SignatureStatus.unsigned)

        _ = try await runner.run(["config", "--local", "--unset", "gpg.ssh.allowedSignersFile"])
        #expect(try await references.signature(ofTag: "refs/tags/签名/v1.0").status == .cannotCheck)

        await #expect(throws: RepositoryReadError.self) { try await references.signature(ofTag: "refs/heads/main") }
    }

    /// 本机装有 gpg 时实测 OpenPGP 签名经包装器校验；没有 gpg 时跳过。
    @Test("OpenPGP 签名经包装器校验")
    func openPGP() async throws {
        let candidates = ["/opt/homebrew/bin/gpg", "/usr/local/bin/gpg", "/usr/local/MacGPG2/bin/gpg"]

        guard let gpg = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else {
            return
        }

        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let home = try Self.keyDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        // 密钥环只在临时目录里，签名与校验都经同一个 GNUPGHOME
        let runner = GitRunner(
            location: .local(path: fixture.directory.path),
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GNUPGHOME": home.path,
            ])
        )

        _ = try await CommandExecutor.execute(
            executable: gpg,
            processArguments: [
                "--homedir", home.path, "--batch", "--pinentry-mode", "loopback", "--passphrase", "",
                "--quick-generate-key", "Spooky Test <spooky@example.invalid>", "ed25519", "sign", "never",
            ],
            arguments: ["gpg"]
        )

        _ = try await runner.run(["config", "--local", "gpg.program", gpg])
        _ = try await runner.run(["config", "--local", "user.signingkey", "spooky@example.invalid"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-S", "-m", "gpg"])

        let commit = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let signature = try #require(try await RepositoryHistory(runner: runner).signatures(of: [commit])[commit])
        #expect([.good, .unknownValidity].contains(signature.status))
        #expect(signature.email == "spooky@example.invalid")
    }

    /// OpenPGP 校验经包装器调用仓库配置的 gpg，并关闭自动取钥与信任库检查；用记录参数的假 gpg 验证，不需要真的 gpg。
    @Test("OpenPGP 校验关闭自动取钥与信任库检查")
    func verificationOptions() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let scripts = try Self.keyDirectory()
        defer { try? FileManager.default.removeItem(at: scripts) }

        // 假 gpg 只记下收到的参数，然后以失败退出
        let record = scripts.appending(path: "arguments")
        let program = scripts.appending(path: "fake gpg")
        try Data("#!/bin/sh\nprintf '%s\\n' \"$@\" > '\(record.path)'\nexit 2\n".utf8).write(to: program)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: program.path)

        let runner = fixture.runner
        _ = try await runner.run(["config", "--local", "gpg.program", program.path])
        let unsigned = try await Self.commit(fixture, message: "base", sign: false)

        // 在提交对象里放一段 OpenPGP 签名头，Git 校验时会调用 gpg
        let object = String(decoding: try await runner.run(["cat-file", "commit", unsigned]), as: UTF8.self)
        let header = "gpgsig -----BEGIN PGP SIGNATURE-----\n \n iQEz\n -----END PGP SIGNATURE-----\n\n"
        let signed = Data(object.replacingOccurrences(of: "\n\n", with: "\n" + header).utf8)
        let id = String(
            decoding: try await runner.run(["hash-object", "-t", "commit", "-w", "--stdin"], input: signed),
            as: UTF8.self
        )
        .trimmingCharacters(in: .newlines)

        let signature = try #require(try await RepositoryHistory(runner: runner).signatures(of: [id])[id])
        #expect(signature.status != .good)

        let arguments = String(decoding: try Data(contentsOf: record), as: UTF8.self).split(separator: "\n")
        #expect(Array(arguments.prefix(2)) == ["--no-auto-key-retrieve", "--no-auto-check-trustdb"])
        #expect(arguments.contains("--verify"))
    }

    /// 签名查询与 cat-file 输出的格式错误；标签的 gpg 状态行按 Git 的规则归类。
    @Test("签名输出的解析")
    func parsing() throws {
        let hash = String(repeating: "b", count: 40)
        let parsed = try CommitSignature.parse(Data("\(hash)\0G\0Name <mail@example.invalid>\0KEY\0FPR\0".utf8))
        #expect(parsed[hash]?.name == "Name" && parsed[hash]?.email == "mail@example.invalid")

        for malformed in ["\(hash)\0G\0", "\(hash)\0Z\0\0\0\0", "HEAD\0G\0\0\0\0", "\(hash)\0G\0\0\0"] {
            #expect(throws: RepositoryReadError.self) { try CommitSignature.parse(Data(malformed.utf8)) }
        }

        let object = "\(hash) commit 11\ngpgsig x\n\nm\n\(hash) missing\n"
        let objects = try CommitObjects.parse(Data(object.utf8))
        #expect(objects.count == 1 && CommitObjects.hasSignature(objects[0].content))
        #expect(!CommitObjects.hasSignature(Data("tree a\n\ngpgsig in message\n".utf8)))
        #expect(throws: RepositoryReadError.self) { try CommitObjects.parse(Data("\(hash) commit 99\nshort\n".utf8)) }

        let good = "[GNUPG:] GOODSIG ABC Name <a@b.c>\n[GNUPG:] VALIDSIG F1 2 3 4 5 6 7 8 9 PRIMARY\n"
        #expect(TagVerification.parse(Self.result(good)).status == .unknownValidity)
        #expect(TagVerification.parse(Self.result(good + "[GNUPG:] TRUST_ULTIMATE 0 pgp\n")) == CommitSignature(
            status: .good,
            signer: "Name <a@b.c>",
            key: "ABC",
            primaryFingerprint: "PRIMARY"
        ))
        #expect(TagVerification.parse(Self.result("[GNUPG:] BADSIG ABC Name <a@b.c>\n")).status == .bad)
        #expect(TagVerification.parse(Self.result("[GNUPG:] EXPKEYSIG ABC Name\n")).status == .expiredKey)
        #expect(TagVerification.parse(Self.result("[GNUPG:] ERRSIG ABC 1 2 00 0 9\n")).status == .cannotCheck)
        #expect(TagVerification.parse(Self.result("Signature verification failed: incorrect signature\n")).status == .bad)
    }
}

// MARK: - Helpers

extension SignatureVerificationTests {
    /// 私钥目录权限为 0700，路径不含会被 ssh-keygen 拒绝的字符。
    private static func keyDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: "/tmp/spooky-verify-test-" + UUID().uuidString.prefix(8).lowercased())

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        return directory
    }

    /// 生成没有口令的 ed25519 密钥，返回私钥路径。
    private static func makeKey(in directory: URL, name: String) async throws -> URL {
        let key = directory.appending(path: name)

        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/ssh-keygen",
            processArguments: ["-q", "-t", "ed25519", "-N", "", "-C", name, "-f", key.path],
            arguments: ["ssh-keygen"]
        )

        return key
    }

    /// SSH 签名与 allowed signers 都写进测试仓库的本地配置。
    private static func configure(
        _ fixture: TemporaryRepository,
        signingKey: URL,
        allowed: [(String, URL)],
        keys: URL
    ) async throws {
        let signers = keys.appending(path: "allowed signers")
        let lines = try allowed.map { principal, key in
            principal + " " + String(decoding: try Data(contentsOf: key.appendingPathExtension("pub")), as: UTF8.self)
        }

        try Data(lines.joined().utf8).write(to: signers)

        for (name, value) in [
            ("gpg.format", "ssh"),
            ("user.signingkey", signingKey.path),
            ("gpg.ssh.allowedSignersFile", signers.path),
        ] {
            _ = try await fixture.runner.run(["config", "--local", name, value])
        }
    }

    /// 创建一个空提交并返回它的哈希。
    private static func commit(_ fixture: TemporaryRepository, message: String, sign: Bool) async throws -> String {
        _ = try await fixture.runner.run(["commit", "-q", "--allow-empty", sign ? "-S" : "--no-gpg-sign", "-m", message])
        return try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
    }

    /// 只有标准错误的命令结果。
    private static func result(_ standardError: String) -> GitCommandResult {
        GitCommandResult(
            arguments: ["verify-tag"],
            standardOutput: Data(),
            standardError: Data(standardError.utf8),
            terminationStatus: .exited(1),
            isCancelled: false
        )
    }
}
