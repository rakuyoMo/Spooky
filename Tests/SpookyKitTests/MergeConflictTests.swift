import Foundation
import Testing

@testable import SpookyKit

// MARK: - MergeConflictTests

/// 用真实 Git 在临时仓库里构造合并、变基、摘取与反转的冲突，验证冲突向导读到的内容和每个写入的结果。
struct MergeConflictTests {
    /// 向导显示的三方内容必须与索引一致；采用一侧前的备份不能覆盖用户已有的同名文件，清理只删除向导生成的备份。
    @Test("合并冲突：三方内容、采用一侧时保留备份与清理备份")
    func mergeWizard() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let path = "冲突 '文件' [*].txt"
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

        // 合并的我方是当前 HEAD，对方是被合并的提交，还没有解决任何冲突
        let progress = try #require(try await service.context(head: status.branch.oid).progress)

        #expect(progress.state == .merge)
        #expect(progress.ours == status.branch.oid)
        #expect(progress.theirs == side)
        #expect(progress.resolvedPaths.isEmpty)

        // 用户自己的同名 .orig 文件保持原样，备份换用下一个名字
        let existing = repository.directory.appending(path: path + ".orig")
        try Data("user file\n".utf8).write(to: existing)

        let recorder = BackupRecorder()
        try await service.resolve([entry], theirs: true) { await recorder.add($0) }
        let backups = await recorder.paths

        #expect(backups == [path + ".1.orig"])
        #expect(try Data(contentsOf: repository.directory.appending(path: path + ".1.orig")) == marked)
        #expect(try Data(contentsOf: existing) == Data("user file\n".utf8))
        #expect(try Data(contentsOf: repository.directory.appending(path: path)) == Data("theirs\n".utf8))

        // 解决之后，resolve-undo 记录让横幅能数出已解决的冲突
        let resolved = try #require(try await service.context(head: status.branch.oid).progress)
        #expect(resolved.resolvedPaths == [path])

        try await service.removeBackups(backups + ["missing.orig"])

        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: path + ".1.orig").path))
        #expect(FileManager.default.fileExists(atPath: existing.path))
    }

    /// 恢复只改工作区，文件仍是冲突；手动编辑在文件被外部改过时拒绝覆盖；标记解决后还能重新生成冲突。
    @Test("恢复冲突版本与手动编辑")
    func restoreAndEdit() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let path = "file.txt"
        let file = repository.directory.appending(path: path)
        _ = try await diverge(repository, base: [path: "base\n"], ours: [path: "ours\n"], theirs: [path: "theirs\n"])
        _ = try await repository.runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: repository.runner)
        let entry = try #require(try await repository.runner.status().entries.first)

        try await service.restoreConflicts([entry], to: .ours)
        #expect(try Data(contentsOf: file) == Data("ours\n".utf8))
        #expect(try await repository.runner.status().entries.first?.kind == .conflicted)

        try await service.restoreConflicts([entry], to: .base)
        #expect(try Data(contentsOf: file) == Data("base\n".utf8))

        try await service.restoreConflicts([entry], to: .unmerged)
        #expect(String(decoding: try Data(contentsOf: file), as: UTF8.self).contains(">>>>>>>"))

        // 手动编辑：载入时的内容与磁盘一致才写入
        let loaded = try Data(contentsOf: file)
        try await service.saveResolution(Data("edited\n".utf8), for: entry, replacing: loaded)
        #expect(try Data(contentsOf: file) == Data("edited\n".utf8))

        // 其它程序在载入之后改了文件，编辑结果不能覆盖它
        try Data("external\n".utf8).write(to: file)

        await #expect(throws: ConflictResolutionError.fileChanged) {
            try await service.saveResolution(Data("mine\n".utf8), for: entry, replacing: Data("edited\n".utf8))
        }

        #expect(try Data(contentsOf: file) == Data("external\n".utf8))

        // 标记解决之后，Git 的 resolve-undo 记录仍能重新生成冲突
        try await service.stage([entry], staged: true)
        #expect(try await repository.runner.status().entries.allSatisfy { $0.kind != .conflicted })

        try await service.restoreConflicts([entry], to: .unmerged)
        #expect(try await repository.runner.status().entries.first?.kind == .conflicted)
    }

    /// 缺少一侧的冲突也要能读、能解决；二进制内容原样取回；没有的版本拒绝恢复。
    @Test("删改冲突、两侧新增与二进制冲突")
    func otherConflictKinds() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        _ = try await diverge(
            repository,
            base: ["deleted.txt": "base\n", "binary.bin": "\0base"],
            ours: ["deleted.txt": "ours\n", "binary.bin": "\0ours", "added.txt": "ours\n"],
            theirs: ["deleted.txt": nil, "binary.bin": "\0theirs", "added.txt": "theirs\n"]
        )

        _ = try await repository.runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: repository.runner)
        let entries = Dictionary(uniqueKeysWithValues: try await repository.runner.status().entries.map { ($0.path, $0) })
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

        let remaining = try await repository.runner.status().entries.filter { $0.kind == .conflicted }
        #expect(remaining.map(\.path) == ["added.txt"])
    }

    /// 继续之后停在下一步的冲突上，Git 以失败退出，状态文件仍显示进行中，不能当作变基已经完成。
    @Test("变基冲突：步数与标题，继续后停在下一步仍是进行中")
    func rebaseSteps() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        try await commit(repository, ["f": "base\n", "g": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "feature"])
        try await commit(repository, ["f": "f1\n"], message: "feature one")
        try await commit(repository, ["g": "g2\n"], message: "feature two")
        let original = try #require(try await runner.status().branch.oid)

        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["f": "main\n", "g": "main\n"], message: "main")
        let onto = try #require(try await runner.status().branch.oid)

        _ = try await runner.run(["checkout", "-q", "feature"])
        _ = try await runner.execute(["rebase", "main"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: runner)
        let first = try #require(try await service.context(head: try await runner.status().branch.oid).progress)

        #expect(first.state == .rebase)
        #expect(first.step == 1 && first.stepCount == 2)
        #expect(first.stepSubject == "feature one")
        #expect(first.branch == "refs/heads/feature")
        #expect(first.ours == onto && first.theirs == original)

        // 变基时对方是正在重放的提交
        try await service.resolve(try await runner.status().entries, theirs: true)
        #expect(try Data(contentsOf: repository.directory.appending(path: "f")) == Data("f1\n".utf8))

        await #expect(throws: GitError.self) {
            try await service.finish(.rebase, action: "continue")
        }

        let second = try #require(try await service.context(head: try await runner.status().branch.oid).progress)

        #expect(second.step == 2 && second.stepSubject == "feature two")
        #expect(second.resolvedPaths.isEmpty)
        #expect(try await runner.status().entries.contains { $0.kind == .conflicted })

        try await service.finish(.rebase, action: "abort")
        #expect(try await service.context(head: try await runner.status().branch.oid).progress == nil)
        #expect(try await runner.status().branch.oid == original)
    }

    /// 摘取序列的步数从已完成的提交数出；这一步解决后没有改动时，继续保留一个沿用原作者与信息的空提交。
    @Test("摘取序列：步数与空的一步继续")
    func cherryPickSequence() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        try await commit(repository, ["x": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "picked"])
        try await commit(repository, ["x": "picked\n"], message: "pick me", author: "Original Author")
        try await commit(repository, ["y": "second\n"], message: "second", author: "Original Author")
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["x": "main\n"], message: "main")

        _ = try await runner.execute(["cherry-pick", "picked~1", "picked"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: runner)
        let progress = try #require(try await service.context(head: try await runner.status().branch.oid).progress)

        #expect(progress.state == .cherryPick)
        #expect(progress.step == 1 && progress.stepCount == 2)
        #expect(progress.stepSubject == "pick me")

        // 采用我方后这一步与 HEAD 相同
        try await service.resolve(try await runner.status().entries, theirs: false)
        try await service.finish(.cherryPick, action: "continue")

        #expect(try await service.context(head: try await runner.status().branch.oid).operation == nil)

        let log = String(decoding: try await runner.run(["log", "-3", "--format=%an|%s"]), as: UTF8.self)
        #expect(log == "Original Author|second\nOriginal Author|pick me\nSpooky Test|main\n")
    }

    /// 反转的对方是被反转的提交；中止回到反转之前的 HEAD。
    @Test("反转冲突的识别与中止")
    func revertConflict() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        try await commit(repository, ["x": "base\n"], message: "base")
        try await commit(repository, ["x": "changed\n"], message: "change")
        let reverted = try #require(try await runner.status().branch.oid)
        try await commit(repository, ["x": "again\n"], message: "again")
        let head = try #require(try await runner.status().branch.oid)

        _ = try await runner.execute(["revert", "--no-edit", reverted], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: runner)
        let progress = try #require(try await service.context(head: head).progress)

        #expect(progress.state == .revert)
        #expect(progress.theirs == reverted && progress.ours == head)
        #expect(progress.stepKind == .reverting)

        try await service.finish(.revert, action: "abort")
        #expect(try await service.context(head: head).operation == nil)
        #expect(try await runner.status().branch.oid == head)
    }

    /// merge 后端的变基在空的一步上继续，同样保留空提交并完成后面的步骤。
    @Test("变基的空的一步继续时保留空提交")
    func emptyRebaseStep() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let runner = repository.runner
        try await commit(repository, ["x": "base\n"], message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "feature"])
        try await commit(repository, ["x": "feature\n"], message: "conflicting", author: "Original Author")
        try await commit(repository, ["y": "after\n"], message: "after")
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["x": "main\n"], message: "main")
        _ = try await runner.run(["checkout", "-q", "feature"])
        _ = try await runner.execute(["rebase", "main"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: runner)

        // 变基时我方是 main，采用它之后这一步没有改动
        try await service.resolve(try await runner.status().entries, theirs: false)
        try await service.finish(.rebase, action: "continue")

        #expect(try await service.context(head: try await runner.status().branch.oid).operation == nil)

        let log = String(decoding: try await runner.run(["log", "-3", "--format=%an|%s"]), as: UTF8.self)
        #expect(log == "Spooky Test|after\nOriginal Author|conflicting\nSpooky Test|main\n")
    }
}

// MARK: - Helpers

extension MergeConflictTests {
    /// 收集备份回调交出的路径。
    private actor BackupRecorder {
        /// 已经交出的备份路径。
        private(set) var paths: [String] = []

        /// 追加一批备份路径。
        func add(_ new: [String]) {
            paths += new
        }
    }

    /// 从同一个基础提交分出 main 与 side 两侧，各自提交一次；值为 nil 的文件在那一侧被删除。
    ///
    /// - Returns: side 分支的提交，结束时检出 main。
    private func diverge(
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
    private func commit(
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
