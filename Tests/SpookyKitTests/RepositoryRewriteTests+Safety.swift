import Foundation
import Testing
import TestSupport

@testable import SpookyKit

// MARK: - Safety

extension RepositoryRewriteTests {
    /// 计划之后历史变了就不执行：Git 生成的 todo 与计划的提交序列对不上时，序列编辑器中止变基，HEAD 与工作区都不变；
    /// 分支被别的操作移动过时，执行前发现 HEAD 变了，不改写任何提交。
    @Test("计划过期时不执行：todo 与计划不一致、HEAD 被移动")
    func stalePlans() async throws {
        let (repository, commits) = try await makeRepository(["一", "二", "三"])
        defer { repository.remove() }

        let rewrite = RepositoryRewrite(runner: repository.runner)
        let plan = try await rewrite.plan(.drop([commits[1]]))

        // 计划里少了最新的提交，相当于读取之后又有提交进入了这段历史
        let stale = RewritePlan(
            action: plan.action,
            head: plan.head,
            base: plan.base,
            onto: nil,
            commits: Array(plan.commits.dropLast()),
            instructions: Array(plan.instructions.dropLast()),
            pushed: [],
            merged: []
        )

        let error = await #expect(throws: RewriteError.self) {
            try await rewrite.perform(stale)
        }

        guard case .sequenceChanged(let result) = error else {
            Issue.record("应当报告提交序列已变化")
            return
        }

        let operations = WorkingCopyOperations(runner: repository.runner)

        #expect(result.map(RepositoryRewrite.isSequenceChange) ?? false)
        #expect(try await head(in: repository) == commits[2])
        #expect(try await operations.context(head: commits[2]).operation == nil)

        // 终端里又提交了一次，原来的计划不再执行
        try write("终端\n", to: "终端.txt", in: repository)
        _ = try await repository.runner.run(["add", "--all"])
        _ = try await repository.runner.run(["commit", "-q", "-m", "终端里的提交"])

        let moved = try await head(in: repository)

        await #expect(throws: RewriteError.self) {
            try await rewrite.perform(plan)
        }

        #expect(try await head(in: repository) == moved)
    }

    /// 调整顺序引起冲突时变基停下，进行中状态是变基；中止后回到开始之前。
    @Test("移动提交引起冲突后中止")
    func moveConflictThenAbort() async throws {
        let (repository, _) = try await makeRepository(["一"])
        defer { repository.remove() }

        var changed: [String] = []

        for content in ["甲", "乙"] {
            try write(content + "\n", to: file(0), in: repository)
            _ = try await repository.runner.run(["commit", "-q", "-am", content])
            changed.append(try await head(in: repository))
        }

        let rewrite = RepositoryRewrite(runner: repository.runner)
        let operations = WorkingCopyOperations(runner: repository.runner)
        let plan = try await rewrite.plan(.move([changed[1]], to: changed[0], position: .below))

        await #expect(throws: GitError.self) {
            try await rewrite.perform(plan)
        }

        let context = try await operations.context(head: try await head(in: repository))

        #expect(context.operation == .rebase)
        #expect(!(context.progress?.stopsForEdit ?? true))

        try await operations.finish(.rebase, action: "abort")
        #expect(try await head(in: repository) == changed[1])
    }

    /// 已推送到上游与已并入其它分支的提交分别列出，供确认时警告；
    /// 范围里有合并提交时不做交互式变基，不在 HEAD 历史里的提交同样拒绝。
    @Test("计划时的检查：已推送、已并入、合并提交与不在 HEAD 里的提交")
    func planChecks() async throws {
        let (repository, commits) = try await makeRepository(["一", "二", "三", "四"])
        defer { repository.remove() }

        let runner = repository.runner
        let rewrite = RepositoryRewrite(runner: runner)

        // 上游指向第二个提交，另一个分支停在第三个提交
        _ = try await runner.run(["update-ref", "refs/remotes/origin/main", commits[1]])
        _ = try await runner.run(["symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main"])
        _ = try await runner.run(["config", "remote.origin.url", "/nonexistent"])
        _ = try await runner.run(["config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*"])
        _ = try await runner.run(["config", "branch.main.remote", "origin"])
        _ = try await runner.run(["config", "branch.main.merge", "refs/heads/main"])
        _ = try await runner.run(["branch", "其它", commits[2]])

        let plan = try await rewrite.plan(.drop([commits[3], commits[1]]))

        #expect(plan.pushed == [commits[1]])
        #expect(plan.merged == [commits[1], commits[2]])

        // 不在 HEAD 历史里的提交
        let side = try await sideBranch(["支线"], from: commits[0], in: repository)

        await #expect(throws: RewriteError.self) {
            try await rewrite.plan(.drop(side))
        }

        // 合并之后，范围里有合并提交
        _ = try await runner.run(["merge", "-q", "--no-ff", "--no-edit", "side"])

        await #expect(throws: RewriteError.self) {
            try await rewrite.plan(.drop([commits[1]]))
        }
    }

    /// 取消正在执行的变基：Git 进程被结束，仓库停在开始之前。
    @Test("中途取消交互式变基")
    func cancelDuringRebase() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        // 变基开始前的钩子停在闸门上，报到时 Git 进程确实在运行
        let gate = try ProcessGate(in: repository.directory.appending(path: ".git"))
        defer { gate.release() }

        try installHook("pre-rebase", script: gate.command, in: repository)

        let rewrite = RepositoryRewrite(runner: repository.runner)
        let plan = try await rewrite.plan(.drop([commits[1]]))
        let task = Task { try await rewrite.perform(plan) }

        await gate.arrival()
        task.cancel()

        let result = await task.result
        let cancelled =
            switch result {
            case .success: false
            case .failure(let error): error is CancellationError || ((error as? GitError)?.isCancelled ?? false)
            }

        let operations = WorkingCopyOperations(runner: repository.runner)

        #expect(cancelled)
        #expect(try await head(in: repository) == commits[1])
        #expect(try await operations.context(head: commits[1]).operation == nil)
    }

    /// for-each-ref 的四个字段：引用名、上游、符号引用目标与当前分支标记；字段数不对时报告格式错误。
    @Test("包含提交的引用解析")
    func parseContainingReferences() throws {
        let output = Data(
            "refs/heads/功能 分支\0refs/remotes/origin/x\0\0*\nrefs/remotes/origin/HEAD\0\0refs/remotes/origin/main\0 \n"
                .utf8
        )

        let references = try RepositoryRewrite.parseContainingReferences(output)

        #expect(references.map(\.name) == ["refs/heads/功能 分支", "refs/remotes/origin/HEAD"])
        #expect(references[0].isHead && !references[0].isSymbolic)
        #expect(references[1].isSymbolic && !references[1].isHead)

        #expect(throws: RepositoryReadError.self) {
            try RepositoryRewrite.parseContainingReferences(Data("refs/heads/x\0\n".utf8))
        }
    }
}
