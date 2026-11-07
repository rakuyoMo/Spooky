import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 进行中的操作没有任何改动时的空提交确认：单个操作与序列各自按钮的 Git 结果、关掉警告后直接保留空提交，以及什么时候不算空。
extension RepositorySessionTests {
    /// 单个摘取解决后没有任何改动：可以提交，提交前先确认，确认之前不执行 Git；保留后建出带编辑后信息的空提交并结束摘取。
    @Test("单个操作保留空提交")
    func emptySingleCommit() async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await stopEmptyCherryPick(session, in: directory, runner: runner)

        var requests: [EmptyCommitRequest] = []
        session.onEmptyCommitPrompt = { requests.append($0) }

        let head = try await revision("HEAD", runner: runner)

        #expect(session.commitsEmpty && session.canCommit)

        session.setMessage("空的摘取")
        withEmptyCommitWarning(true) { session.commit() }

        // 确认框还开着时什么也不执行，Cancel 就是不选任何动作
        #expect(requests.map(\.isSequence) == [false])

        try await reload(session) { true }

        #expect(session.context?.operation == .cherryPick)
        #expect(try await revision("HEAD", runner: runner) == head)

        requests.first?.commit()
        await session.writeTask?.value
        try await reload(session) { session.context != nil && session.context?.operation == nil }

        // 空提交与它的父提交是同一棵树
        let tree = try await revision("HEAD~1^{tree}", runner: runner)

        #expect(try await revision("HEAD~1", runner: runner) == head)
        #expect(try await revision("HEAD^{tree}", runner: runner) == tree)
        #expect(try await subject(of: "HEAD", runner: runner) == "空的摘取")
    }

    /// 合并解决后没有任何改动：确认框的备选中止合并，回到合并前的提交，工作区没有改动。
    @Test("单个操作中止")
    func emptySingleAbort() async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try await commitFiles(["x": "side"], message: "side", in: directory, runner: runner)
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commitFiles(["x": "main"], message: "main", in: directory, runner: runner)

        _ = try await runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])
        try await reload(session) { session.conflictCount == 1 && session.context?.operation == .merge }
        try await resolveAll(session, theirs: false)
        try await reload(session) { session.commitsEmpty }

        var requests: [EmptyCommitRequest] = []
        session.onEmptyCommitPrompt = { requests.append($0) }

        let head = try await revision("HEAD", runner: runner)

        session.setMessage("合并")
        withEmptyCommitWarning(true) { session.commit() }

        #expect(requests.map(\.isSequence) == [false])

        requests.first?.alternate()
        await session.writeTask?.value
        try await reload(session) { session.context != nil && session.context?.operation == nil }

        #expect(try await revision("HEAD", runner: runner) == head)
        #expect(session.status?.entries.isEmpty ?? false)
    }

    /// 摘取序列的一步解决后没有任何改动：继续前先确认；保留时这一步成为带编辑后信息的空提交，跳过时没有这一步，两种都接着摘取后面的提交。
    @Test("序列的空步骤保留或跳过", arguments: [true, false])
    func emptySequenceStep(keeps: Bool) async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
        _ = try await runner.run(["checkout", "-q", "-b", "picked"])
        try await commitFiles(["x": "one"], message: "one", in: directory, runner: runner)
        try await commitFiles(["y": "two"], message: "two", in: directory, runner: runner)
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commitFiles(["x": "main"], message: "main", in: directory, runner: runner)

        let head = try await revision("HEAD", runner: runner)

        // 第一步冲突，采用我方后这一步没有改动
        _ = try await runner.execute(["cherry-pick", "picked~1", "picked"], acceptedExitCodes: [1])
        try await reload(session) {
            session.conflictCount == 1 && (session.context?.progress?.isSequence ?? false)
        }
        try await resolveAll(session, theirs: false)
        try await reload(session) { session.commitsEmpty }

        var requests: [EmptyCommitRequest] = []
        session.onEmptyCommitPrompt = { requests.append($0) }

        session.setMessage("保留的空步骤")
        withEmptyCommitWarning(true) { session.continueSequence() }

        #expect(requests.map(\.isSequence) == [true])

        if keeps {
            requests.first?.commit()
        } else {
            requests.first?.alternate()
        }

        await session.writeTask?.value
        try await reload(session) { session.context != nil && session.context?.operation == nil }

        let log = String(decoding: try await runner.run(["log", "--format=%s", "\(head)..HEAD"]), as: UTF8.self)

        #expect(log == (keeps ? "two\n保留的空步骤\n" : "two\n"))
    }

    /// 关掉空提交警告后不再确认，提交直接保留空提交。
    @Test("关掉警告时直接保留空提交")
    func emptyCommitWithoutWarning() async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await stopEmptyCherryPick(session, in: directory, runner: runner)

        var requests: [EmptyCommitRequest] = []
        session.onEmptyCommitPrompt = { requests.append($0) }

        let head = try await revision("HEAD", runner: runner)

        session.setMessage("不再确认")
        withEmptyCommitWarning(false) { session.commit() }

        #expect(requests.isEmpty)

        await session.writeTask?.value
        try await reload(session) { session.context != nil && session.context?.operation == nil }

        #expect(try await revision("HEAD~1", runner: runner) == head)
        #expect(try await subject(of: "HEAD", runner: runner) == "不再确认")
    }

    /// 未跟踪的文件与未暂存的修改都是改动，不算空提交；这时没有暂存的改动也不能提交。
    @Test("有改动时不算空提交")
    func emptyCommitConditions() async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await stopEmptyCherryPick(session, in: directory, runner: runner)
        session.setMessage("message")

        #expect(session.commitsEmpty && session.canCommit)

        let note = directory.appending(path: "note.txt")
        try Data("note".utf8).write(to: note)
        try await reload(session) { !session.isWorkingCopyClean }

        #expect(!session.commitsEmpty && !session.canCommit)

        try FileManager.default.removeItem(at: note)
        try Data("changed\n".utf8).write(to: directory.appending(path: "x"))
        try await reload(session) { session.status?.entries.map(\.path) == ["x"] }

        #expect(!session.commitsEmpty && !session.canCommit)
    }

    /// 停在 edit 上时工作区没有任何改动也不算空提交：提交区的 Commit 修订当前提交，结束编辑交给 Git 继续。
    @Test("edit 停顿不算空提交")
    func emptyCommitAtEditStop() async throws {
        let (session, directory, runner) = try await openOperationRepository()
        defer { closeOperationRepository(session, directory) }

        try await commitFiles(["x": "one"], message: "one", in: directory, runner: runner)
        try await commitFiles(["y": "two"], message: "two", in: directory, runner: runner)
        try await commitFiles(["z": "three"], message: "three", in: directory, runner: runner)

        let rewrite = RepositoryRewrite(runner: runner)
        try await rewrite.perform(try await rewrite.plan(.edit(try await rewrite.resolve("HEAD~1"))))

        // 停下时重新打开了 two 的改动，删掉它新增的文件后工作区没有任何改动
        try FileManager.default.removeItem(at: directory.appending(path: "y"))

        try await reload(session) {
            (session.context?.progress?.stopsForEdit ?? false) && session.isWorkingCopyClean
        }

        #expect(!session.commitsEmpty)
    }
}

// MARK: - Empty Commit Helpers

extension RepositorySessionTests {
    /// 摘取一个与 main 冲突的提交，采用我方解决后停在没有任何改动的单个摘取上。
    private func stopEmptyCherryPick(_ session: RepositorySession, in directory: URL, runner: GitRunner) async throws {
        try await commitFiles(["x": "base"], message: "base", in: directory, runner: runner)
        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try await commitFiles(["x": "side"], message: "side", in: directory, runner: runner)
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commitFiles(["x": "main"], message: "main", in: directory, runner: runner)

        _ = try await runner.execute(["cherry-pick", "side"], acceptedExitCodes: [1])
        try await reload(session) { session.conflictCount == 1 && session.context?.operation == .cherryPick }
        try await resolveAll(session, theirs: false)
        try await reload(session) { session.commitsEmpty }
    }

    /// 按给定的警告设置同步执行一段操作，再恢复原来的设置；会话在这段同步代码里读取设置，不受并行测试改动它的影响。
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
