import Foundation
import Testing

@testable import SpookyKit

// MARK: - File Pick

extension RepositoryRewriteTests {
    /// 只把提交里一个文件的改动套到工作区：同一提交里的其它文件、暂存区与 HEAD 都不动。
    @Test("摘取提交里的单个文件")
    func pickSingleFile() async throws {
        let (repository, commits) = try await makeRepository(["基础"])
        defer { repository.remove() }

        let picked = try await sideCommit(in: repository, from: commits[0]) {
            try write("基础\n侧边\n", to: file(0), in: repository)
            try write("其它\n", to: "其它 [x].txt", in: repository)
        }

        try await RepositoryRewrite(runner: repository.runner)
            .cherryPick(path: file(0), originalPath: nil, from: picked)

        #expect(try read(file(0), in: repository) == "基础\n侧边\n")
        #expect(!exists("其它 [x].txt", in: repository))

        let status = try await repository.runner.status()
        #expect(status.branch.oid == commits[0])
        #expect(!status.entries.contains { $0.hasStagedChanges })
    }

    /// 重命名的文件连同原路径一起套用：原路径的文件删除，新路径带着改动出现。
    @Test("摘取重命名的文件")
    func pickRenamedFile() async throws {
        let (repository, commits) = try await makeRepository(["基础"])
        defer { repository.remove() }

        let target = "新 目录/名字 [1] *.txt"

        let picked = try await sideCommit(in: repository, from: commits[0]) {
            try FileManager.default.createDirectory(
                at: repository.directory.appending(path: "新 目录"),
                withIntermediateDirectories: true
            )
            _ = try await repository.runner.run(["mv", "--", file(0), target])
            try write("基础\n改名后\n", to: target, in: repository)
        }

        try await RepositoryRewrite(runner: repository.runner)
            .cherryPick(path: target, originalPath: file(0), from: picked)

        #expect(!exists(file(0), in: repository))
        #expect(try read(target, in: repository) == "基础\n改名后\n")
    }

    /// 根提交没有父提交，取的是整个文件。
    @Test("摘取根提交里的文件")
    func pickFromRootCommit() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        _ = try await repository.runner.run(["rm", "-q", "--", file(0)])
        _ = try await repository.runner.run(["commit", "-q", "-m", "删除"])

        try await RepositoryRewrite(runner: repository.runner)
            .cherryPick(path: file(0), originalPath: nil, from: commits[0])

        #expect(try read(file(0), in: repository) == "一\n")
    }

    /// 工作区的同一处已经改过时套用失败，工作区保持原样；不是完整哈希的版本在执行前被拒绝。
    @Test("单个文件套用不上与非法版本")
    func pickConflict() async throws {
        let (repository, commits) = try await makeRepository(["基础"])
        defer { repository.remove() }

        let picked = try await sideCommit(in: repository, from: commits[0]) {
            try write("侧边\n", to: file(0), in: repository)
        }

        try write("本地\n", to: file(0), in: repository)
        let rewrite = RepositoryRewrite(runner: repository.runner)

        await #expect(throws: GitError.self) {
            try await rewrite.cherryPick(path: file(0), originalPath: nil, from: picked)
        }

        #expect(try read(file(0), in: repository) == "本地\n")

        await #expect(throws: RepositoryReadError.invalidQuery) {
            try await rewrite.cherryPick(path: file(0), originalPath: nil, from: "HEAD")
        }
    }
}

// MARK: - Helpers

extension RepositoryRewriteTests {
    /// 从指定提交开一个侧分支，做完改动后提交一次，再回到 main；返回这个提交。
    private func sideCommit(
        in repository: TemporaryRepository,
        from start: String,
        changes: () async throws -> Void
    ) async throws -> String {
        _ = try await repository.runner.run(["switch", "-q", "-c", "side", start])
        try await changes()
        _ = try await repository.runner.run(["add", "--all"])
        _ = try await repository.runner.run(["commit", "-q", "-m", "侧边"])

        let commit = try await head(in: repository)
        _ = try await repository.runner.run(["switch", "-q", "main"])
        return commit
    }
}
