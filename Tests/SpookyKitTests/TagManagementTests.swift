import Foundation
import Subprocess
import Synchronization
import Testing

@testable import SpookyKit

// MARK: - TagManagementTests

/// 标签的新建、签名、推送与删除；远端是测试目录里的裸仓库，SHA-1 与 SHA-256 仓库都要通过。
struct TagManagementTests {
    /// 没有说明时是轻量标签，有说明时是附注标签，说明里以 “#” 开头的行原样保留；重名、非法名字与签名缺说明都被拒绝。
    @Test("轻量标签与附注标签", arguments: ["sha1", "sha256"])
    func createTags(objectFormat: String) async throws {
        let (fixture, _) = try await BranchManagementTests.repository(objectFormat: objectFormat)
        defer { fixture.remove() }

        let runner = fixture.runner
        let tags = RepositoryTags(runner: runner)

        try await tags.create(name: "v1.0", revision: "HEAD", message: " \n", sign: false)
        #expect(try await Self.text(["cat-file", "-t", "refs/tags/v1.0"], runner) == "commit")

        try await tags.create(name: "发布/v2", revision: "refs/heads/main", message: "# 第一行\n\n说明", sign: false)
        #expect(try await Self.text(["cat-file", "-t", "refs/tags/发布/v2"], runner) == "tag")
        #expect(
            try await Self.text(["for-each-ref", "--format=%(contents)", "refs/tags/发布/v2"], runner)
                == "# 第一行\n\n说明"
        )

        await #expect(throws: GitError.self) {
            try await tags.create(name: "v1.0", revision: "HEAD", message: "", sign: false)
        }
        await #expect(throws: ReferenceError.self) {
            try await tags.create(name: "-v3", revision: "HEAD", message: "", sign: false)
        }
        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await tags.create(name: "v3", revision: "HEAD", message: "  ", sign: true)
        }
        await #expect(throws: GitError.self) {
            try await tags.create(name: "v3", revision: "no-such-revision", message: "", sign: false)
        }
    }

    /// SSH 签名经本机生产路径执行：私钥口令经回调询问；选定的密钥连同签名格式一起生效，不依赖仓库的 gpg.format。
    @Test("SSH 签名标签")
    func sshSignedTag() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        _ = try await fixture.runner.run(["commit", "--allow-empty", "-m", "root"])

        let keys = URL(fileURLWithPath: "/tmp/spooky-tag-" + UUID().uuidString.prefix(8).lowercased())
        try FileManager.default.createDirectory(
            at: keys,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: keys) }

        let locked = keys.appending(path: "标签 key")
        let open = keys.appending(path: "open")

        for (key, passphrase) in [(locked, "tag-pw"), (open, "")] {
            _ = try await CommandExecutor.execute(
                executable: "/usr/bin/ssh-keygen",
                processArguments: ["-q", "-t", "ed25519", "-N", passphrase, "-C", "spooky-test", "-f", key.path],
                arguments: ["ssh-keygen"]
            )
        }

        _ = try await fixture.runner.run(["config", "--local", "gpg.format", "ssh"])
        _ = try await fixture.runner.run(["config", "--local", "user.signingkey", locked.path + ".pub"])

        // 与临时仓库相同的隔离环境，另外不接入用户的 SSH agent，口令只能经回调取得
        let kinds = Mutex<[RemoteCallbackRequest.Kind]>([])
        var runner = GitRunner(
            location: .local(path: fixture.directory.path),
            executablePath: "/usr/bin/git",
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_PARAMETERS": nil,
                "GIT_CONFIG_COUNT": nil,
                "SSH_AUTH_SOCK": nil,
            ])
        )

        runner.credentialHandler = { request in
            kinds.withLock { $0.append(request.kind) }
            return "tag-pw"
        }

        let tags = RepositoryTags(runner: runner)
        try await tags.create(name: "signed", revision: "HEAD", message: "签名的标签", sign: true)
        #expect(try await Self.text(["cat-file", "-p", "refs/tags/signed"], runner).contains("BEGIN SSH SIGNATURE"))
        #expect(kinds.withLock { $0 } == [.signing])

        // 仓库改回 OpenPGP 也不影响：选定的 SSH 密钥带上自己的签名格式
        _ = try await fixture.runner.run(["config", "--local", "gpg.format", "openpgp"])
        try await tags.create(name: "chosen", revision: "HEAD", message: "选定密钥", sign: true, signingKey: open.path + ".pub")
        #expect(try await Self.text(["cat-file", "-p", "refs/tags/chosen"], runner).contains("BEGIN SSH SIGNATURE"))
    }

    /// 发布一个标签、推送全部标签、删除本地标签与远端标签。
    @Test("推送与删除本地、远端标签", arguments: ["sha1", "sha256"])
    func pushAndDelete(objectFormat: String) async throws {
        let (fixture, bare) = try await BranchManagementTests.repository(objectFormat: objectFormat)
        defer { fixture.remove() }

        let runner = fixture.runner
        let remote = fixture.runner(at: bare)
        let tags = RepositoryTags(runner: runner)
        try await tags.create(name: "v1", revision: "HEAD", message: "", sign: false)
        try await tags.create(name: "v2/候选", revision: "HEAD", message: "说明", sign: false)

        try await tags.publish("v1", to: "origin", skipHooks: true)
        #expect(try await Self.text(["for-each-ref", "--format=%(refname)", "refs/tags"], remote) == "refs/tags/v1")

        try await tags.pushAll(to: "origin")
        #expect(
            try await Self.text(["for-each-ref", "--format=%(refname)", "refs/tags"], remote)
                == "refs/tags/v1\nrefs/tags/v2/候选"
        )

        try await tags.delete(["v1", "v2/候选"])
        #expect(try await Self.text(["for-each-ref", "refs/tags"], runner).isEmpty)

        try await tags.deleteRemote(["v2/候选"], on: "origin")
        #expect(try await Self.text(["for-each-ref", "--format=%(refname)", "refs/tags"], remote) == "refs/tags/v1")

        await #expect(throws: ReferenceError.self) {
            try await tags.pushAll(to: "-origin")
        }
        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await tags.delete([])
        }
    }
}

// MARK: - Helpers

extension TagManagementTests {
    /// 命令输出去掉末尾换行后的文本。
    private static func text(_ arguments: [String], _ runner: GitRunner) async throws -> String {
        String(decoding: try await runner.run(arguments), as: UTF8.self).trimmingCharacters(in: .newlines)
    }
}
