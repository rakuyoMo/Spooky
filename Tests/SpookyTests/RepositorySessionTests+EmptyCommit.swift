import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 进行中的操作没有任何改动时的空提交确认：什么时候算空、单个操作与序列各自按钮的 Git 结果，以及关掉警告后直接保留空提交。
extension RepositorySessionTests {
    /// 单个摘取解决后没有任何改动才算空，有改动时也不能提交；确认框开着时不执行 Git，关掉警告后直接保留空提交；
    /// 合并解决后没有任何改动时，确认框的备选中止合并。
    @Test("单个操作的空提交：何时算空、确认、保留与中止")
    func emptySingleCommit() async throws {
        let (session, directory, runner) = try await openOperationRepository { directory, runner in
            try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
            _ = try await runner.run(["checkout", "-q", "-b", "side"])
            try await commitFiles(["x": "side"], message: "side", in: directory, runner: runner)
            _ = try await runner.run(["checkout", "-q", "main"])
            try await commitFiles(["x": "main"], message: "main", in: directory, runner: runner)
            _ = try await runner.execute(["cherry-pick", "side"], acceptedExitCodes: [1])
        }

        defer { closeOperationRepository(session, directory) }

        await resolveAll(session, theirs: false)
        try await checkEmptyConditions(session, directory: directory, runner: runner)

        var requests: [EmptyCommitRequest] = []
        session.onEmptyCommitPrompt = { requests.append($0) }

        let head = try await revision("HEAD", runner: runner)

        // 确认框还开着时什么也不执行，Cancel 就是不选任何动作
        session.setMessage("空的摘取")
        withEmptyCommitWarning(true) { session.commit() }

        #expect(requests.map(\.isSequence) == [false])
        #expect(session.writeTask == nil)

        // 关掉警告后不再确认，直接建出带编辑后信息的空提交并结束摘取
        withEmptyCommitWarning(false) { session.commit() }
        #expect(requests.count == 1)

        await session.writeTask?.value
        await reload(session) { session.context?.progress == nil }

        // 空提交与它的父提交是同一棵树
        let tree = try await revision("HEAD~1^{tree}", runner: runner)

        #expect(try await revision("HEAD~1", runner: runner) == head)
        #expect(try await revision("HEAD^{tree}", runner: runner) == tree)
        #expect(try await subject(of: "HEAD", runner: runner) == "空的摘取")

        try await abortEmptyMerge(session, runner: runner)
    }

    /// 摘取序列的两步解决后都没有任何改动：继续前先确认；保留时这一步成为带编辑后信息的空提交，跳过时没有这一步，两种都接着摘取后面的提交。
    @Test("序列的空步骤保留与跳过")
    func emptySequenceStep() async throws {
        let (session, directory, runner) = try await openOperationRepository { directory, runner in
            try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
            _ = try await runner.run(["checkout", "-q", "-b", "picked"])
            try await commitFiles(["x": "one"], message: "one", in: directory, runner: runner)
            try await commitFiles(["y": "two"], message: "two", in: directory, runner: runner)
            try await commitFiles(["x": "three"], message: "three", in: directory, runner: runner)
            _ = try await runner.run(["checkout", "-q", "main"])
            try await commitFiles(["x": "main"], message: "main", in: directory, runner: runner)
        }

        defer { closeOperationRepository(session, directory) }

        var requests: [EmptyCommitRequest] = []
        session.onEmptyCommitPrompt = { requests.append($0) }

        let head = try await revision("HEAD", runner: runner)

        // 第一步与第三步都冲突，采用我方后这一步没有改动
        _ = try await runner.execute(["cherry-pick", "picked~2", "picked~1", "picked"], acceptedExitCodes: [1])
        await reload(session) { session.context?.progress?.isSequence ?? false }

        await resolveAll(session, theirs: false)
        session.setMessage("保留的空步骤")
        withEmptyCommitWarning(true) { session.continueSequence() }

        #expect(requests.map(\.isSequence) == [true])

        // 保留后接着摘取，停在第三步
        let three = try await revision("picked", runner: runner)
        requests.last?.commit()
        await session.writeTask?.value
        await reload(session) { session.context?.progress?.theirs == three }

        await resolveAll(session, theirs: false)
        session.setMessage("跳过的空步骤")
        withEmptyCommitWarning(true) { session.continueSequence() }

        #expect(requests.map(\.isSequence) == [true, true])

        // 跳过最后一步后序列结束
        requests.last?.alternate()
        await session.writeTask?.value
        await reload(session) { session.context?.progress == nil }

        let log = String(decoding: try await runner.run(["log", "--format=%s", "\(head)..HEAD"]), as: UTF8.self)

        #expect(log == "two\n保留的空步骤\n")
    }
}

// MARK: - Empty Commit Helpers

extension RepositorySessionTests {
    /// 未跟踪的文件与未暂存的修改都是改动，不算空提交，这时没有暂存的改动也不能提交；还原后重新算空。
    private func checkEmptyConditions(
        _ session: RepositorySession,
        directory: URL,
        runner: GitRunner
    ) async throws {
        session.setMessage("message")

        #expect(session.commitsEmpty && session.canCommit)

        let note = directory.appending(path: "note.txt")
        try Data("note".utf8).write(to: note)
        await reload(session) { !session.isWorkingCopyClean }

        #expect(!session.commitsEmpty && !session.canCommit)

        try FileManager.default.removeItem(at: note)
        try Data("changed\n".utf8).write(to: directory.appending(path: "x"))
        await reload(session) { session.status?.entries.map(\.path) == ["x"] }

        #expect(!session.commitsEmpty && !session.canCommit)

        _ = try await runner.run(["checkout", "--", "x"])
        await reload(session) { session.isWorkingCopyClean }

        #expect(session.commitsEmpty)
    }

    /// 合并 side 再次冲突，采用我方后没有任何改动：确认框的备选中止合并，回到合并前的提交，工作区没有改动。
    private func abortEmptyMerge(_ session: RepositorySession, runner: GitRunner) async throws {
        var requests: [EmptyCommitRequest] = []
        session.onEmptyCommitPrompt = { requests.append($0) }

        _ = try await runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])
        await reload(session) { session.context?.operation == .merge }
        await resolveAll(session, theirs: false)

        let head = try await revision("HEAD", runner: runner)

        session.setMessage("合并")
        withEmptyCommitWarning(true) { session.commit() }

        #expect(requests.map(\.isSequence) == [false])

        requests.first?.alternate()
        await session.writeTask?.value
        await reload(session) { session.context?.progress == nil }

        #expect(try await revision("HEAD", runner: runner) == head)
        #expect(session.status?.entries.isEmpty ?? false)
    }

    /// 按给定的警告设置同步执行一段操作，再恢复原来的设置。
    ///
    /// 会话只从 `UserDefaults.standard` 读取这个设置，并在这段同步代码里读完，不受并行测试改动它的影响。
    private func withEmptyCommitWarning(_ warns: Bool, _ body: () -> Void) {
        let key = WorkingCopyPreferences.warnsEmptyCommit
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }

        UserDefaults.standard.set(warns, forKey: key)
        body()
    }

    /// 修订解析出的对象哈希。
    private func revision(_ name: String, runner: GitRunner) async throws -> String {
        let output = try await runner.run(["rev-parse", name])
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
    }

    /// 提交的标题。
    private func subject(of revision: String, runner: GitRunner) async throws -> String {
        let output = try await runner.run(["log", "-1", "--format=%s", revision, "--"])
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
    }
}
