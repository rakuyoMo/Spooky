import Foundation
import Testing

@testable import SpookyKit

// MARK: - Amend

/// 修补旧提交停在目标的 edit 步：HEAD 分离到目标，索引与工作区不撤回到父提交；本地改动由用户决定是否先储藏。
extension RepositoryRewriteTests {
    /// 干净工作区直接停到目标本身；暂存的修补由结束编辑并进目标，后面的提交照原样重放。
    @Test("干净工作区停到目标并结束编辑")
    func amendStopsAtTarget() async throws {
        let (repository, commits) = try await makeRepository(["一", "二", "三"])
        defer { repository.remove() }

        let runner = repository.runner
        let rewrite = RepositoryRewrite(runner: runner)
        let operations = WorkingCopyOperations(runner: runner)
        let plan = try await rewrite.plan(.amend(commits[1]))

        #expect(plan.instructions.map(\.command) == [.edit, .pick])

        try await rewrite.perform(plan)

        // 停在目标本身，提交的改动没有撤回到工作区
        let progress = try await operations.context(head: try await head(in: repository)).progress

        #expect(try await head(in: repository) == commits[1])
        #expect(progress?.editedCommit == commits[1])
        #expect(try await runner.status().entries.isEmpty)

        try write("补充\n", to: file(1), in: repository)
        _ = try await runner.run(["add", "--all"])
        try await operations.finish(.rebase, action: "continue")

        let amended = try await runner.run(["show", "HEAD~1:" + file(1)])

        #expect(try await subjects(in: repository) == ["三", "二", "一"])
        #expect(String(decoding: amended, as: UTF8.self) == "补充\n")
        #expect(try await rewrite.resolve("HEAD~2") == commits[0])
    }

    /// 暂存、未暂存或两者都有时不储藏直接开始：Git 拒绝，HEAD、索引、工作区与储藏列表都不变。
    @Test("有本地改动时不储藏", arguments: ["staged", "unstaged", "both"])
    func amendBlockedByLocalChanges(changes: String) async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        let runner = repository.runner
        let rewrite = RepositoryRewrite(runner: runner)
        try await makeLocalChanges(changes, in: repository)
        let before = try await runner.status()

        await #expect(throws: GitError.self) {
            try await rewrite.perform(try await rewrite.plan(.amend(commits[0])))
        }

        #expect(try await head(in: repository) == commits[1])
        #expect(try await runner.status() == before)
        #expect(try await WorkingCopyOperations(runner: runner).context(head: commits[1]).progress == nil)
        #expect(try await RepositoryStashes(runner: runner).list().isEmpty)
    }

    /// 只有未跟踪文件时 Git 不拒绝：不储藏也停到目标，未跟踪文件留在工作区。
    @Test("只有未跟踪文件时不储藏")
    func amendWithUntrackedFiles() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        let rewrite = RepositoryRewrite(runner: repository.runner)
        try await makeLocalChanges("untracked", in: repository)
        try await rewrite.perform(try await rewrite.plan(.amend(commits[0])))

        #expect(try await head(in: repository) == commits[0])
        #expect(try read(untrackedFile, in: repository) == "新文件\n")
    }

    /// 先储藏全部本地改动再开始：停到目标时与结束编辑后储藏都保留，改动不自动回到工作区。
    @Test("储藏后停到目标", arguments: ["staged", "unstaged", "both", "untracked"])
    func amendAfterStash(changes: String) async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        let runner = repository.runner
        let rewrite = RepositoryRewrite(runner: runner)
        let stashes = RepositoryStashes(runner: runner)
        let plan = try await rewrite.plan(.amend(commits[0]))
        try await makeLocalChanges(changes, in: repository)

        try await stashes.stashingLocalChanges(message: "修补前", reapply: false) {
            try await rewrite.perform(plan)
        }

        #expect(try await head(in: repository) == commits[0])
        #expect(try await runner.status().entries.isEmpty)
        #expect(try await stashes.list().map(\.subject).contains { $0.hasSuffix("修补前") })

        try await WorkingCopyOperations(runner: runner).finish(.rebase, action: "continue")

        #expect(try await subjects(in: repository) == ["二", "一"])
        #expect(try await runner.status().entries.isEmpty)
        #expect(try await stashes.list().count == 1)
    }
}

// MARK: - Helpers

extension RepositoryRewriteTests {
    /// 未跟踪的新文件。
    private var untrackedFile: String {
        "未跟踪 [x].txt"
    }

    /// 按种类制造本地改动：暂存的改动在第 0 个文件，未暂存的在第 1 个文件，未跟踪的是一个新文件。
    private func makeLocalChanges(_ kind: String, in repository: TemporaryRepository) async throws {
        if ["staged", "both"].contains(kind) {
            try write("暂存\n", to: file(0), in: repository)
            _ = try await repository.runner.run(["add", "--", file(0)])
        }

        if ["unstaged", "both"].contains(kind) {
            try write("未暂存\n", to: file(1), in: repository)
        }

        if kind == "untracked" {
            try write("新文件\n", to: untrackedFile, in: repository)
        }
    }
}
