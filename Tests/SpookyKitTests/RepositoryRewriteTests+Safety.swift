import Foundation
import Testing

@testable import SpookyKit

// MARK: - Safety

extension RepositoryRewriteTests {
    /// 计划之后分支被别的操作移动过：执行前发现 HEAD 变了，不改写任何提交。
    @Test("计划后 HEAD 被移动时不执行")
    func headMovedAfterPlanning() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        let rewrite = RepositoryRewrite(runner: repository.runner)
        let plan = try await rewrite.plan(.drop([commits[1]]))

        try write("终端\n", to: "终端.txt", in: repository)
        _ = try await repository.runner.run(["add", "--all"])
        _ = try await repository.runner.run(["commit", "-q", "-m", "终端里的提交"])
        let moved = try await head(in: repository)

        await #expect(throws: RewriteError.self) { try await rewrite.perform(plan) }
        #expect(try await head(in: repository) == moved)
    }

    /// Git 生成的 todo 与计划的提交序列对不上时，序列编辑器中止变基，HEAD 与工作区都不变。
    @Test("todo 与计划不一致时中止")
    func sequenceMismatch() async throws {
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

        let error = await #expect(throws: RewriteError.self) { try await rewrite.perform(stale) }
        guard case .sequenceChanged(let result) = error else {
            Issue.record("应当报告提交序列已变化")
            return
        }

        #expect(result.map(RepositoryRewrite.isSequenceChange) ?? false)
        #expect(try await head(in: repository) == commits[2])
        #expect(try await WorkingCopyOperations(runner: repository.runner).context(head: commits[2]).operation == nil)
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

        await #expect(throws: GitError.self) { try await rewrite.perform(plan) }

        let context = try await operations.context(head: try await head(in: repository))
        #expect(context.operation == .rebase)
        #expect(!(context.progress?.stopsForEdit ?? true))

        try await operations.finish(.rebase, action: "abort")
        #expect(try await head(in: repository) == changed[1])
    }

    /// 范围里有合并提交时不做交互式变基；不在 HEAD 历史里的提交同样拒绝。
    @Test("合并提交与不在 HEAD 里的提交")
    func rejectsMergesAndForeignCommits() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        let side = try await sideBranch(["支线"], from: commits[0], in: repository)
        let rewrite = RepositoryRewrite(runner: repository.runner)

        await #expect(throws: RewriteError.self) { try await rewrite.plan(.drop(side)) }

        _ = try await repository.runner.run(["merge", "-q", "--no-ff", "--no-edit", "side"])

        await #expect(throws: RewriteError.self) { try await rewrite.plan(.drop([commits[1]])) }
    }

    /// 取消正在执行的变基：Git 进程被结束，仓库停在开始之前。
    @Test("中途取消交互式变基")
    func cancelDuringRebase() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        try installHook("pre-rebase", script: "sleep 10", in: repository)
        let rewrite = RepositoryRewrite(runner: repository.runner)
        let plan = try await rewrite.plan(.drop([commits[1]]))
        let task = Task { try await rewrite.perform(plan) }

        try await Task.sleep(for: .milliseconds(800))
        task.cancel()

        let result = await task.result
        let cancelled =
            switch result {
            case .success: false
            case .failure(let error): error is CancellationError || ((error as? GitError)?.isCancelled ?? false)
            }

        #expect(cancelled)
        #expect(try await head(in: repository) == commits[1])
        #expect(try await WorkingCopyOperations(runner: repository.runner).context(head: commits[1]).operation == nil)
    }

    /// 已推送到上游与已并入其它分支的提交分别列出，供确认时警告。
    @Test("已推送与已并入其它分支的提交")
    func pushedAndMergedCommits() async throws {
        let (repository, commits) = try await makeRepository(["一", "二", "三", "四"])
        defer { repository.remove() }

        _ = try await repository.runner.run(["update-ref", "refs/remotes/origin/main", commits[1]])
        _ = try await repository.runner.run(["symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main"])
        _ = try await repository.runner.run(["config", "remote.origin.url", "/nonexistent"])
        _ = try await repository.runner.run(["config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*"])
        _ = try await repository.runner.run(["config", "branch.main.remote", "origin"])
        _ = try await repository.runner.run(["config", "branch.main.merge", "refs/heads/main"])
        _ = try await repository.runner.run(["branch", "其它", commits[2]])

        let plan = try await RepositoryRewrite(runner: repository.runner).plan(.drop([commits[3], commits[1]]))

        #expect(plan.pushed == [commits[1]])
        #expect(plan.merged == [commits[1], commits[2]])
    }

    /// for-each-ref 的四个字段：引用名、上游、符号引用目标与当前分支标记；字段数不对时报告格式错误。
    @Test("包含提交的引用解析")
    func parseContainingReferences() throws {
        let output =
            Data("refs/heads/功能 分支\0refs/remotes/origin/x\0\0*\nrefs/remotes/origin/HEAD\0\0refs/remotes/origin/main\0 \n".utf8)
        let references = try RepositoryRewrite.parseContainingReferences(output)

        #expect(references.map(\.name) == ["refs/heads/功能 分支", "refs/remotes/origin/HEAD"])
        #expect(references[0].isHead && !references[0].isSymbolic)
        #expect(references[1].isSymbolic && !references[1].isHead)
        #expect(throws: RepositoryReadError.self) {
            try RepositoryRewrite.parseContainingReferences(Data("refs/heads/x\0\n".utf8))
        }
    }

    /// 标记可以连续出现；没有标记或只剩标记时不是 Autosquash 提交。
    @Test("Autosquash 标记")
    func autosquashReference() {
        #expect(RepositoryRewrite.autosquashReference(of: "fixup! fixup! 标题") == "标题")
        #expect(RepositoryRewrite.autosquashReference(of: "amend! abc1234") == "abc1234")
        #expect(RepositoryRewrite.autosquashReference(of: "squash! ") == nil)
        #expect(RepositoryRewrite.autosquashReference(of: "普通提交") == nil)
    }

    /// 只有 edit 主动停下时才有 amend 文件；冲突停下与 apply 后端都不算。
    @Test("edit 停顿的判断")
    func editStop() throws {
        var files = ["rebase-merge/head-name": "refs/heads/main\n", "rebase-merge/done": "edit abcd1234 # 标题\n"]
        #expect(!(OperationProgress(files: files, head: nil)?.stopsForEdit ?? true))

        files["rebase-merge/amend"] = "abcd1234\n"
        let progress = try #require(OperationProgress(files: files, head: nil))
        #expect(progress.stopsForEdit)
        #expect(progress.stepSubject == "标题")
    }
}
