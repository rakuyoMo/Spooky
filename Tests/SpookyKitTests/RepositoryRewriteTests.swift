import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryRewriteTests

/// 反转、摘取、重置、检出版本与变基到别处在真实 Git 上的结果；路径含空格、中文、引号与通配符。
struct RepositoryRewriteTests {
    /// 反转一个提交会新增一个抵消它的提交，原提交仍在历史里；再摘取原提交又把改动带回来。SHA-1 与 SHA-256 仓库结果相同。
    @Test("反转单个提交再摘取回来", arguments: ["sha1", "sha256"])
    func revertSingle(objectFormat: String) async throws {
        let (repository, commits) = try await makeRepository(["一", "二"], objectFormat: objectFormat)
        defer { repository.remove() }

        let rewrite = RepositoryRewrite(runner: repository.runner)
        try await rewrite.revert([commits[1]], options: PickOptions())

        #expect(try await subjects(in: repository) == ["Revert \"二\"", "二", "一"])
        #expect(!exists(file(1), in: repository))

        try await rewrite.cherryPick([commits[1]], options: PickOptions())
        #expect(exists(file(1), in: repository))
    }

    /// 不直接提交时，多个提交的反转只留在暂存区，HEAD 不动。
    @Test("反转多个提交但不提交")
    func revertWithoutCommit() async throws {
        let (repository, commits) = try await makeRepository(["一", "二", "三"])
        defer { repository.remove() }

        var options = PickOptions()
        options.commit = false
        try await RepositoryRewrite(runner: repository.runner).revert([commits[2], commits[1]], options: options)

        let status = try await repository.runner.status()
        #expect(status.branch.oid == commits[2])
        #expect(Set(status.entries.filter(\.hasStagedChanges).map(\.path)) == [file(1), file(2)])
    }

    /// 多个提交按给定顺序摘取到当前分支，标题与原提交相同。
    @Test("按顺序摘取多个提交")
    func cherryPickMany() async throws {
        let (repository, commits) = try await makeRepository(["基础"])
        defer { repository.remove() }

        let picked = try await sideBranch(["甲 'quote'", "乙 $HOME"], from: commits[0], in: repository)
        try await RepositoryRewrite(runner: repository.runner).cherryPick(picked, options: PickOptions())

        #expect(try await subjects(in: repository) == ["乙 $HOME", "甲 'quote'", "基础"])
    }

    /// 合并提交只能指定主线摘取；主线 1 取得被合并分支带来的改动。
    @Test("按主线摘取合并提交")
    func cherryPickMergeCommit() async throws {
        let (repository, commits) = try await makeRepository(["基础"])
        defer { repository.remove() }

        _ = try await sideBranch(["支线"], from: commits[0], in: repository)
        _ = try await repository.runner.run(["switch", "-q", "-c", "合并", commits[0]])
        _ = try await repository.runner.run(["merge", "-q", "--no-ff", "--no-edit", "side"])
        let merge = try await head(in: repository)
        _ = try await repository.runner.run(["switch", "-q", "main"])

        await #expect(throws: GitError.self) {
            try await RepositoryRewrite(runner: repository.runner).cherryPick([merge], options: PickOptions())
        }

        var options = PickOptions()
        options.mainline = 1
        try await RepositoryRewrite(runner: repository.runner).cherryPick([merge], options: options)

        #expect(exists("side 1.txt", in: repository))
    }

    /// 摘取冲突时停在进行中状态；中止回到摘取前，解决后继续生成提交。
    @Test("摘取冲突后中止与继续")
    func cherryPickConflict() async throws {
        let (repository, commits) = try await makeRepository(["基础"])
        defer { repository.remove() }

        let picked = try await sideBranch(["改同一行"], from: commits[0], in: repository, file: file(0))
        try write("本地\n", to: file(0), in: repository)
        _ = try await repository.runner.run(["commit", "-q", "-am", "本地改动"])
        let before = try await head(in: repository)
        let rewrite = RepositoryRewrite(runner: repository.runner)
        let operations = WorkingCopyOperations(runner: repository.runner)

        await #expect(throws: GitError.self) { try await rewrite.cherryPick(picked, options: PickOptions()) }
        #expect(try await operations.context(head: before).operation == .cherryPick)

        try await operations.finish(.cherryPick, action: "abort")
        #expect(try await head(in: repository) == before)

        await #expect(throws: GitError.self) { try await rewrite.cherryPick(picked, options: PickOptions()) }
        try write("解决\n", to: file(0), in: repository)
        _ = try await repository.runner.run(["add", "--", file(0)])
        try await operations.finish(.cherryPick, action: "continue")

        #expect(try await subjects(in: repository).first == "改同一行")
        #expect(try await operations.context(head: try await head(in: repository)).operation == nil)
    }

    /// 本地改动会被反转覆盖时，失败归为本地改动，供自动储藏询问。
    @Test("反转被本地改动挡住")
    func revertBlockedByLocalChanges() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        try write("本地\n", to: file(1), in: repository)

        let error = await #expect(throws: GitError.self) {
            try await RepositoryRewrite(runner: repository.runner).revert([commits[1]], options: PickOptions())
        }

        #expect(error?.category == .localChanges)
    }
}

// MARK: - Helpers

extension RepositoryRewriteTests {
    /// 第 n 个提交写入的文件名，含空格、中文、引号与通配符。
    func file(_ index: Int) -> String {
        "文件 \(index) \"q\" *.txt"
    }

    /// 在 main 上依次提交，第 n 个提交新增 ``file(_:)``；返回从旧到新的提交哈希。
    func makeRepository(
        _ subjects: [String],
        objectFormat: String = "sha1"
    ) async throws -> (TemporaryRepository, [String]) {
        let repository = try TemporaryRepository()
        try await repository.initialize(objectFormat: objectFormat)
        var commits: [String] = []

        for (index, subject) in subjects.enumerated() {
            try write("\(subject)\n", to: file(index), in: repository)
            _ = try await repository.runner.run(["add", "--all"])
            _ = try await repository.runner.run(["commit", "-q", "-m", subject])
            commits.append(try await head(in: repository))
        }

        return (repository, commits)
    }

    /// 从指定提交开出 side 分支并依次提交，回到 main；返回 side 上从旧到新的提交。
    func sideBranch(
        _ subjects: [String],
        from start: String,
        in repository: TemporaryRepository,
        file name: String? = nil
    ) async throws -> [String] {
        _ = try await repository.runner.run(["switch", "-q", "-c", "side", start])
        var commits: [String] = []

        for (index, subject) in subjects.enumerated() {
            try write("\(subject)\n", to: name ?? "side \(index + 1).txt", in: repository)
            _ = try await repository.runner.run(["add", "--all"])
            _ = try await repository.runner.run(["commit", "-q", "-m", subject])
            commits.append(try await head(in: repository))
        }

        _ = try await repository.runner.run(["switch", "-q", "main"])
        return commits
    }

    /// HEAD 所在的提交。
    func head(in repository: TemporaryRepository) async throws -> String {
        try await RepositoryRewrite(runner: repository.runner).resolve("HEAD")
    }

    /// 当前分支从新到旧的提交标题。
    func subjects(in repository: TemporaryRepository) async throws -> [String] {
        let output = try await repository.runner.run(["log", "-z", "--format=%s"])
        return String(decoding: output, as: UTF8.self).split(separator: "\0").map(String.init)
    }

    /// 写入仓库内的文件。
    func write(_ content: String, to path: String, in repository: TemporaryRepository) throws {
        try Data(content.utf8).write(to: repository.directory.appending(path: path))
    }

    /// 读取仓库内的文件。
    func read(_ path: String, in repository: TemporaryRepository) throws -> String {
        String(decoding: try Data(contentsOf: repository.directory.appending(path: path)), as: UTF8.self)
    }

    /// 仓库内的文件是否存在。
    func exists(_ path: String, in repository: TemporaryRepository) -> Bool {
        FileManager.default.fileExists(atPath: repository.directory.appending(path: path).path)
    }
}
