import Foundation
import Synchronization
import Testing

@testable import SpookyKit

/// 服务器提交在 B 上签名，口令经主连接的中继回到 A；仅在显式启用时访问测试专用仓库。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteCommitSigningTests {
    /// B 上的 ssh-keygen 解锁签名私钥时询问一次签名口令；找不到签名程序时保留 B 上的原始错误。
    @Test("服务器 SSH 签名与签名失败", .timeLimit(.minutes(2)))
    func sshSigning() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()
        let kinds = Mutex<[RemoteCallbackRequest.Kind]>([])
        await remote.setCallbackHandler { request in
            kinds.withLock { $0.append(request.kind) }
            return "远端 pw"
        }

        do {
            let key = fixture.root + "/签名 key"
            _ = try await RemoteFixture.raw(["ssh-keygen", "-q", "-t", "ed25519", "-N", "远端 pw", "-f", key])

            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)

            for (name, value) in [("gpg.format", "ssh"), ("user.signingkey", key + ".pub"), ("commit.gpgsign", "true")] {
                _ = try await runner.run(["config", "--local", name, value])
            }

            try await files.write(Data("signed\n".utf8), to: fixture.repository + "/a.txt")
            try await service.stageAll(staged: true)
            try await service.commit(subject: "服务器签名", body: "")

            let head = String(decoding: try await runner.run(["cat-file", "-p", "HEAD"]), as: UTF8.self)
            let asked = kinds.withLock { $0 }
            #expect(head.contains("BEGIN SSH SIGNATURE"))
            #expect(asked == [.signing])

            // B 的非交互 PATH 里找不到签名程序时，签名失败保留 B 上的报错
            _ = try await runner.run(["config", "--local", "gpg.format", "openpgp"])
            _ = try await runner.run(["config", "--local", "gpg.program", "/nonexistent/gpg"])
            try await files.write(Data("again\n".utf8), to: fixture.repository + "/a.txt")
            try await service.stageAll(staged: true)

            let error = try await #require(throws: GitError.self) {
                try await service.commit(subject: "无法签名", body: "")
            }
            #expect(error.category == .signingFailed)
            #expect(String(decoding: error.result.standardError, as: UTF8.self).contains("cannot exec"))

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}
