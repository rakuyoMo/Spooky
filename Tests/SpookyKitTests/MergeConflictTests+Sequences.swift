import Foundation
import Testing

@testable import SpookyKit

/// 用真实 Git 停在各种进行中操作上，验证单个操作、序列、edit 与交互式变基尚未开始的分类与步数。
extension MergeConflictTests {
    /// 只摘取或反转一个提交时 Git 不建 sequencer，按合并的方式收尾，没有步数。
    @Test("单个摘取与单个反转不是序列")
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

        let service = WorkingCopyOperations(runner: runner)
        _ = try await runner.execute(["cherry-pick", "side"], acceptedExitCodes: [1])

        let picking = try await currentProgress(repository)

        #expect(picking.state == .cherryPick && !picking.isSequence)
        #expect(picking.step == nil && picking.stepCount == nil)

        try await service.finish(.cherryPick, action: "abort")

        _ = try await runner.execute(["revert", "--no-edit", "HEAD~1"], acceptedExitCodes: [1])
        let reverting = try await currentProgress(repository)

        #expect(reverting.state == .revert && !reverting.isSequence)
        #expect(reverting.step == nil && reverting.stepCount == nil)
    }

    /// 三个提交在第二个冲突时剩两个：当前一步是剩余中的第 1 个；只剩最后一个时仍是序列。
    @Test("摘取与反转序列的剩余步数", arguments: [false, true])
    func sequenceSteps(reverting: Bool) async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        let service = WorkingCopyOperations(runner: runner)
        try await commit(repository, ["x": "base\n"], message: "base")

        // 反转按给出的顺序处理：先 one，再 two（冲突），最后 three
        if reverting {
            try await commit(repository, ["a": "a\n"], message: "one")
            try await commit(repository, ["x": "two\n"], message: "two")
            try await commit(repository, ["c": "c\n"], message: "three")
            try await commit(repository, ["x": "again\n"], message: "again")
            _ = try await runner.execute(
                ["revert", "--no-edit", "HEAD~3", "HEAD~2", "HEAD~1"],
                acceptedExitCodes: [1]
            )
        } else {
            _ = try await runner.run(["checkout", "-q", "-b", "side"])
            try await commit(repository, ["a": "a\n"], message: "one")
            try await commit(repository, ["x": "two\n"], message: "two")
            try await commit(repository, ["c": "c\n"], message: "three")
            _ = try await runner.run(["checkout", "-q", "main"])
            try await commit(repository, ["x": "main\n"], message: "main")
            _ = try await runner.execute(["cherry-pick", "side~2", "side~1", "side"], acceptedExitCodes: [1])
        }

        let progress = try await currentProgress(repository)

        #expect(progress.state == (reverting ? .revert : .cherryPick) && progress.isSequence)
        #expect(progress.step == 1 && progress.stepCount == 2)
        #expect(progress.stepKind == (reverting ? .reverting : .applying))
        #expect(progress.stepSubject == "two")

        // 采用对方解决后继续，第三个提交没有冲突，整个序列完成
        try await service.resolve(try await runner.status().entries, theirs: true)
        try await service.finish(reverting ? .revert : .cherryPick, action: "continue")

        let head = try await runner.status().branch.oid
        #expect(try await service.context(head: head).operation == nil)
    }

    /// 序列的最后一个提交冲突时 todo 只剩一项，仍是序列，步数为 1 of 1。
    @Test("序列的最后一项仍是序列")
    func lastSequenceStep() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        try await commit(repository, ["x": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try await commit(repository, ["a": "a\n"], message: "one")
        try await commit(repository, ["x": "last\n"], message: "last")
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["x": "main\n"], message: "main")
        _ = try await runner.execute(["cherry-pick", "side~1", "side"], acceptedExitCodes: [1])

        let progress = try await currentProgress(repository)

        #expect(progress.isSequence)
        #expect(progress.step == 1 && progress.stepCount == 1)
        #expect(progress.stepSubject == "last")
    }

    /// 只有一个提交的变基也有步数；merge 与 apply 两种后端都是序列，冲突停下不是 edit，也不是尚未开始。
    @Test("一项变基的步数", arguments: [false, true])
    func singleCommitRebase(apply: Bool) async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        try await commit(repository, ["x": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "feature"])
        try await commit(repository, ["x": "feature\n"], message: "feature")
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
    }

    /// edit 停下时记下正在修改的提交；squash、fixup 的冲突同样留下 amend，却不是 edit。
    @Test("edit 停顿与 squash、fixup 冲突的区分")
    func editAndSquashStops() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        let service = WorkingCopyOperations(runner: runner)
        try await commit(repository, ["x": "base\n"], message: "base")
        try await commit(repository, ["x": "one\n"], message: "one")
        try await commit(repository, ["x": "two\n"], message: "two")
        try await commit(repository, ["x": "three\n"], message: "three")

        let one = try await commitID("HEAD~2", in: repository)
        let three = try await commitID("HEAD", in: repository)

        try await rebaseInteractively(repository, todo: "edit \(one) one\n", onto: "HEAD~3")

        let editing = try await currentProgress(repository)

        #expect(editing.stopsForEdit && editing.editedCommit == one)
        #expect(editing.stepKind == .editing && editing.stepSubject == "one")
        #expect(!editing.isPendingInteractive)

        try await service.finish(.rebase, action: "abort")

        // three 的改动基于 two，接在 one 上就冲突
        for command in ["squash", "fixup"] {
            try await rebaseInteractively(
                repository,
                todo: "pick \(one) one\n\(command) \(three) three\n",
                onto: "HEAD~3"
            )

            let stopped = try await currentProgress(repository)

            #expect(!stopped.stopsForEdit && stopped.stepKind == .applying)
            #expect(!stopped.isPendingInteractive)
            #expect(try await runner.status().entries.contains { $0.kind == .conflicted })

            try await service.finish(.rebase, action: "abort")
        }
    }

    /// 停在第一条 break 上时还没有处理任何提交：没有 stopped-sha，是交互式变基尚未开始。
    @Test("交互式变基尚未开始")
    func pendingInteractiveRebase() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        try await commit(repository, ["x": "base\n"], message: "base")
        try await commit(repository, ["x": "one\n"], message: "one")

        let one = try await commitID("HEAD", in: repository)
        try await rebaseInteractively(repository, todo: "break\npick \(one) one\n", onto: "HEAD~1")

        let progress = try await currentProgress(repository)

        #expect(progress.state == .rebase && progress.isPendingInteractive)
        #expect(!progress.stopsForEdit)
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
