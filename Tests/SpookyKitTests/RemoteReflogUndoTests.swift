import Foundation
import Testing

@testable import SpookyKit

/// 服务器 Reflog 与撤销验收：记录在 B 上读取，快照建在 B 上、只把哈希留在本机，恢复也在 B 上执行；仅在显式启用时访问测试专用仓库。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteReflogUndoTests {
    /// HEAD 与分支的记录分页读取、按说明搜索，分支按读取时的位置核对后移回某条记录。
    @Test("服务器 Reflog 分页、搜索与恢复分支", .timeLimit(.minutes(2)))
    func reflog() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let files = RepositoryFiles(runner: runner)
            let reflog = RepositoryReflog(runner: runner)
            let path = fixture.repository + "/文件 [*].txt"

            try await files.write(Data("base\n".utf8), to: path)
            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["commit", "-q", "-m", "root"])
            _ = try await runner.run(["checkout", "-q", "-b", "功能/分支"])
            try await files.write(Data("feature\n".utf8), to: path)
            _ = try await runner.run(["commit", "-q", "-a", "-m", "功能 [x] *"])
            _ = try await runner.run(["checkout", "-q", "-"])

            let first = try await reflog.page(of: "HEAD", limit: 2)
            #expect(first.entries.map(\.command) == ["checkout", "commit"])
            #expect(first.hasMore)

            let moving = try await reflog.page(of: "HEAD", matching: "MOVING FROM")
            #expect(moving.entries.count == 2)

            let branch = try await reflog.page(of: "refs/heads/功能/分支").entries
            try await reflog.restore("refs/heads/功能/分支", to: branch[1].commit.id, expected: branch[0].commit.id)
            #expect(try await reflog.page(of: "refs/heads/功能/分支").entries.first?.commit.id == branch[1].commit.id)

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 提交与带未跟踪文件的储藏在服务器上撤销后回到记录的状态，重做后回到操作后；操作后又被改动时拒绝。
    @Test("服务器撤销与重做", .timeLimit(.minutes(3)))
    func undo() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let files = RepositoryFiles(runner: runner)
            let undo = RepositoryUndo(runner: runner)
            let tracked = fixture.repository + "/文件 [*].txt"
            let untracked = fixture.repository + "/新 [1].txt"

            try await files.write(Data("base\n".utf8), to: tracked)
            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["commit", "-q", "-m", "root"])
            try await files.write(Data("staged\n".utf8), to: tracked)
            _ = try await runner.run(["add", "--all"])
            try await files.write(Data("untracked\n".utf8), to: untracked)

            for operation in [["commit", "-q", "-m", "next"], ["stash", "push", "-q", "-u"]] {
                let before = try await undo.capture()
                _ = try await runner.run(operation)
                let after = try await undo.capture()

                try await undo.restore(before, expecting: after, message: "undo")
                #expect(try await undo.capture() == before)

                try await undo.restore(after, expecting: before, message: "redo")
                #expect(try await undo.capture() == after)

                try await undo.restore(before, expecting: after, message: "undo")
            }

            // 操作之后又在服务器上改动了仓库
            let before = try await undo.capture()
            _ = try await runner.run(["branch", "topic"])
            let after = try await undo.capture()
            _ = try await runner.run(["branch", "outside"])

            await #expect(throws: RepositoryUndoError.repositoryChanged) {
                try await undo.restore(before, expecting: after, message: "undo")
            }

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
