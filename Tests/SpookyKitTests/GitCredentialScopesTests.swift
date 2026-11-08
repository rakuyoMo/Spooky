import Foundation
import Synchronization
import Testing

@testable import SpookyKit

// MARK: - GitCredentialScopesTests

/// 账号实例与关联远端的 HTTPS 地址只问 Spooky 的凭据助手：用户自己的助手存不走令牌，助手拿得到路径才能按项目找账号。
///
/// 前缀是进程级的全局设置，本组测试串行执行，结束时清空。
@Suite(.serialized)
struct GitCredentialScopesTests {
    /// 作用域内只问 Spooky 的助手，助手拿到路径，它的回答成为凭据；凭据被拒时 Git 向它发 erase，同样带着路径；
    /// 作用域外问仓库配的助手。
    @Test("作用域内外的凭据助手与被拒时的 erase")
    func scopedHelpers() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()

        let user = try Self.helper("user", answer: "username=user\npassword=user-secret", in: fixture)
        let spooky = try Self.helper("spooky", answer: "username=oauth2\npassword=account-token", in: fixture)

        // 仓库自己配的助手，代表用户的 osxkeychain 等
        _ = try await fixture.runner.run([
            "config",
            "--local",
            "credential.helper",
            "!" + GitRunner.shellQuoted(user.path),
        ])

        GitCredentialScopes.current = ["https://example.com/gitlab"]
        defer { GitCredentialScopes.current = [] }

        let options = GitCredentialScopes.options(callback: GitRunner.shellQuoted(spooky.path))

        // 部署路径下的项目在作用域内：只问 Spooky 的助手，输入带着路径
        let inside = try await Self.credential(
            "fill",
            fixture,
            options: options,
            input: "protocol=https\nhost=example.com\npath=gitlab/group/repo.git\n\n"
        )

        #expect(inside.contains("username=oauth2\npassword=account-token"))

        let filled = try String(contentsOf: spooky.log, encoding: .utf8)

        #expect(filled.hasPrefix("credential get\n"))
        #expect(filled.contains("path=gitlab/group/repo.git"))
        #expect(!FileManager.default.fileExists(atPath: user.log.path))

        try FileManager.default.removeItem(at: spooky.log)

        // 凭据被拒时只向作用域内的助手发 erase，用户的助手不会删掉自己存的凭据
        _ = try await Self.credential(
            "reject",
            fixture,
            options: options,
            input: "protocol=https\nhost=example.com\npath=gitlab/group/repo.git\n"
                + "username=oauth2\npassword=account-token\n\n"
        )

        let erased = try String(contentsOf: spooky.log, encoding: .utf8)

        #expect(erased.hasPrefix("credential erase\n"))
        #expect(erased.contains("path=gitlab/group/repo.git"))
        #expect(!FileManager.default.fileExists(atPath: user.log.path))

        try FileManager.default.removeItem(at: spooky.log)

        // 别的主机不在作用域内，仍问仓库配的助手
        let outside = try await Self.credential(
            "fill",
            fixture,
            options: options,
            input: "protocol=https\nhost=other.example\npath=owner/repo.git\n\n"
        )

        #expect(outside.contains("password=user-secret"))
        #expect(!FileManager.default.fileExists(atPath: spooky.log.path))
    }

    /// 前缀含 “=” 或换行时不生成配置，否则 Git 读到无效的键，所有命令都会失败；没有前缀时不加任何配置；
    /// 服务器上的命令先清空 B 上的全部助手，再把作用域内的地址交给包装器。
    @Test("凭据配置：前缀的过滤与服务器命令")
    func options() {
        GitCredentialScopes.current = ["https://example.com/a=b", "https://example.com/\nx", "https://github.com"]
        defer { GitCredentialScopes.current = [] }

        #expect(
            GitCredentialScopes.options(callback: "'/tmp/callback'") == [
                "-c", "credential.https://github.com.helper=",
                "-c", "credential.https://github.com.helper=!'/tmp/callback' credential",
                "-c", "credential.https://github.com.useHttpPath=true",
            ]
        )

        let remote = RemoteConnection.callbackOptions(wrapper: "/home/me/.spooky/bin/spooky-remote")

        #expect(
            Array(remote.prefix(8)) == [
                "-c", "credential.helper=",
                "-c", "credential.https://github.com.helper=",
                "-c", "credential.https://github.com.helper=!'/home/me/.spooky/bin/spooky-remote' credential",
                "-c", "credential.https://github.com.useHttpPath=true",
            ]
        )

        GitCredentialScopes.current = []

        #expect(GitCredentialScopes.options(callback: "'/tmp/callback'").isEmpty)
    }
}

// MARK: - Wrapper

extension GitCredentialScopesTests {
    /// 包装器的 `credential` 入口：get 只把地址交给中继，回答原样成为凭据，凭据里的令牌在输出中被遮住；
    /// A 不回答时包装器什么都不输出，Git 改问 askpass，提示里带着路径；erase 只交地址，Git 带来的密码不离开包装器；store 不发请求。
    @Test("包装器：get 的回答与遮挡、改问 askpass、erase 与 store")
    func wrapper() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        GitCredentialScopes.current = ["https://example.com"]
        defer { GitCredentialScopes.current = [] }

        // get：中继的回答成为凭据，只遮令牌，用户名照常输出
        let requests = Mutex<[RemoteCallbackRequest]>([])
        var answering = try Self.credentialRunner(fixture, command: "fill", fields: "")

        answering.credentialHandler = { request in
            requests.withLock { $0.append(request) }
            return request.kind == .credential ? "username=oauth2\npassword=account-token\n" : nil
        }

        let answered = try await answering.execute(["fetch", "--porcelain"])
        let output = String(decoding: answered.standardOutput, as: UTF8.self)

        #expect(output.contains("username=oauth2\npassword=[REDACTED]"))
        #expect(!output.contains("account-token"))

        let request = try #require(requests.withLock { $0 }.first)

        #expect(requests.withLock { $0.count } == 1)
        #expect(request.kind == .credential)
        #expect(request.prompt == "get")
        #expect(request.content == "https://example.com/owner/repo.git")

        // 中继不回答时 Git 改问 askpass
        let prompts = Mutex<[String]>([])
        var asking = try Self.credentialRunner(fixture, command: "fill", fields: "")

        asking.credentialHandler = { request in
            guard request.kind == .askpass else {
                return nil
            }

            prompts.withLock { $0.append(request.prompt) }
            return request.prompt.hasPrefix("Username") ? "typed-user" : "typed-password"
        }

        let typed = try await asking.execute(["fetch", "--porcelain"])

        #expect(String(decoding: typed.standardOutput, as: UTF8.self).contains("username=typed-user"))
        #expect(prompts.withLock { $0 }.first == "Username for 'https://example.com/owner/repo.git': ")

        // erase 只把地址交给中继；store 不发请求
        let recorded = Mutex<[RemoteCallbackRequest]>([])
        let fields = "username=oauth2\npassword=account-token\n"

        for command in ["reject", "approve"] {
            var runner = try Self.credentialRunner(fixture, command: command, fields: fields)

            runner.credentialHandler = { request in
                recorded.withLock { $0.append(request) }
                return ""
            }

            _ = try await runner.execute(["fetch", "--porcelain"])
        }

        #expect(recorded.withLock { $0 }.map(\.prompt) == ["erase"])
        #expect(recorded.withLock { $0 }.first?.content == "https://example.com/owner/repo.git")
    }
}

// MARK: - Helpers

extension GitCredentialScopesTests {
    /// 写一个记录调用的凭据助手：把参数与输入追加到自己的日志，`get` 时输出给定的回答。
    ///
    /// - Returns: 助手的路径与它的日志；没被调用过时日志不存在。
    private static func helper(
        _ name: String,
        answer: String,
        in fixture: TemporaryRepository
    ) throws -> (path: String, log: URL) {
        let path = fixture.directory.appending(path: "\(name)-helper").path
        let log = fixture.directory.appending(path: "\(name).log")

        let script = """
            #!/bin/sh
            input=$(cat)
            printf '%s\\n%s\\n' "$*" "$input" >> \(GitRunner.shellQuoted(log.path))
            if [ "$2" = get ] || [ "$1" = get ]; then
                printf '%s\\n' \(GitRunner.shellQuoted(answer))
            fi
            """

        try Data(script.utf8).write(to: URL(fileURLWithPath: path))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path)

        return (path, log)
    }

    /// 在隔离的仓库里执行 `git credential <command>`，返回 Git 的输出。
    ///
    /// - Parameters:
    ///   - command: `fill` 或 `reject`。
    ///   - options: 加在 `credential` 之前的配置。
    ///   - input: 交给 Git 的凭据字段。
    private static func credential(
        _ command: String,
        _ fixture: TemporaryRepository,
        options: [String],
        input: String
    ) async throws -> String {
        let output = try await fixture.runner.run(options + ["credential", command], input: Data(input.utf8))
        return String(decoding: output, as: UTF8.self)
    }

    /// 经凭据中继执行的临时 git 程序：去掉最后的 `fetch --porcelain`，带着同样的 `-C` 与 `-c` 配置向真实的 Git 执行一次
    /// `credential <command>`。
    ///
    /// - Parameters:
    ///   - command: `fill`、`reject` 或 `approve`。
    ///   - fields: 地址之外交给 Git 的字段，如用户名与密码。
    private static func credentialRunner(
        _ fixture: TemporaryRepository,
        command: String,
        fields: String
    ) throws -> GitRunner {
        let executable = fixture.directory.appending(path: "git-credential-\(command)").path

        let script = """
            #!/bin/sh
            count=$(($# - 2))
            index=0
            for argument do
                shift
                index=$((index + 1))
                if [ "$index" -le "$count" ]; then set -- "$@" "$argument"; fi
            done
            printf 'protocol=https\\nhost=example.com\\npath=owner/repo.git\\n%s\\n' \(GitRunner.shellQuoted(fields)) \\
                | /usr/bin/git "$@" credential \(command)
            """

        try Data(script.utf8).write(to: URL(fileURLWithPath: executable))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable)

        return fixture.runner(at: fixture.directory.path, executable: executable)
    }
}
