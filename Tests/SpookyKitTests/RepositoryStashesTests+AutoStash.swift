import Foundation
import Testing

@testable import SpookyKit

/// Auto Stash 的三种结局：全部完成、原操作失败、恢复失败；失败时储藏必须保留，原始错误随之带回。
extension RepositoryStashesTests {
    /// 合并被本地改动挡住后，储藏、合并、按暂存区状态恢复依次完成，储藏随后删除。
    @Test("Auto Stash 完成合并并恢复改动")
    func autoStashMerge() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let runner = repository.runner
        let stashes = RepositoryStashes(runner: runner)
        try await commitOnFeature("feature.txt", content: "feature\n", in: repository)

        try write("local\n", to: "tracked x.txt", in: repository)
        _ = try await runner.run(["--literal-pathspecs", "add", "--", "tracked x.txt"])
        try write("new\n", to: "未跟踪.txt", in: repository)

        // 未跟踪文件同样会挡住合并，自动储藏要把它们一起收走
        await #expect(throws: RepositorySyncError.dirtyWorkingCopy) {
            try await RepositorySync(runner: runner).merge("refs/heads/feature")
        }

        try await stashes.stashingLocalChanges(message: "auto", reapply: true) {
            try await RepositorySync(runner: runner).merge("refs/heads/feature")
        }

        #expect(try read("feature.txt", in: repository) == "feature\n")
        let entries = try await runner.status().entries
        #expect(entries.first { $0.path == "tracked x.txt" }?.staged == .modified)
        #expect(entries.contains { $0.path == "未跟踪.txt" && $0.kind == .untracked })
        #expect(try await stashes.list().isEmpty)
    }

    /// 原操作失败时停在失败的状态：储藏保留，错误说明储藏的说明，并带回 Git 的原始错误。
    @Test("Auto Stash 后原操作失败")
    func autoStashOperationFailure() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let runner = repository.runner
        let stashes = RepositoryStashes(runner: runner)
        try await commitOnFeature("tracked *.txt", content: "feature\n", in: repository)
        try write("main\n", to: "tracked *.txt", in: repository)
        _ = try await runner.run(["commit", "-q", "-am", "main change"])
        try write("local\n", to: "tracked x.txt", in: repository)

        do {
            try await stashes.stashingLocalChanges(message: "auto", reapply: true) {
                try await RepositorySync(runner: runner).merge("refs/heads/feature")
            }
            Issue.record("冲突的合并应失败")
        } catch StashError.operationFailed(let stash, let underlying) {
            #expect(stash == "auto")
            #expect((underlying as? GitError)?.exitCode == 1)
        }

        // 冲突留给用户处理，本地改动仍在储藏里，没有被套回冲突中的工作区
        #expect(try await stashes.list().map(\.message) == ["auto"])
        #expect(try await runner.status().entries.contains { $0.kind == .conflicted })
        #expect(try read("tracked x.txt", in: repository) == "base\n")
    }

    /// 原操作完成但恢复失败：HEAD 已更新，储藏保留，工作区不留半套用的改动。
    @Test("Auto Stash 恢复失败后保留储藏")
    func autoStashReapplyFailure() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let runner = repository.runner
        let stashes = RepositoryStashes(runner: runner)
        let feature = try await commitOnFeature("tracked x.txt", content: "feature\n", in: repository)

        // 已暂存的本地改动与合并进来的版本冲突，带暂存区状态的恢复无法完成
        try write("local\n", to: "tracked x.txt", in: repository)
        _ = try await runner.run(["--literal-pathspecs", "add", "--", "tracked x.txt"])

        do {
            try await stashes.stashingLocalChanges(message: "auto", reapply: true) {
                try await RepositorySync(runner: runner).merge("refs/heads/feature")
            }
            Issue.record("冲突的恢复应失败")
        } catch StashError.reapplyFailed(let stash, let underlying) {
            #expect(stash == "auto")
            #expect((underlying as? GitError)?.message.contains("Try without --index") ?? false)
        }

        #expect(try await RepositoryReferences(runner: runner).resolve("HEAD") == feature)
        #expect(try await stashes.list().map(\.message) == ["auto"])
        #expect(try await runner.status().entries.isEmpty)
    }

    /// 取消不包装成储藏错误，交给调用方按取消处理；储藏同样保留。
    @Test("Auto Stash 期间取消")
    func autoStashCancellation() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let stashes = RepositoryStashes(runner: repository.runner)
        try write("local\n", to: "tracked x.txt", in: repository)

        await #expect(throws: CancellationError.self) {
            try await stashes.stashingLocalChanges(message: "auto", reapply: true) {
                throw CancellationError()
            }
        }

        #expect(try await stashes.list().map(\.message) == ["auto"])
    }

    /// 只有列出与查看储藏越过写队列；保存、应用、删除、登记与生成储藏提交都按写操作排队。
    @Test("储藏子命令的读写分类")
    func readOnlyClassification() {
        #expect(RepositoryOperationQueue.isReadOnly(["-c", "log.date=default", "stash", "list", "-z"]))
        #expect(RepositoryOperationQueue.isReadOnly(["stash", "show", "-p", "stash@{0}"]))

        for arguments in [
            ["stash"], ["stash", "push"], ["--literal-pathspecs", "stash", "push", "-u"], ["stash", "apply"],
            ["stash", "pop", "--index"], ["stash", "drop"], ["stash", "store"], ["stash", "create"],
        ] {
            #expect(!RepositoryOperationQueue.isReadOnly(arguments))
        }
    }
}

// MARK: - Auto Stash Helpers

extension RepositoryStashesTests {
    /// 在 feature 分支上提交一个文件后回到 main，返回 feature 的提交。
    @discardableResult
    func commitOnFeature(_ path: String, content: String, in repository: TemporaryRepository) async throws -> String {
        let runner = repository.runner
        _ = try await runner.run(["switch", "-q", "-c", "feature"])
        try write(content, to: path, in: repository)
        _ = try await runner.run(["--literal-pathspecs", "add", "--", path])
        _ = try await runner.run(["commit", "-q", "-m", "feature"])
        _ = try await runner.run(["switch", "-q", "main"])
        return try await RepositoryReferences(runner: runner).resolve("refs/heads/feature")
    }
}
