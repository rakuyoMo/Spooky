import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteAddressTests

/// 远端地址的主机解析，以及自动获取按 skipFetchAll 与主机挑选远端。
struct RemoteAddressTests {
    /// URL 与 scp 写法取出主机，可带用户名、端口与方括号里的 IPv6；本机路径、`file://`、未知协议与 `<传输>::` 写不出主机。
    @Test(
        "主机解析",
        arguments: [
            ("https://user:secret@github.com:8443/a/b.git", "github.com"),
            ("ssh://git@[2001:db8::1]:22/repo.git", "2001:db8::1"),
            ("git://Host.example/repo", "Host.example"),
            ("git@github.com:a/b.git", "github.com"),
            ("[git@host.example:2222]:repo.git", "host.example"),
            ("[::1]:repo.git", "::1"),
            ("file:///srv/repo.git", nil),
            ("/srv/repo.git", nil),
            ("./dir:name/repo.git", nil),
            ("../repo.git", nil),
            ("foo://host/repo.git", nil),
            ("ext::ssh -p 22 host %S repo", nil),
            (":repo.git", nil),
        ] as [(String, String?)]
    )
    func host(url: String, host: String?) {
        #expect(RemoteAddress.host(in: url) == host)
    }

    /// 本机仓库去掉设了 skipFetchAll、本机路径、`file://`、只有 pushurl 与经 insteadOf 改写成本机路径的远端，保持原顺序；
    /// 服务器仓库只去掉设了 skipFetchAll 的，别名与本机看来无效的路径都留给服务器上的 Git。
    @Test("自动获取挑选远端")
    func autoFetchTargets() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner

        let remotes = [
            ("web", "https://example.invalid/repo.git"),
            ("alias", "build-host:repo.git"),
            ("path", "/srv/repo.git"),
            ("file", "file:///srv/repo.git"),
            ("rewritten", "corp:repo.git"),
            ("skipped", "ssh://example.invalid/repo.git"),
        ]

        for (name, url) in remotes {
            _ = try await runner.run(["config", "--local", "remote.\(name).url", url])
        }

        _ = try await runner.run(["config", "--local", "remote.pushonly.pushurl", "ssh://example.invalid/push.git"])
        _ = try await runner.run(["config", "--local", "remote.skipped.skipFetchAll", "true"])
        _ = try await runner.run(["config", "--local", "url./srv/mirror/.insteadOf", "corp:"])

        let names = remotes.map(\.0) + ["pushonly"]
        let sync = RepositorySync(runner: runner)

        #expect(try await sync.autoFetchTargets(among: names, requiresHost: true) == ["web", "alias"])
        #expect(
            try await sync.autoFetchTargets(among: names, requiresHost: false)
                == ["web", "alias", "path", "file", "rewritten", "pushonly"]
        )

        // 只读出远端地址的 remote 子命令按读取调度
        #expect(RepositoryOperationQueue.isReadOnly(["remote", "get-url", "web"]))
        #expect(!RepositoryOperationQueue.isReadOnly(["remote", "remove", "web"]))
    }
}
