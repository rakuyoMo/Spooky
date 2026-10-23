import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteWorkingCopyFilesTests

/// 服务器 M6 工作区文件操作仅在显式启用时访问测试专用仓库：规则文件经 SFTP 读写，删除在 B 上永久生效，补丁经标准输入交给 B 上的 git apply。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteWorkingCopyFilesTests {
    /// 忽略与排除规则写进 B 上的文件，info 目录不存在时经 SFTP 创建；停止跟踪、移动与删除都在 B 上执行。
    @Test("服务器忽略、排除、停止跟踪、移动与删除", .timeLimit(.minutes(2)))
    func fileOperations() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let special = "文件 ' [*]?.txt"

            for name in [special, "keep.txt", "tracked.txt"] {
                try await files.write(Data("\(name)\n".utf8), to: fixture.repository + "/" + name)
            }

            try await service.stageAll(staged: true)
            try await service.commit(subject: "base", body: "")

            // 只匹配所选文件本身的规则写进 .gitignore，排除规则写进新建的 info/exclude
            try await files.write(Data("new\n".utf8), to: fixture.repository + "/new.txt")
            try await files.write(Data("o\n".utf8), to: fixture.repository + "/out.o")
            try await service.addIgnorePatterns(
                WorkingCopyOperations.ignorePatterns(for: ["new.txt"], scope: .items),
                to: .gitignore
            )
            try await service.addIgnorePatterns(["*.o"], to: .exclude)
            #expect(Set(try await runner.ignoredFiles()) == ["new.txt", "out.o"])

            // 停止跟踪后文件留在 B 上的工作区
            try await service.untrack(["keep.txt"])
            let entries = try await runner.status().entries
            #expect(entries.contains { $0.path == "keep.txt" && $0.staged == .deleted })
            #expect(entries.contains { $0.path == "keep.txt" && $0.kind == .untracked })

            // 已跟踪文件经 git mv 移动；未跟踪文件经 SFTP 移动，目标已存在时拒绝
            try await service.move(special, to: "renamed.txt", tracked: true)
            await #expect(throws: WorkingCopyFileError.destinationExists) {
                try await service.move("keep.txt", to: "tracked.txt", tracked: false)
            }
            try await service.move("keep.txt", to: "moved.txt", tracked: false)

            // 服务器上的删除是永久删除，没有可找回的位置
            #expect(try await service.delete(["moved.txt", "out.o"]).isEmpty)
            let removed = [fixture.repository + "/moved.txt", fixture.repository + "/out.o"]
            #expect(try await files.read(removed).isEmpty)

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }

    /// A 上的补丁内容经标准输入交给 B 上的 git apply；B 上的文件已被改动时前像核对拒绝应用。
    @Test("服务器应用补丁并核对前像", .timeLimit(.minutes(2)))
    func applyPatch() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let path = fixture.repository + "/lines [*].txt"
            let original = Data("1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n".utf8)

            try await files.write(original, to: path)
            try await service.stageAll(staged: true)
            try await service.commit(subject: "lines", body: "")

            try await files.write(Data("1\nTWO\n3\n4\n5\n6\n7\n8\n9\n10\n".utf8), to: path)
            let patch = try await runner.run(["diff", "--full-index"])
            try await files.write(original, to: path)

            try await service.applyPatch(patch)
            #expect(try await files.read([path])[path] == Data("1\nTWO\n3\n4\n5\n6\n7\n8\n9\n10\n".utf8))

            let edited = Data("1\n2\n3\n4\n5\n6\n7\n8\n9\nTEN\n".utf8)
            try await files.write(edited, to: path)
            await #expect(throws: WorkingCopyFileError.patchPreimageMismatch(["lines [*].txt"])) {
                try await service.applyPatch(patch)
            }
            #expect(try await files.read([path])[path] == edited)

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
