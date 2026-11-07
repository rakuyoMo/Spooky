import Foundation
import Testing

@testable import SpookyKit

/// 冲突向导卡片的数据：两侧相对共同祖先的改动，以及对方版本所在的提交，由真实 Git 制造的冲突验证。
extension MergeConflictTests {
    /// 七种冲突的两侧徽标都按这一侧与共同祖先的 stage 是否存在得出。
    @Test("两侧的改动类型")
    func conflictChanges() {
        let hash = String(repeating: "a", count: 40)

        /// 只给出存在的 stage。
        func stages(base: Bool, ours: Bool, theirs: Bool) -> ConflictStages {
            ConflictStages(
                base: base ? hash : nil,
                ours: ours ? hash : nil,
                theirs: theirs ? hash : nil,
                existsInWorktree: true,
                baseMode: base ? "100644" : nil,
                oursMode: ours ? "100644" : nil,
                theirsMode: theirs ? "100644" : nil
            )
        }

        /// 我方与对方的改动。
        func changes(_ stages: ConflictStages) -> [ConflictChange] {
            [stages.change(theirs: false), stages.change(theirs: true)]
        }

        // UU、AA、DU、UD
        #expect(changes(stages(base: true, ours: true, theirs: true)) == [.modified, .modified])
        #expect(changes(stages(base: false, ours: true, theirs: true)) == [.added, .added])
        #expect(changes(stages(base: true, ours: false, theirs: true)) == [.deleted, .modified])
        #expect(changes(stages(base: true, ours: true, theirs: false)) == [.modified, .deleted])

        // AU、UA、DD
        #expect(changes(stages(base: false, ours: true, theirs: false)) == [.added, .deleted])
        #expect(changes(stages(base: false, ours: false, theirs: true)) == [.deleted, .added])
        #expect(changes(stages(base: true, ours: false, theirs: false)) == [.deleted, .deleted])
    }

    /// 对方版本所在的提交：合并是被合并的提交，摘取与反转是正在处理的提交，两种后端的变基都是这一步正在应用的原提交。
    @Test("对方版本的提交来源", arguments: ["merge", "cherry-pick", "revert", "rebase", "rebase --apply"])
    func theirsCommit(operation: String) async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        let side = try await diverge(
            repository,
            base: ["x": "base\n"],
            ours: ["x": "ours\n"],
            theirs: ["x": "theirs\n"]
        )

        switch operation {
        case "revert":
            // 反转的是 main 上的 ours 提交：之后再改一次 x，反转时冲突
            try await commit(repository, ["x": "again\n"], message: "again")
            _ = try await runner.execute(["revert", "--no-edit", "HEAD~1"], acceptedExitCodes: [1])

        case "rebase", "rebase --apply":
            let arguments = operation.split(separator: " ").map(String.init) + ["main"]

            _ = try await runner.run(["checkout", "-q", "side"])
            _ = try await runner.execute(arguments, acceptedExitCodes: [1])

        default:
            _ = try await runner.execute([operation, "side"], acceptedExitCodes: [1])
        }

        let progress = try await currentProgress(repository)
        let expected = operation == "revert" ? try await commitID("main~1", in: repository) : side

        #expect(progress.theirsCommit == expected)
    }

    /// 压缩合并与储藏应用的对方没有提交来源。
    @Test("压缩合并与储藏应用没有对方提交")
    func theirsCommitMissing() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        _ = try await diverge(
            repository,
            base: ["x": "base\n"],
            ours: ["x": "ours\n"],
            theirs: ["x": "theirs\n"]
        )

        _ = try await runner.execute(["merge", "--squash", "side"], acceptedExitCodes: [1])
        #expect(try await currentProgress(repository).theirsCommit == nil)

        _ = try await runner.run(["reset", "-q", "--hard"])

        // 储藏应用冲突时没有进行中的操作
        try Data("stashed\n".utf8).write(to: repository.directory.appending(path: "x"))
        _ = try await runner.run(["stash", "-q"])
        try await commit(repository, ["x": "changed\n"], message: "changed")
        _ = try await runner.execute(["stash", "apply", "-q"], acceptedExitCodes: [1])

        let head = try await runner.status().branch.oid
        #expect(try await WorkingCopyOperations(runner: runner).context(head: head).progress == nil)
    }
}
