import Foundation
import Testing

@testable import SpookyKit

/// 断线后的核对读取远端跟踪分支，用来判断中断的获取或推送是否已经改动了它们。
struct RemoteRecoveryReferencesTests {
    /// 每行是引用名、NUL、对象标识；哈希长度随仓库而定，引用名可含中文与特殊字符。
    @Test("远端跟踪分支的解析")
    func parsing() throws {
        let sha1 = String(repeating: "a", count: 40)
        let sha256 = String(repeating: "b", count: 64)
        let output = "refs/remotes/origin/main\u{0}\(sha1)\nrefs/remotes/备份/功能-'$x'\u{0}\(sha256)\n"

        #expect(
            try RemoteRecoverySnapshot.parseReferences(Data(output.utf8)) == [
                "refs/remotes/origin/main": sha1,
                "refs/remotes/备份/功能-'$x'": sha256,
            ]
        )

        #expect(try RemoteRecoverySnapshot.parseReferences(Data()).isEmpty)

        #expect(throws: RepositoryReadError.self) {
            try RemoteRecoverySnapshot.parseReferences(Data("refs/remotes/origin/main \(sha1)\n".utf8))
        }

        #expect(throws: RepositoryReadError.self) {
            try RemoteRecoverySnapshot.parseReferences(Data("refs/remotes/origin/main\u{0}HEAD\n".utf8))
        }
    }

    /// 本机仓库的真实输出与解析一致。
    @Test("读取真实仓库的远端跟踪分支")
    func realOutput() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize(objectFormat: "sha256")

        let runner = fixture.runner
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["update-ref", "refs/remotes/远端/主分支", "HEAD"])

        let output = try await runner.run(["for-each-ref", "--format=%(refname)%00%(objectname)", "refs/remotes"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")

        #expect(try RemoteRecoverySnapshot.parseReferences(output) == ["refs/remotes/远端/主分支": head])
    }
}
