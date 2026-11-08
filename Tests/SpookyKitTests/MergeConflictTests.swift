import Foundation
import Testing

@testable import SpookyKit

// MARK: - MergeConflictTests

/// 用真实 Git 在临时仓库里构造合并、变基、摘取与反转的冲突，验证冲突向导读到的内容和每个写入的结果。
struct MergeConflictTests {
    /// 向导显示的三方内容必须与索引一致；合并的对方提交是被合并的提交，预填保留 Git 写下的冲突清单注释；
    /// 恢复只改工作区，文件仍是冲突，恢复成某一侧之外的内容就算手动改过，标记解决后还能重新生成冲突；
    /// 采用一侧后 resolve-undo 记录让横幅能数出已解决的冲突。
    @Test("合并冲突：三方内容、预填信息、恢复冲突版本、手动编辑的识别与采用一侧")
    func mergeWizard() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()

        let path = "冲突 '文件' [*].txt"
        let file = repository.directory.appending(path: path)

        let side = try await diverge(
            repository,
            base: [path: "base\n"],
            ours: [path: "ours\n"],
            theirs: [path: "theirs\n"]
        )

        _ = try await repository.runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: repository.runner)
        let status = try await repository.runner.status()
        let entry = try #require(status.entries.first { $0.path == path })
        let contents = try await service.conflictContents(of: entry)
        let marked = try #require(contents.worktree)

        #expect(contents.base == Data("base\n".utf8))
        #expect(contents.ours == Data("ours\n".utf8))
        #expect(contents.theirs == Data("theirs\n".utf8))
        #expect(String(decoding: marked, as: UTF8.self).contains("<<<<<<<"))

        // Git 刚写入的冲突标记还在，不算手动编辑过
        #expect(!contents.isManuallyEdited)

        // 合并的我方是当前 HEAD，对方是被合并的提交，还没有解决任何冲突
        let context = try await service.context(head: status.branch.oid)
        let progress = try #require(context.progress)

        #expect(progress.state == .merge)
        #expect(progress.ours == status.branch.oid)
        #expect(progress.theirs == side && progress.theirsCommit == side)
        #expect(progress.resolvedPaths.isEmpty)

        // 预填保留 Git 写下的冲突清单注释，交给提交时的注释设置处理
        #expect(context.preparedMessage.hasPrefix("Merge branch 'side'"))
        #expect(context.preparedMessage.contains("# Conflicts:"))

        // 恢复成我方：只改工作区，文件仍是冲突；与我方相同的内容只是一侧的版本，不算手动编辑
        try await service.restoreConflicts([entry], to: .ours)

        #expect(try Data(contentsOf: file) == Data("ours\n".utf8))
        #expect(try await repository.runner.status().entries.first?.kind == .conflicted)
        #expect(try await !service.conflictContents(of: entry).isManuallyEdited)

        // 恢复成共同祖先算手动改过，重新生成冲突标记则不算
        try await service.restoreConflicts([entry], to: .base)

        #expect(try Data(contentsOf: file) == Data("base\n".utf8))
        #expect(try await service.conflictContents(of: entry).isManuallyEdited)

        try await service.restoreConflicts([entry], to: .unmerged)

        #expect(String(decoding: try Data(contentsOf: file), as: UTF8.self).contains(">>>>>>>"))
        #expect(try await !service.conflictContents(of: entry).isManuallyEdited)

        // 在外部编辑器里删掉冲突标记、写成自己的结果
        try Data("edited\n".utf8).write(to: file)

        #expect(try await service.conflictContents(of: entry).isManuallyEdited)

        // 标记解决之后，Git 的 resolve-undo 记录仍能重新生成冲突
        try await service.stage([entry], staged: true)

        #expect(try await repository.runner.status().entries.allSatisfy { $0.kind != .conflicted })

        try await service.restoreConflicts([entry], to: .unmerged)

        #expect(try await repository.runner.status().entries.first?.kind == .conflicted)

        // 采用对方之后，resolve-undo 记录让横幅能数出已解决的冲突
        try await service.resolve([entry], theirs: true)

        #expect(try Data(contentsOf: file) == Data("theirs\n".utf8))

        let resolved = try #require(try await service.context(head: status.branch.oid).progress)

        #expect(resolved.resolvedPaths == [path])
    }

    /// 缺少一侧的冲突也要能读、能解决；二进制内容原样取回；没有的版本拒绝恢复；
    /// 压缩合并的对方没有提交来源，储藏应用冲突时没有进行中的操作。
    @Test("删改冲突、两侧新增、二进制冲突、压缩合并与储藏应用")
    func otherConflictKinds() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let runner = repository.runner

        _ = try await diverge(
            repository,
            base: ["deleted.txt": "base\n", "binary.bin": "\0base"],
            ours: ["deleted.txt": "ours\n", "binary.bin": "\0ours", "added.txt": "ours\n"],
            theirs: ["deleted.txt": nil, "binary.bin": "\0theirs", "added.txt": "theirs\n"]
        )

        _ = try await runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: runner)

        let entries = Dictionary(
            uniqueKeysWithValues: try await runner.status().entries.map { ($0.path, $0) }
        )

        let deleted = try #require(entries["deleted.txt"])
        let binary = try #require(entries["binary.bin"])
        let added = try #require(entries["added.txt"])

        #expect(deleted.conflictKind == .deletedByThem)
        #expect(added.conflictKind == .bothAdded)

        let deletedContents = try await service.conflictContents(of: deleted)

        #expect(deletedContents.theirs == nil)
        #expect(deletedContents.ours == Data("ours\n".utf8))
        #expect(deletedContents.worktree == Data("ours\n".utf8))

        #expect(try await service.conflictContents(of: binary).theirs == Data("\0theirs".utf8))
        #expect(try await service.conflictContents(of: added).base == nil)

        await #expect(throws: ConflictResolutionError.versionUnavailable) {
            try await service.restoreConflicts([added], to: .base)
        }

        // 采用删除了文件的一侧，解决的结果就是删除
        try await service.resolve([deleted], theirs: true)
        try await service.resolve([binary], theirs: true)

        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: "deleted.txt").path))
        #expect(try Data(contentsOf: repository.directory.appending(path: "binary.bin")) == Data("\0theirs".utf8))

        let remaining = try await runner.status().entries.filter { $0.kind == .conflicted }

        #expect(remaining.map(\.path) == ["added.txt"])

        // 压缩合并的对方没有提交来源
        _ = try await runner.run(["reset", "-q", "--hard"])
        _ = try await runner.execute(["merge", "--squash", "side"], acceptedExitCodes: [1])

        #expect(try await currentProgress(repository).theirsCommit == nil)

        // 储藏应用冲突时没有进行中的操作
        _ = try await runner.run(["reset", "-q", "--hard"])
        try Data("stashed\n".utf8).write(to: repository.directory.appending(path: "added.txt"))
        _ = try await runner.run(["stash", "-q"])
        try await commit(repository, ["added.txt": "changed\n"], message: "changed")
        _ = try await runner.execute(["stash", "apply", "-q"], acceptedExitCodes: [1])

        #expect(try await service.context(head: try await runner.status().branch.oid).progress == nil)
    }

    /// 继续之后停在下一步的冲突上，Git 以失败退出，状态文件仍显示进行中，不能当作变基已经完成；
    /// 对方提交是这一步正在重放的提交；空的一步确认保留后，空提交沿用原作者并完成变基。
    @Test("变基冲突：步数、标题与对方提交，继续后停在下一步，空的一步继续时保留空提交")
    func rebaseSteps() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let runner = repository.runner

        try await commit(repository, ["f": "base\n", "g": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "feature"])
        try await commit(repository, ["f": "f1\n"], message: "feature one", author: "Original Author")
        try await commit(repository, ["g": "g2\n"], message: "feature two", author: "Original Author")

        let original = try #require(try await runner.status().branch.oid)
        let featureOne = try await commitID("HEAD~1", in: repository)

        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["f": "main\n", "g": "main\n"], message: "main")

        let onto = try #require(try await runner.status().branch.oid)

        _ = try await runner.run(["checkout", "-q", "feature"])
        _ = try await runner.execute(["rebase", "main"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: runner)
        let first = try await currentProgress(repository)

        #expect(first.state == .rebase)
        #expect(first.step == 1 && first.stepCount == 2)
        #expect(first.stepSubject == "feature one")
        #expect(first.branch == "refs/heads/feature")
        #expect(first.ours == onto && first.theirs == original)
        #expect(first.theirsCommit == featureOne)

        // 变基时对方是正在重放的提交
        try await service.resolve(try await runner.status().entries, theirs: true)

        #expect(try Data(contentsOf: repository.directory.appending(path: "f")) == Data("f1\n".utf8))

        await #expect(throws: GitError.self) {
            try await service.finish(.rebase, action: "continue")
        }

        let second = try await currentProgress(repository)

        #expect(second.step == 2 && second.stepSubject == "feature two")
        #expect(second.theirsCommit == original)
        #expect(second.resolvedPaths.isEmpty)
        #expect(try await runner.status().entries.contains { $0.kind == .conflicted })

        // 我方是 main，采用它之后这一步没有改动，确认保留空提交
        try await service.resolve(try await runner.status().entries, theirs: false)
        try await service.continueSequence(.rebase, subject: "feature two", body: "", allowEmpty: true)

        #expect(try await service.context(head: try await runner.status().branch.oid).operation == nil)

        let log = String(decoding: try await runner.run(["log", "-3", "--format=%an|%s"]), as: UTF8.self)

        #expect(log == "Original Author|feature two\nOriginal Author|feature one\nSpooky Test|main\n")
    }

    /// 摘取序列不记录已完成的步数，只数剩余的提交：三个提交在第二个冲突时剩两个，当前一步是其中第 1 个；
    /// 这一步解决后没有改动时，确认保留的空提交沿用原作者，后面的提交照常摘取。
    @Test("摘取序列：剩余提交数与空的一步继续")
    func cherryPickSequence() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let runner = repository.runner

        try await commit(repository, ["x": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try await commit(repository, ["a": "a\n"], message: "one", author: "Original Author")
        try await commit(repository, ["x": "two\n"], message: "two", author: "Original Author")
        try await commit(repository, ["c": "c\n"], message: "three", author: "Original Author")
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["x": "main\n"], message: "main")

        _ = try await runner.execute(["cherry-pick", "side~2", "side~1", "side"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: runner)
        let progress = try await currentProgress(repository)

        #expect(progress.state == .cherryPick && progress.isSequence)
        #expect(progress.step == 1 && progress.stepCount == 2)
        #expect(progress.stepKind == .applying && progress.stepSubject == "two")
        #expect(progress.theirsCommit == (try await commitID("side~1", in: repository)))

        // 采用我方后这一步与 HEAD 相同
        try await service.resolve(try await runner.status().entries, theirs: false)
        try await service.continueSequence(.cherryPick, subject: "two", body: "", allowEmpty: true)

        #expect(try await service.context(head: try await runner.status().branch.oid).operation == nil)

        let log = String(decoding: try await runner.run(["log", "-4", "--format=%an|%s"]), as: UTF8.self)

        #expect(log == "Original Author|three\nOriginal Author|two\nOriginal Author|one\nSpooky Test|main\n")
    }
}

// MARK: - Helpers

extension MergeConflictTests {
    /// 从同一个基础提交分出 main 与 side 两侧，各自提交一次；值为 nil 的文件在那一侧被删除。
    ///
    /// - Returns: side 分支的提交，结束时检出 main。
    func diverge(
        _ repository: TemporaryRepository,
        base: [String: String?],
        ours: [String: String?],
        theirs: [String: String?]
    ) async throws -> String {
        try await commit(repository, base, message: "base")

        _ = try await repository.runner.run(["checkout", "-q", "-b", "side"])
        try await commit(repository, theirs, message: "theirs")
        let side = try #require(try await repository.runner.status().branch.oid)

        _ = try await repository.runner.run(["checkout", "-q", "main"])
        try await commit(repository, ours, message: "ours")
        return side
    }

    /// 写入或删除文件后提交全部改动。
    ///
    /// - Parameters:
    ///   - files: 相对路径与内容；值为 nil 的文件被删除。
    ///   - author: 提交作者的名字，缺省为仓库配置的身份。
    func commit(
        _ repository: TemporaryRepository,
        _ files: [String: String?],
        message: String,
        author: String? = nil
    ) async throws {
        for (path, content) in files {
            let url = repository.directory.appending(path: path)

            if let content {
                try Data(content.utf8).write(to: url)
            } else {
                try FileManager.default.removeItem(at: url)
            }
        }

        _ = try await repository.runner.run(["add", "-A"])

        let identity = author.map { ["--author=\($0) <author@example.invalid>"] } ?? []
        _ = try await repository.runner.run(["commit", "-q", "-m", message] + identity)
    }
}
