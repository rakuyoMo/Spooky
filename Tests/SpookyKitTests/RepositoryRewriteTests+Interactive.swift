import Foundation
import Testing

@testable import SpookyKit

// MARK: - Interactive Rebase

extension RepositoryRewriteTests {
    /// 压缩把所选提交并进其中最旧的一个，信息合并保留；SHA-1 与 SHA-256 仓库结果相同。
    @Test("压缩所选提交", arguments: ["sha1", "sha256"])
    func squash(objectFormat: String) async throws {
        let (repository, commits) = try await makeRepository(["一", "二", "三"], objectFormat: objectFormat)
        defer { repository.remove() }

        let rewrite = RepositoryRewrite(runner: repository.runner)
        let plan = try await rewrite.plan(.squash([commits[2], commits[1]], into: nil))

        #expect(plan.base == commits[0])
        #expect(plan.instructions.map(\.command) == [.pick, .squash])
        try await rewrite.perform(plan)

        let message = try await rewrite.commits([try await head(in: repository)]).first?.message
        #expect(try await subjects(in: repository) == ["二", "一"])
        #expect(message?.contains("三") ?? false)
    }

    /// fixup 到指定提交：比目标更旧的所选提交挪到目标之后，只保留目标的信息。
    @Test("fixup 到指定提交")
    func fixupIntoTarget() async throws {
        let (repository, commits) = try await makeRepository(["一", "二", "三", "四"])
        defer { repository.remove() }

        let rewrite = RepositoryRewrite(runner: repository.runner)
        let plan = try await rewrite.plan(.fixup([commits[1]], into: commits[2]))

        #expect(plan.instructions.map(\.commit) == [commits[2], commits[1], commits[3]])
        try await rewrite.perform(plan)

        #expect(try await subjects(in: repository) == ["四", "三", "一"])
        #expect(exists(file(1), in: repository))
    }

    /// 删除与移动只改变 todo 的指令，其余提交照原顺序重放。
    @Test("删除与移动提交")
    func dropAndMove() async throws {
        let (repository, commits) = try await makeRepository(["一", "二", "三", "四"])
        defer { repository.remove() }

        let rewrite = RepositoryRewrite(runner: repository.runner)
        try await rewrite.perform(try await rewrite.plan(.drop([commits[2]])))
        #expect(try await subjects(in: repository) == ["四", "二", "一"])

        let current = try await rewrite.commits([try await head(in: repository)])
        let second = try #require(current.first?.parents.first)
        try await rewrite.perform(try await rewrite.plan(.move([second], to: try await head(in: repository), position: .above)))
        #expect(try await subjects(in: repository) == ["二", "四", "一"])

        let top = try await head(in: repository)
        let bottom = try await RepositoryRewrite(runner: repository.runner).resolve("HEAD~2")
        try await rewrite.perform(try await rewrite.plan(.move([top], to: bottom, position: .below)))
        #expect(try await subjects(in: repository) == ["四", "一", "二"])
    }

    /// 改信息沿用传入的文字：Unicode、引号、`$` 与以 # 开头的行都原样保留。
    @Test("改写提交信息")
    func reword() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        let message = "新标题 'é' $HOME `x`\n\n#123 正文\n"
        let rewrite = RepositoryRewrite(runner: repository.runner)
        try await rewrite.perform(try await rewrite.plan(.reword(commits[0], message: message)))

        let rewritten = try await rewrite.resolve("HEAD~1")
        let stored = try await rewrite.commits([rewritten]).first?.message
        #expect(stored?.trimmingCharacters(in: .newlines) == message.trimmingCharacters(in: .newlines))
        #expect(try await subjects(in: repository).first == "二")
    }

    /// edit 停下后提交被撤回工作区；横幅据此显示继续，提交改动后继续完成变基。
    @Test("编辑提交后继续")
    func editAndContinue() async throws {
        let (repository, commits) = try await makeRepository(["一", "二", "三"])
        defer { repository.remove() }

        let rewrite = RepositoryRewrite(runner: repository.runner)
        let operations = WorkingCopyOperations(runner: repository.runner)
        try await rewrite.perform(try await rewrite.plan(.edit(commits[1])))

        let context = try await operations.context(head: try await head(in: repository))
        #expect(context.progress?.stopsForEdit ?? false)
        #expect(context.progress?.stepKind == .editing)
        #expect(try await head(in: repository) == commits[0])

        _ = try await repository.runner.run(["add", "--all"])
        _ = try await repository.runner.run(["commit", "-q", "-m", "二（拆分后）"])
        try await operations.finish(.rebase, action: "continue")

        #expect(try await subjects(in: repository) == ["三", "二（拆分后）", "一"])
        await #expect(throws: RewriteError.self) { try await rewrite.plan(.edit(commits[0])) }
    }

    /// 暂存的改动并入较早的提交；未暂存的改动由变基自己储藏，结束后回到工作区。
    @Test("暂存的改动并入所选提交")
    func amendStagedChanges() async throws {
        let (repository, commits) = try await makeRepository(["一", "二"])
        defer { repository.remove() }

        try write("补充\n", to: file(0), in: repository)
        _ = try await repository.runner.run(["add", "--", file(0)])
        try write("未暂存\n", to: file(1), in: repository)
        let rewrite = RepositoryRewrite(runner: repository.runner)
        try await rewrite.perform(try await rewrite.plan(.amend(commits[0])))

        let first = try await rewrite.resolve("HEAD~1")
        let content = try await repository.runner.run(["show", first + ":" + file(0)])
        #expect(String(decoding: content, as: UTF8.self) == "补充\n")
        #expect(try await subjects(in: repository) == ["二", "一"])
        #expect(try read(file(1), in: repository) == "未暂存\n")

        await #expect(throws: RewriteError.self) { try await rewrite.plan(.amend(first)) }
    }

    /// Autosquash 由 Git 按标记排列 todo，核对时只比较提交集合。
    @Test("Autosquash")
    func autosquash() async throws {
        let (repository, _) = try await makeRepository(["一", "二", "fixup! 一"])
        defer { repository.remove() }

        let rewrite = RepositoryRewrite(runner: repository.runner)
        let plan = try await rewrite.plan(.autosquash)

        #expect(plan.base == nil)
        #expect(plan.instructions.isEmpty)
        try await rewrite.perform(plan)

        #expect(try await subjects(in: repository) == ["二", "一"])
        await #expect(throws: RewriteError.self) { try await rewrite.plan(.autosquash) }
    }

    /// 只把所选提交重放到新基点上，同一段里没选的提交从当前分支去掉。
    @Test("只把所选提交变基到别处")
    func rebaseSelected() async throws {
        let (repository, commits) = try await makeRepository(["基础", "甲", "不要", "乙"])
        defer { repository.remove() }

        let target = try await sideBranch(["新基点"], from: commits[0], in: repository).last ?? ""
        let rewrite = RepositoryRewrite(runner: repository.runner)
        let plan = try await rewrite.plan(.rebase([commits[3], commits[1]], onto: "side"))

        #expect(plan.onto == target)
        #expect(plan.instructions.map(\.command) == [.pick, .drop, .pick])

        // pre-rebase 钩子拒绝时不改写；跳过钩子后照常执行
        try installHook("pre-rebase", script: "exit 1", in: repository)
        await #expect(throws: GitError.self) { try await rewrite.perform(plan) }
        try await rewrite.perform(plan, skipHooks: true)

        #expect(try await subjects(in: repository) == ["乙", "甲", "新基点", "基础"])
        #expect(!exists(file(2), in: repository))
    }
}
