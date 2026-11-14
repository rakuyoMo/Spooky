import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Conflict Files

extension RepositorySessionTests {
    /// AA、UU、UD、DU 四种冲突文件都能打开与恢复到指定版本，不能移动，只有两侧都是文件的才能用合并工具；
    /// 恢复到含这个路径的版本后冲突结束，所选版本里没有它时报告失败、冲突保留。
    @Test("冲突文件的打开、移动、合并工具与恢复到指定版本")
    func conflictFileActions() async throws {
        let (session, directory, runner) = try await openOperationRepository { directory, runner in
            try await commitFiles(["uu": "base", "ud": "base", "du": "base"], message: "base", in: directory, runner: runner)
            _ = try await runner.run(["checkout", "-q", "-b", "side"])
            _ = try await runner.run(["rm", "-q", "ud"])
            try await commitFiles(["uu": "side", "du": "side", "aa": "side"], message: "side", in: directory, runner: runner)
            _ = try await runner.run(["checkout", "-q", "main"])
            _ = try await runner.run(["rm", "-q", "du"])
            try await commitFiles(["uu": "main", "ud": "main", "aa": "main"], message: "main", in: directory, runner: runner)
        }

        defer { closeOperationRepository(session, directory) }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }

        _ = try? await runner.run(["merge", "-q", "side"])
        await reload(session) { session.context?.operation == .merge }

        let conflicts = Dictionary(
            uniqueKeysWithValues: (session.status?.entries ?? []).filter { $0.kind == .conflicted }.map { ($0.path, $0) }
        )

        #expect(conflicts.keys.sorted() == ["aa", "du", "ud", "uu"])

        // 四种冲突都能打开与恢复，不能移动；合并工具只给两侧都是文件的冲突
        for (path, entry) in conflicts {
            #expect(session.canOpen([entry]), "\(path)")
            #expect(session.canRevert([entry]), "\(path)")
            #expect(!session.canMove([entry]), "\(path)")
            #expect(session.canOpenMergeTool([entry]) == ["aa", "uu"].contains(path), "\(path)")
        }

        let head = try #require(session.status?.branch.oid)

        // 恢复到 HEAD：HEAD 里有 uu，冲突结束
        session.revert([try #require(conflicts["uu"])], to: head)
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(failures.isEmpty)
        #expect(try !#require(session.status).entries.contains { $0.path == "uu" })
        #expect(try String(contentsOf: directory.appending(path: "uu"), encoding: .utf8) == "main\n")

        // HEAD 里没有 du：报告失败，冲突保留
        session.revert([try #require(conflicts["du"])], to: head)
        await session.writeTask?.value
        await session.waitForRefresh()

        #expect(failures.count == 1)
        #expect(session.status?.entries.first { $0.path == "du" }?.kind == .conflicted)
    }
}
