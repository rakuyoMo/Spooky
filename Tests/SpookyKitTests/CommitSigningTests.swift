import Foundation
import Subprocess
import Synchronization
import Testing

@testable import SpookyKit

// MARK: - CommitSigningTests

/// 签名口令只在确实需要时经中继询问，任何失败都以签名类别报告并保留 gpg 或 ssh-keygen 的原始输出。
@Suite(.serialized)
struct CommitSigningTests {
    /// 仓库根目录，用来读取包装器源码。
    private static let package = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// 模拟 gpg 的 loopback 协议：需要口令时在状态输出里索取，并从命令管道读取应答。
    private static let fakeGPG = """
        #!/bin/sh
        command_fd=
        while [ $# -gt 0 ]; do
          case "$1" in
            --command-fd) command_fd=$2; shift ;;
          esac
          shift
        done
        cat > /dev/null
        echo '[GNUPG:] KEY_CONSIDERED 0123ABCD 2' >&2
        if [ -n "$FAKE_PASSPHRASE" ]; then
          echo '[GNUPG:] USERID_HINT 0123ABCD Spooky Test <spooky@example.invalid>' >&2
          echo '[GNUPG:] NEED_PASSPHRASE 0123ABCD 0123ABCD 22 0' >&2
          echo '[GNUPG:] GET_HIDDEN passphrase.enter' >&2
          if [ -z "$command_fd" ] || ! eval "read -r answer <&$command_fd"; then
            echo 'gpg: signing failed: Operation cancelled' >&2
            exit 2
          fi
          if [ "$answer" != "$FAKE_PASSPHRASE" ]; then
            echo '[GNUPG:] BAD_PASSPHRASE 0123ABCD' >&2
            echo 'gpg: signing failed: Bad passphrase' >&2
            exit 2
          fi
        fi
        echo '[GNUPG:] SIG_CREATED D 22 8 00 1 0123ABCD' >&2
        printf '%s\\n' '-----BEGIN PGP SIGNATURE-----' 'fake' '-----END PGP SIGNATURE-----'
        """

    /// 密钥已解锁或没有口令时不弹出询问，提交照常签名。
    @Test("gpg 不需要口令时不询问")
    func gpgWithoutPassphrase() async throws {
        let requests = Mutex<[RemoteCallbackRequest]>([])
        let result = try await Self.commitThroughWrapper(passphrase: "") { request in
            requests.withLock { $0.append(request) }
            return nil
        }

        let asked = requests.withLock { $0 }
        #expect(result.signed)
        #expect(asked.isEmpty)
    }

    /// 需要口令时只询问一次，请求标为签名口令并带上 gpg 给出的密钥提示。
    @Test("gpg 口令经中继应答")
    func gpgPassphraseRelayed() async throws {
        let requests = Mutex<[RemoteCallbackRequest]>([])
        let result = try await Self.commitThroughWrapper(passphrase: "口令 pw") { request in
            requests.withLock { $0.append(request) }
            return "口令 pw"
        }

        let asked = requests.withLock { $0 }
        #expect(result.signed)
        #expect(asked.count == 1)
        let request = try #require(asked.first)
        #expect(request.kind == .signing)
        #expect(request.prompt.contains("Spooky Test <spooky@example.invalid>"))
    }

    /// 取消输入、口令错误和找不到程序都归为签名失败，原始输出保留，提交没有生成。
    @Test("gpg 签名失败保留原始错误")
    func gpgFailures() async throws {
        let cancelled = try await Self.commitThroughWrapper(passphrase: "secret") { _ in nil }
        #expect(cancelled.error?.category == .signingFailed)
        #expect(cancelled.standardError.contains("Operation cancelled"))
        #expect(!cancelled.signed)

        let wrong = try await Self.commitThroughWrapper(passphrase: "secret") { _ in "wrong" }
        #expect(wrong.error?.category == .signingFailed)
        #expect(wrong.standardError.contains("Bad passphrase"))

        let missing = try await Self.commitThroughWrapper(passphrase: "", program: "/nonexistent/gpg") { _ in nil }
        #expect(missing.error?.category == .signingFailed)
        #expect(missing.standardError.contains("cannot exec '/nonexistent/gpg'"))
    }

    /// 本机 SSH 签名经生产路径执行：ssh-keygen 解锁私钥时询问签名口令，不会等待终端输入。
    @Test("本机 SSH 签名口令经中继询问")
    func localSSHSigning() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let keys = try Self.privateDirectory()
        defer { try? FileManager.default.removeItem(at: keys) }
        let key = keys.appending(path: "签名 key")
        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/ssh-keygen",
            processArguments: ["-q", "-t", "ed25519", "-N", "ssh-pw", "-C", "spooky-test", "-f", key.path],
            arguments: ["ssh-keygen"]
        )

        for (name, value) in [("gpg.format", "ssh"), ("user.signingkey", key.path + ".pub"), ("commit.gpgsign", "true")] {
            _ = try await repository.runner.run(["config", "--local", name, value])
        }

        let answer = Mutex("ssh-pw")
        let kinds = Mutex<[RemoteCallbackRequest.Kind]>([])
        var runner = Self.isolatedRunner(repository, extra: [:])
        runner.credentialHandler = { request in
            kinds.withLock { $0.append(request.kind) }
            return answer.withLock { $0 }
        }

        let service = WorkingCopyOperations(runner: runner)
        try Data("one\n".utf8).write(to: repository.directory.appending(path: "a.txt"))
        try await service.stageAll(staged: true)
        try await service.commit(subject: "SSH 签名", body: "")

        let head = String(decoding: try await repository.runner.run(["cat-file", "-p", "HEAD"]), as: UTF8.self)
        #expect(head.contains("BEGIN SSH SIGNATURE"))
        let asked = kinds.withLock { $0 }
        #expect(asked == [.signing])

        // 口令错误时 ssh-keygen 的报错原样保留，草稿对应的暂存改动仍在
        answer.withLock { $0 = "wrong" }
        try Data("two\n".utf8).write(to: repository.directory.appending(path: "a.txt"))
        try await service.stageAll(staged: true)

        let error = try await #require(throws: GitError.self) {
            try await service.commit(subject: "口令错误", body: "")
        }
        #expect(error.category == .signingFailed)
        #expect(String(decoding: error.result.standardError, as: UTF8.self).contains("incorrect passphrase"))
        #expect(try await repository.runner.status().entries.contains(where: \.hasStagedChanges))
    }
}

// MARK: - Helpers

extension CommitSigningTests {
    /// 一次经包装器签名的提交结果。
    private struct SigningResult {
        /// 提交失败时的错误。
        let error: GitError?

        /// HEAD 是否带有签名。
        let signed: Bool

        /// 失败时 Git 转述的 gpg 原始输出。
        var standardError: String {
            error.map { String(decoding: $0.result.standardError, as: UTF8.self) } ?? ""
        }
    }

    /// 在私有临时会话里经包装器的 gpg 入口提交；口令由测试给定的处理器应答。
    ///
    /// - Parameters:
    ///   - passphrase: 模拟 gpg 要求的口令；为空表示密钥不需要口令。
    ///   - program: 仓库配置的 gpg 程序；为 nil 时使用模拟 gpg。
    private static func commitThroughWrapper(
        passphrase: String,
        program: String? = nil,
        handler: @escaping RemoteCallbackHandler
    ) async throws -> SigningResult {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let session = try Self.privateDirectory()
        defer { try? FileManager.default.removeItem(at: session) }

        // 与本机中继相同的会话布局：随机令牌、私有 socket 与按调用名区分模式的包装器入口。
        let relay = try CallbackRelay(path: session.appending(path: "relay.sock").path, host: "test", handler: handler)
        try relay.start()
        defer { relay.stop() }
        let operation = UUID().uuidString.lowercased()
        relay.register(operation)
        defer { relay.unregister(operation) }

        let wrapper = session.appending(path: "callback")
        try FileManager.default.copyItem(
            at: Self.package.appending(path: "Sources/SpookyKit/Resources/spooky-remote.pl"),
            to: wrapper
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: wrapper.path)
        try FileManager.default.createSymbolicLink(atPath: wrapper.path + "-gpg", withDestinationPath: wrapper.path)
        try JSONSerialization.data(withJSONObject: ["token": relay.token])
            .write(to: session.appending(path: "session.json"))

        let gpg = session.appending(path: "fake gpg")
        try Data(Self.fakeGPG.utf8).write(to: gpg)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: gpg.path)
        _ = try await repository.runner.run(["config", "--local", "gpg.program", program ?? gpg.path])
        _ = try await repository.runner.run(["config", "--local", "commit.gpgsign", "true"])

        let runner = Self.isolatedRunner(repository, extra: [
            "SPOOKY_SESSION": session.path,
            "SPOOKY_OPERATION": operation,
            "FAKE_PASSPHRASE": passphrase,
        ])
        try Data("signed\n".utf8).write(to: repository.directory.appending(path: "a.txt"))
        _ = try await runner.run(["add", "a.txt"])

        var failure: GitError?

        do {
            _ = try await runner.run(
                ["-c", "gpg.program=" + wrapper.path + "-gpg", "commit", "-F", "-"],
                input: Data("签名提交\n".utf8)
            )
        } catch let error as GitError {
            failure = error
        }

        let head = try await runner.execute(["cat-file", "-p", "HEAD"], acceptedExitCodes: [0, 128])
        let signed = String(decoding: head.standardOutput, as: UTF8.self).contains("gpgsig -----BEGIN PGP SIGNATURE-----")
        return SigningResult(error: failure, signed: signed)
    }

    /// 与临时仓库相同的隔离环境，另外不接入用户的 SSH agent。
    private static func isolatedRunner(
        _ repository: TemporaryRepository,
        extra: [Environment.Key: String?]
    ) -> GitRunner {
        GitRunner(
            location: .local(path: repository.directory.path),
            executablePath: "/usr/bin/git",
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_PARAMETERS": nil,
                "GIT_CONFIG_COUNT": nil,
                "SSH_AUTH_SOCK": nil,
            ].merging(extra) { _, new in new })
        )
    }

    /// 权限为 0700 的短路径目录，Unix socket 路径不能超过系统上限。
    private static func privateDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: "/tmp/spooky-sign-" + UUID().uuidString.prefix(8).lowercased())
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        return directory
    }
}
