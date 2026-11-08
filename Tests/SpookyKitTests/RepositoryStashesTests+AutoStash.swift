import Foundation
import Testing

@testable import SpookyKit

/// Auto Stash 的结局：全部完成、原操作失败、原操作停在冲突上、恢复失败、取消；没有全部完成时储藏必须保留，原始错误随之带回。
extension RepositoryStashesTests {
    /// 合并被本地改动挡住后，储藏、合并、按暂存区状态恢复依次完成，储藏随后删除；
    /// 取消不包装成储藏错误，交给调用方按取消处理，储藏保留；不恢复时操作完成后储藏保留，改动不回到工作区。
    @Test("Auto Stash 完成合并并恢复改动，取消或不恢复时保留储藏")
    func autoStashMerge() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }

        let runner = repository.runner
        let stashes = RepositoryStashes(runner: runner)
        try await commitOnFeature("feature.txt", content: "feature\n", in: repository)

        try write("local\n", to: "tracked x.txt", in: repository)
        _ = try await runner.run(["--literal-pathspecs", "add", "--", "tracked x.txt"])
        try write("new\n", to: "未跟踪.txt", in: repository)

        // 已暂存的改动挡住合并，自动储藏把未跟踪文件也一起收走
        await #expect(throws: RepositorySyncError.dirtyWorkingCopy(rebase: false)) {
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

        // 储藏之后原操作被取消
        await #expect(throws: CancellationError.self) {
            try await stashes.stashingLocalChanges(message: "cancelled", reapply: true) {
                throw CancellationError()
            }
        }

        #expect(try await stashes.list().map(\.message) == ["cancelled"])

        // 不恢复：已经合并过的分支再合并一次照常完成，储藏留着
        try write("kept\n", to: "tracked x.txt", in: repository)

        try await stashes.stashingLocalChanges(message: "kept", reapply: false) {
            try await RepositorySync(runner: runner).merge("refs/heads/feature")
        }

        #expect(try await stashes.list().map(\.message) == ["kept", "cancelled"])
        #expect(try read("tracked x.txt", in: repository) == "base\n")
    }

    /// 原操作失败或停在冲突上时都不恢复：储藏保留，错误说明储藏的去向，失败时带回 Git 的原始错误，冲突留在工作区。
    @Test("Auto Stash 后原操作失败或停在冲突上")
    func autoStashOperationConflicts() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }

        let runner = repository.runner
        let stashes = RepositoryStashes(runner: runner)

        // main 与 feature 改了同一个文件，另有本地改动需要先储藏
        try await commitOnFeature("tracked *.txt", content: "feature\n", in: repository)
        try write("main\n", to: "tracked *.txt", in: repository)
        _ = try await runner.run(["commit", "-q", "-am", "main change"])
        try write("local\n", to: "tracked x.txt", in: repository)

        // 拉取里的合并把冲突当作失败抛出
        do {
            try await stashes.stashingLocalChanges(message: "failed", reapply: true) {
                try await RepositorySync(runner: runner)
                    .performMerge("refs/heads/feature", options: MergeOptions(), onOutput: nil)
            }

            Issue.record("冲突的合并应失败")
        } catch StashError.operationFailed(let stash, let underlying) {
            #expect(stash == "failed")
            #expect((underlying as? GitError)?.exitCode == 1)
        }

        try await expectStashKept(["failed"], in: repository)

        // 放弃这次合并，同样的本地改动再经停在冲突上的合并储藏一次
        _ = try await runner.run(["merge", "--abort"])
        try write("local\n", to: "tracked x.txt", in: repository)

        do {
            try await stashes.stashingLocalChanges(message: "auto", reapply: true) {
                let outcome = try await RepositorySync(runner: runner)
                    .merge("refs/heads/feature")

                #expect(outcome == .conflicts)
            }

            Issue.record("停在冲突上的合并不应恢复储藏")
        } catch StashError.operationConflicts(let stash) {
            #expect(stash == "auto")
        }

        try await expectStashKept(["auto", "failed"], in: repository)
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
}

// MARK: - Auto Stash Helpers

extension RepositoryStashesTests {
    /// 在 feature 分支上提交一个文件后回到 main，返回 feature 的提交。
    @discardableResult
    func commitOnFeature(
        _ path: String,
        content: String,
        in repository: TemporaryRepository
    ) async throws -> String {
        let runner = repository.runner

        _ = try await runner.run(["switch", "-q", "-c", "feature"])
        try write(content, to: path, in: repository)
        _ = try await runner.run(["--literal-pathspecs", "add", "--", path])
        _ = try await runner.run(["commit", "-q", "-m", "feature"])
        _ = try await runner.run(["switch", "-q", "main"])

        return try await RepositoryReferences(runner: runner).resolve("refs/heads/feature")
    }

    /// 冲突留给用户处理：储藏列表是给定的说明，冲突在工作区，本地改动没有被套回冲突中的工作区。
    private func expectStashKept(_ messages: [String], in repository: TemporaryRepository) async throws {
        #expect(try await RepositoryStashes(runner: repository.runner).list().map(\.message) == messages)
        #expect(try await repository.runner.status().entries.contains { $0.kind == .conflicted })
        #expect(try read("tracked x.txt", in: repository) == "base\n")
    }
}
