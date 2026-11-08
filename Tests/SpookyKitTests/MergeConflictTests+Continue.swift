import Foundation
import Testing

@testable import SpookyKit

/// 序列冲突解决后的预填与继续：信息按固定顺序取自 Git 的状态文件，继续时用编辑后的完整信息，由真实 Git 验证。
extension MergeConflictTests {
    /// 预填按 SQUASH_MSG、当前 fixup / squash 步、变基信息、apply 后端信息、MERGE_MSG 的顺序取第一个存在的文件。
    @Test("预填信息的来源顺序")
    func preparedMessageOrder() {
        let all = [
            "SQUASH_MSG": "squash merge",
            "rebase-merge/message-squash": "squash step",
            "rebase-merge/message-fixup": "fixup step",
            "rebase-merge/message": "rebase",
            "rebase-apply/final-commit": "apply",
            "MERGE_MSG": "merge",
        ]

        func message(without removed: Set<String>, done: String? = nil) -> String? {
            var files = all.filter { !removed.contains($0.key) }
            files["rebase-merge/done"] = done
            return OperationProgress.preparedMessage(in: files)
        }

        #expect(message(without: [], done: "squash 1234567 three\n") == "squash merge")
        #expect(message(without: ["SQUASH_MSG"], done: "pick 1234567 one\nsquash 89abcde two\n") == "squash step")
        #expect(message(without: ["SQUASH_MSG"], done: "fixup -C 89abcde two\n") == "fixup step")

        // 不在 squash / fixup 步时，即使留着它们的文件也不取
        #expect(message(without: ["SQUASH_MSG"], done: "pick 1234567 one\n") == "rebase")
        #expect(message(without: ["SQUASH_MSG", "rebase-merge/message"]) == "apply")
        #expect(message(without: ["SQUASH_MSG", "rebase-merge/message", "rebase-apply/final-commit"]) == "merge")
        #expect(OperationProgress.preparedMessage(in: [:]) == nil)
    }

    /// 变基冲突解决后用编辑后的信息继续：Unicode、换行、引号与注释行原样进入提交，原作者与作者日期不变；
    /// 仓库配置 commit.cleanup=strip 时注释行同样保留。
    @Test("变基冲突用编辑后的信息继续", arguments: [false, true])
    func continueRebaseWithMessage(apply: Bool) async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        let service = WorkingCopyOperations(runner: runner)
        _ = try await runner.run(["config", "--local", "commit.cleanup", "strip"])

        // feature 的第一个提交与 main 冲突，作者与作者日期都与当前身份不同
        try await commit(repository, ["x": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "feature"])
        try Data("feature\n".utf8).write(to: repository.directory.appending(path: "x"))
        _ = try await runner.run([
            "commit", "-q", "-am", "conflicting",
            "--author=Original Author <author@example.invalid>", "--date=@1600000000 +0530",
        ])
        try await commit(repository, ["y": "after\n"], message: "after")
        let original = try await authorLine("feature~1", in: repository)

        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["x": "main\n"], message: "main")
        _ = try await runner.run(["checkout", "-q", "feature"])
        _ = try await runner.execute(["rebase"] + (apply ? ["--apply"] : []) + ["main"], acceptedExitCodes: [1])

        let prepared = try await service.context(head: try await runner.status().branch.oid).preparedMessage
        #expect(prepared.hasPrefix("conflicting"))

        // 采用 feature 的版本，这一步有改动
        try await service.resolve(try await runner.status().entries, theirs: true)

        let subject = "标题 “弯引号” 'single' \"double\" 🎉"
        let body = "第一行\n# 保留的注释\n\n第三段"
        try await service.continueSequence(.rebase, subject: subject, body: body)

        #expect(try await service.context(head: try await runner.status().branch.oid).operation == nil)
        #expect(try await fullMessage("HEAD~1", in: repository) == subject + "\n\n" + body + "\n")
        #expect(try await authorLine("HEAD~1", in: repository) == original)
        #expect(try await fullMessage("HEAD", in: repository) == "after\n")
    }

    /// 序列的最后一个提交冲突时 todo 只剩一项，仍是序列，步数为 1 of 1；
    /// 这时提交即结束序列，不执行继续命令；前一步由 Git 自己完成。
    @Test("摘取序列的最后一步：仍是序列，冲突解决后提交即结束")
    func continueLastCherryPick() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let runner = repository.runner

        try await commit(repository, ["x": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "picked"])
        try await commit(repository, ["y": "first\n"], message: "first", author: "Original Author")
        try await commit(repository, ["x": "picked\n"], message: "conflicting", author: "Original Author")
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["x": "main\n"], message: "main")

        _ = try await runner.execute(["cherry-pick", "picked~1", "picked"], acceptedExitCodes: [1])

        let progress = try await currentProgress(repository)

        #expect(progress.state == .cherryPick && progress.isSequence)
        #expect(progress.step == 1 && progress.stepCount == 1)
        #expect(progress.stepSubject == "conflicting")

        // 采用对方解决后用编辑后的标题提交
        let service = WorkingCopyOperations(runner: runner)
        try await service.resolve(try await runner.status().entries, theirs: true)
        try await service.continueSequence(.cherryPick, subject: "edited", body: "")

        #expect(try await service.context(head: try await runner.status().branch.oid).operation == nil)

        let log = String(decoding: try await runner.run(["log", "-3", "--format=%an|%s"]), as: UTF8.self)

        #expect(log == "Original Author|edited\nOriginal Author|first\nSpooky Test|main\n")
    }
}

// MARK: - Continue Helpers

extension MergeConflictTests {
    /// 提交的作者名、邮箱与原始格式的作者日期。
    private func authorLine(_ revision: String, in repository: TemporaryRepository) async throws -> String {
        let output = try await repository.runner.run(
            ["log", "-1", "--format=%an|%ae|%ad", "--date=raw", revision, "--"]
        )

        return String(decoding: output, as: UTF8.self)
    }
}
