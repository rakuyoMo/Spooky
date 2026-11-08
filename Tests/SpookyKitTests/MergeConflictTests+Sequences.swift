import Foundation
import Testing

@testable import SpookyKit

/// 用真实 Git 停在各种进行中操作上，验证单个操作、序列、edit 与交互式变基尚未开始的分类与步数。
extension MergeConflictTests {
    /// 只摘取或反转一个提交时 Git 不建 sequencer，按合并的方式收尾，没有步数；
    /// 对方是正在摘取或被反转的提交，中止回到操作之前的 HEAD，并撤回冲突留下的改动。
    @Test("单个摘取与单个反转：不是序列、对方提交与中止")
    func singleOperations() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let runner = repository.runner

        try await commit(repository, ["x": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try await commit(repository, ["x": "side\n"], message: "side")
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["x": "change\n"], message: "change")
        try await commit(repository, ["x": "main\n"], message: "main")

        let side = try await commitID("side", in: repository)
        let change = try await commitID("HEAD~1", in: repository)
        let head = try await commitID("HEAD", in: repository)
        let service = WorkingCopyOperations(runner: runner)

        // 单个摘取
        _ = try await runner.execute(["cherry-pick", "side"], acceptedExitCodes: [1])

        let picking = try await currentProgress(repository)

        #expect(picking.state == .cherryPick && !picking.isSequence)
        #expect(picking.step == nil && picking.stepCount == nil)
        #expect(picking.ours == head && picking.theirsCommit == side)

        try await service.finish(.cherryPick, action: "abort")

        // 单个反转：反转 change 时与之后的 main 冲突
        _ = try await runner.execute(["revert", "--no-edit", "HEAD~1"], acceptedExitCodes: [1])

        let reverting = try await currentProgress(repository)

        #expect(reverting.state == .revert && !reverting.isSequence)
        #expect(reverting.step == nil && reverting.stepCount == nil)
        #expect(reverting.theirs == change && reverting.ours == head)
        #expect(reverting.theirsCommit == change && reverting.stepKind == .reverting)

        try await service.finish(.revert, action: "abort")

        #expect(try await service.context(head: head).operation == nil)
        #expect(try await runner.status().branch.oid == head)

        // 中止还要撤回冲突留下的改动，只清掉进行中的状态不算中止
        #expect(try await runner.status().entries.isEmpty)
    }

    /// 反转序列只数剩余的提交：三个提交在第二个冲突时剩两个，当前一步是其中第 1 个；解决后继续，整个序列完成。
    @Test("反转序列的剩余步数与继续")
    func revertSequence() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let runner = repository.runner
        let service = WorkingCopyOperations(runner: runner)

        try await commit(repository, ["x": "base\n"], message: "base")
        try await commit(repository, ["a": "a\n"], message: "one")
        try await commit(repository, ["x": "two\n"], message: "two")
        try await commit(repository, ["c": "c\n"], message: "three")
        try await commit(repository, ["x": "again\n"], message: "again")

        // 反转按给出的顺序处理：先 one，再 two（冲突），最后 three
        _ = try await runner.execute(
            ["revert", "--no-edit", "HEAD~3", "HEAD~2", "HEAD~1"],
            acceptedExitCodes: [1]
        )

        let progress = try await currentProgress(repository)

        #expect(progress.state == .revert && progress.isSequence)
        #expect(progress.step == 1 && progress.stepCount == 2)
        #expect(progress.stepKind == .reverting)
        #expect(progress.stepSubject == "two")

        // 采用对方解决后继续，第三个提交没有冲突，整个序列完成
        try await service.resolve(try await runner.status().entries, theirs: true)
        try await service.finish(.revert, action: "continue")

        #expect(try await service.context(head: try await runner.status().branch.oid).operation == nil)
    }

    /// 只有一个提交的变基也有步数；merge 与 apply 两种后端都是序列，冲突停下不是 edit，也不是尚未开始；
    /// 对方提交是这一步正在应用的原提交；中止回到变基之前的 HEAD。
    @Test("一项变基的步数、对方提交与中止", arguments: [false, true])
    func singleCommitRebase(apply: Bool) async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let runner = repository.runner

        try await commit(repository, ["x": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "feature"])
        try await commit(repository, ["x": "feature\n"], message: "feature")

        let feature = try await commitID("HEAD", in: repository)

        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["x": "main\n"], message: "main")
        _ = try await runner.run(["checkout", "-q", "feature"])

        _ = try await runner.execute(
            ["rebase"] + (apply ? ["--apply"] : []) + ["main"],
            acceptedExitCodes: [1]
        )

        let progress = try await currentProgress(repository)

        #expect(progress.state == .rebase && progress.isSequence)
        #expect(progress.step == 1 && progress.stepCount == 1)
        #expect(progress.stepKind == .applying && progress.stepSubject == "feature")
        #expect(!progress.stopsForEdit && !progress.isPendingInteractive)
        #expect(progress.theirsCommit == feature)

        // 中止回到变基之前的 HEAD
        let service = WorkingCopyOperations(runner: runner)
        try await service.finish(.rebase, action: "abort")

        #expect(try await service.context(head: feature).operation == nil)
        #expect(try await runner.status().branch.oid == feature)
    }

    /// 停在第一条 break 上时还没有处理任何提交，没有 stopped-sha，是交互式变基尚未开始；
    /// edit 停下时记下正在修改的提交与它的父提交；squash、fixup 的冲突同样留下 amend，却不是 edit；
    /// squash 步冲突解决后改写正在合成的提交，编辑后的信息成为合成提交的信息。
    @Test("交互式变基：尚未开始、edit 停顿、squash 与 fixup 冲突，用编辑后的信息继续 squash")
    func interactiveStops() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let runner = repository.runner
        let service = WorkingCopyOperations(runner: runner)

        try await commit(repository, ["x": "base\n"], message: "base")
        try await commit(repository, ["x": "one\n"], message: "one")
        try await commit(repository, ["x": "two\n"], message: "two")
        try await commit(repository, ["x": "three\n"], message: "three")

        let base = try await commitID("HEAD~3", in: repository)
        let one = try await commitID("HEAD~2", in: repository)
        let three = try await commitID("HEAD", in: repository)

        // 停在第一条 break 上
        try await rebaseInteractively(repository, todo: "break\npick \(one) one\n", onto: "HEAD~3")

        let pending = try await currentProgress(repository)

        #expect(pending.state == .rebase && pending.isPendingInteractive)
        #expect(!pending.stopsForEdit)

        try await service.finish(.rebase, action: "abort")

        // edit 停下
        try await rebaseInteractively(repository, todo: "edit \(one) one\n", onto: "HEAD~3")

        let editing = try await currentProgress(repository)

        #expect(editing.stopsForEdit && editing.editedCommit == one && editing.editedParent == base)
        #expect(editing.stepKind == .editing && editing.stepSubject == "one")
        #expect(!editing.isPendingInteractive)

        try await service.finish(.rebase, action: "abort")

        // three 的改动基于 two，接在 one 上就冲突；fixup 停下后中止，squash 停下后留着继续
        for command in ["fixup", "squash"] {
            try await rebaseInteractively(
                repository,
                todo: "pick \(one) one\n\(command) \(three) three\n",
                onto: "HEAD~3"
            )

            let stopped = try await currentProgress(repository)

            #expect(!stopped.stopsForEdit && stopped.editedParent == nil && stopped.stepKind == .applying)
            #expect(!stopped.isPendingInteractive)
            #expect(try await runner.status().entries.contains { $0.kind == .conflicted })

            if command == "fixup" {
                try await service.finish(.rebase, action: "abort")
            }
        }

        // squash 步的预填带着两个提交的信息，用编辑后的信息继续
        let prepared = try await service.context(head: try await runner.status().branch.oid).preparedMessage

        #expect(prepared.contains("one") && prepared.contains("three"))

        try await service.resolve(try await runner.status().entries, theirs: true)
        try await service.continueSequence(.rebase, subject: "合成的提交", body: "")

        #expect(try await service.context(head: try await runner.status().branch.oid).operation == nil)
        #expect(try await fullMessage("HEAD", in: repository) == "合成的提交\n")
        #expect(try await fullMessage("HEAD~1", in: repository) == "base\n")
    }
}

// MARK: - Sequence Helpers

extension MergeConflictTests {
    /// 按当前 HEAD 读取仓库里进行中的操作；没有进行中的操作时记为失败。
    func currentProgress(_ repository: TemporaryRepository) async throws -> OperationProgress {
        let runner = repository.runner
        let head = try await runner.status().branch.oid
        let context = try await WorkingCopyOperations(runner: runner).context(head: head)

        return try #require(context.progress)
    }

    /// 提交的完整信息原文，末尾只留一个换行。
    func fullMessage(_ revision: String, in repository: TemporaryRepository) async throws -> String {
        let output = try await repository.runner.run(["log", "-1", "--format=%B", revision, "--"])

        // log 在信息原文之后再补一个换行
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines) + "\n"
    }

    /// 解析引用对应的完整提交哈希。
    func commitID(_ reference: String, in repository: TemporaryRepository) async throws -> String {
        let output = try await repository.runner.run(["rev-parse", "--verify", reference + "^{commit}"])
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 以给定的指令清单做一次交互式变基；停下时 Git 以 1 退出，与成功一样接受。
    ///
    /// 指令清单写在系统临时目录下的独立文件里，由序列编辑器原样复制过去。
    func rebaseInteractively(
        _ repository: TemporaryRepository,
        todo: String,
        onto base: String
    ) async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "spooky-todo-" + UUID().uuidString)
        try Data(todo.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        _ = try await repository.runner.execute(
            ["-c", "sequence.editor=cp " + file.path, "rebase", "-i", base],
            acceptedExitCodes: [0, 1]
        )
    }
}
