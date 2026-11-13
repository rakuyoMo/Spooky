import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryTrashTests

/// 丢弃与删除经废纸篓：本机移进废纸篓、撤销时移回、重做时再移进去；
/// 服务器上 macOS 的废纸篓脚本在本机执行同一份，核对输出的解析与移回前的核对。
///
/// 移进本机废纸篓的项在测试结束时从废纸篓删除。
@Suite(.serialized)
struct RepositoryTrashTests {
    /// 名字覆盖空格、中文、引号与方括号的未跟踪文件。
    private static let untracked = "新 文件 ' \" [1].txt"

    /// 删除测试里的已跟踪文件：未修改、已暂存、部分暂存、assume-unchanged，以及目录里名字带方括号的文件。
    private static let tracked = ["tracked [*].txt", "staged.txt", "partial.txt", "assumed.txt", "dir/[x].txt"]

    /// 丢弃把已跟踪的改动恢复到最后一次提交，未跟踪文件移进废纸篓、内容不变；撤销从废纸篓移回原处，
    /// 重做再移进废纸篓并记下新的位置；废纸篓里的项不在了时撤销被拒绝，仓库保持操作后的样子；
    /// 永久删除时不进废纸篓。
    @Test("丢弃经废纸篓的撤销、重做与失效")
    func discardThroughTrash() async throws {
        let repository = try await committedRepository()
        defer { repository.remove() }

        let runner = repository.runner
        let service = WorkingCopyOperations(runner: runner)
        let undo = RepositoryUndo(runner: runner)
        let untracked = "目录/" + Self.untracked

        try FileManager.default.createDirectory(
            at: repository.directory.appending(path: "目录"),
            withIntermediateDirectories: true
        )
        try write("changed\n", to: "tracked [*].txt", in: repository)
        try write("untracked\n", to: untracked, in: repository)

        // 丢弃：已跟踪的恢复，未跟踪的进废纸篓，当前的记录收到同样的项
        let before = try await undo.capture()
        let log = TrashLog()

        var trashed = try await TrashLog.$current.withValue(log) {
            try await service.discard(try await runner.status().entries)
        }
        defer { Self.empty(trashed) }

        let after = try await undo.capture()
        let location = try #require(trashed.first?.location)

        #expect(trashed.map(\.path) == [repository.directory.appending(path: untracked).path])
        #expect(log.items.map(\.location) == trashed.map(\.location))
        #expect(try String(contentsOfFile: location, encoding: .utf8) == "untracked\n")
        #expect(try read("tracked [*].txt", in: repository) == "base\n")
        #expect(try await runner.status().entries.isEmpty)
        #expect(try await undo.canRestore(before, from: after, trashed: trashed))

        // 撤销：未跟踪文件从废纸篓移回原处，已跟踪的改动按快照恢复
        try await undo.restore(before, expecting: after, message: "undo", puttingBack: trashed)
        #expect(try await undo.capture() == before)
        #expect(try read(untracked, in: repository) == "untracked\n")
        #expect(try read("tracked [*].txt", in: repository) == "changed\n")

        // 重做：重新移进废纸篓，新的位置记进当前的记录
        let redo = TrashLog()

        try await TrashLog.$current.withValue(redo) {
            try await undo.restore(after, expecting: before, message: "redo", trashing: trashed)
        }

        trashed = redo.items
        #expect(try await undo.capture() == after)
        #expect(trashed.map(\.path) == log.items.map(\.path))
        #expect(trashed.first?.location.map(FileManager.default.fileExists(atPath:)) ?? false)

        // 用户清空了废纸篓：撤销被拒绝，仓库保持重做后的样子
        Self.empty(trashed)

        await #expect(throws: RepositoryUndoError.trashedItemsUnavailable) {
            try await undo.restore(before, expecting: after, message: "undo", puttingBack: trashed)
        }
        #expect(try await undo.capture() == after)

        // 服务器没有废纸篓、用户确认后的永久删除不进废纸篓
        try write("gone\n", to: "gone.txt", in: repository)

        let removed = try await service.discard(try await runner.status().entries, removal: .permanent)
        #expect(removed.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: "gone.txt").path))
    }

    /// 删除把其中的已跟踪文件同时从索引移除：未修改、已暂存、部分暂存、assume-unchanged 与名字带方括号的文件
    /// 都成为已暂存的删除，未跟踪的文件与目录只移进废纸篓；撤销移回原处，索引项、已暂存的内容与
    /// assume-unchanged 标记都回到删除前；删除的文件又出现在索引里时撤销被拒绝，什么都不动。
    @Test("删除并暂存删除，撤销恢复索引与标记")
    func deleteStagesDeletion() async throws {
        let repository = try await stagingRepository()
        defer { repository.remove() }

        let runner = repository.runner
        let service = WorkingCopyOperations(runner: runner)
        let paths = Self.tracked + ["new.txt", "build [x]/"]

        try FileManager.default.createDirectory(
            at: repository.directory.appending(path: "build [x]"),
            withIntermediateDirectories: true
        )
        try write("new\n", to: "new.txt", in: repository)
        try write("a\n", to: "build [x]/a.o", in: repository)

        let index = try await runner.run(["ls-files", "-s", "-v", "-z"])
        let entries = try await service.trackedIndexEntries(under: paths)
        let log = TrashLog()

        try await TrashLog.$current.withValue(log) { _ = try await service.delete(paths) }

        let trashed = log.items
        defer { Self.empty(trashed) }

        // 已跟踪的都成为已暂存的删除，未跟踪的只移走
        let status = try await runner.status().entries

        #expect(trashed.count == paths.count)
        #expect(status.map(\.path).sorted() == Self.tracked.sorted())
        #expect(status.allSatisfy { $0.staged == .deleted && $0.unstaged == nil })

        // 撤销：移回原处，索引与 assume-unchanged 标记回到删除前，工作区里的内容来自废纸篓
        try await service.restoreDeleted(trashed, entries: entries)

        #expect(try await runner.run(["ls-files", "-s", "-v", "-z"]) == index)
        #expect(try read("partial.txt", in: repository) == "worktree\n")
        #expect(try read("assumed.txt", in: repository) == "hidden\n")
        #expect(try read("build [x]/a.o", in: repository) == "a\n")

        // 再删一次后在原路径暂存了新文件：撤销被拒绝，废纸篓里的项没动
        let single = try await service.trackedIndexEntries(under: ["staged.txt"])
        let again = TrashLog()

        try await TrashLog.$current.withValue(again) { _ = try await service.delete(["staged.txt"]) }
        defer { Self.empty(again.items) }

        try write("other\n", to: "staged.txt", in: repository)
        _ = try await runner.run(["add", "--", "staged.txt"])

        await #expect(throws: RepositoryUndoError.repositoryChanged) {
            try await service.restoreDeleted(again.items, entries: single)
        }
        #expect(again.items.allSatisfy { $0.location.map(FileManager.default.fileExists(atPath:)) ?? false })
    }

    /// 删除没有全部完成时如实报告：有一项移不走时只列出已移走的项，索引不动；
    /// 都已移进废纸篓、索引被锁住时报告删除没有暂存，文件留在废纸篓里。
    @Test("删除中途失败的报告")
    func partialDeletion() async throws {
        let repository = try await stagingRepository()
        defer { repository.remove() }

        let runner = repository.runner
        let service = WorkingCopyOperations(runner: runner)
        let locked = repository.directory.appending(path: "locked")

        // 只读目录里的文件移不走，排在它前面的文件已永久删除
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try write("x\n", to: "locked/x.txt", in: repository)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        let partial = try await #require(throws: FileDeletionError.self) {
            try await service.delete(["partial.txt", "locked/x.txt"], removal: .permanent)
        }

        #expect(partial.removed == ["partial.txt"])
        #expect(!partial.removedAll)
        #expect(FileManager.default.fileExists(atPath: locked.appending(path: "x.txt").path))
        #expect(try await runner.status().entries.first { $0.path == "partial.txt" }?.unstaged == .deleted)

        // 索引被锁住：文件已在废纸篓里，删除没有暂存
        let lock = repository.directory.appending(path: ".git/index.lock")
        let log = TrashLog()

        try Data().write(to: lock)

        let unstaged = try await #require(throws: FileDeletionError.self) {
            try await TrashLog.$current.withValue(log) { _ = try await service.delete(["tracked [*].txt"]) }
        }
        defer { Self.empty(log.items) }

        try FileManager.default.removeItem(at: lock)

        #expect(unstaged.removed == ["tracked [*].txt"])
        #expect(unstaged.removedAll)
        #expect(log.items.count == 1)
        #expect(try await runner.status().entries.first { $0.path == "tracked [*].txt" }?.unstaged == .deleted)
    }

    /// 服务器上 macOS 的废纸篓脚本在本机执行同一份：输出与路径一一对应，名字里的引号、换行与中文都能取出位置；
    /// 移回前先核对，原位置被占用时一项也不移动。
    @Test(
        "废纸篓脚本：逐项移进与移回",
        .enabled(if: FileManager.default.isExecutableFile(atPath: "/usr/bin/trash"))
    )
    func trashScripts() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-trash-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(
            at: directory.appending(path: "目录 x"),
            withIntermediateDirectories: true
        )

        let names = ["a \"q\" \" to \".txt", "line\nbreak.txt", "中文 名.txt", "目录 x"]
        let paths = names.map { directory.appending(path: $0).path }

        for path in paths.dropLast() {
            try Data(path.utf8).write(to: URL(fileURLWithPath: path))
        }

        // 逐项移进废纸篓，输出里取出每一项的位置
        let location = RepositoryLocation.local(path: directory.path)
        let moved = try await HostExecution.run(
            ["/bin/sh", "-c", RemoteConnection.trashScript, "spooky-trash"] + paths,
            at: location,
            writing: true
        )
        let items = RemoteConnection.trashedItems(paths, output: moved.standardOutput)
        defer { Self.empty(items) }

        #expect(items.map(\.path) == paths)
        #expect(items.allSatisfy { $0.location.map(FileManager.default.fileExists(atPath:)) ?? false })
        #expect(paths.allSatisfy { !FileManager.default.fileExists(atPath: $0) })

        let arguments = ["/bin/sh", "-c", RemoteConnection.putBackScript, "spooky-put-back"]
            + items.flatMap { [$0.location ?? "", $0.path] }

        // 原位置已被占用：以 3 退出，废纸篓里的项都没动
        try Data("occupied".utf8).write(to: URL(fileURLWithPath: paths[2]))

        let blocked = try await HostExecution.run(
            arguments,
            at: location,
            writing: true,
            acceptedExitCodes: [0, 3]
        )
        #expect(blocked.exitCode == 3)
        #expect(items.allSatisfy { $0.location.map(FileManager.default.fileExists(atPath:)) ?? false })

        // 腾出原位置后全部移回
        try FileManager.default.removeItem(atPath: paths[2])

        _ = try await HostExecution.run(arguments, at: location, writing: true)
        #expect(try String(contentsOfFile: paths[1], encoding: .utf8) == paths[1])
        #expect(FileManager.default.fileExists(atPath: paths[3]))
        #expect(items.allSatisfy { !($0.location.map(FileManager.default.fileExists(atPath:)) ?? true) })
    }

    /// `/usr/bin/trash -v` 每一项的输出取出废纸篓里的位置，格式不符、不是绝对路径或缺少的项没有位置；
    /// 体检记下的废纸篓程序认得出三种写法，体检脚本在本机执行时找到系统程序。
    @Test("废纸篓脚本的输出与体检找到的程序")
    func trashOutputAndProgram() async throws {
        let paths = ["/r/a \"b\" c.txt", "/r/x", "/r/y", "/r/z"]
        let output = "# Moved \"/r/a \"b\" c.txt\" to \"/Users/u/.Trash/a \"b\" c.txt 10-20-30-400.txt\"\n\u{0}"
            + "unexpected\n\u{0}"
            + "# Moved \"/r/y\" to \"relative\"\n\u{0}"
        let items = RemoteConnection.trashedItems(paths, output: Data(output.utf8))

        #expect(items.map(\.path) == paths)
        #expect(items.map(\.location) == ["/Users/u/.Trash/a \"b\" c.txt 10-20-30-400.txt", nil, nil, nil])

        // 体检输出里认得出的三种程序，其余写法都不算
        #expect(RemoteTrash(probe: "trash:/usr/bin/trash") == .macOS)
        #expect(RemoteTrash(probe: "gio:/usr/bin/gio") == .gio("/usr/bin/gio"))
        #expect(
            RemoteTrash(probe: "trash-put:/home/b/.local/bin/trash-put")
                == .trashPut("/home/b/.local/bin/trash-put")
        )

        for probe in ["", "gio:relative", "trash:/opt/trash", "rm:/bin/rm"] {
            #expect(RemoteTrash(probe: probe) == nil)
        }

        // 体检脚本在本机执行，系统有废纸篓程序时记为 macOS
        let result = try await HostExecution.run(
            ["/bin/sh", "-c", RemoteHostEnvironment.script],
            at: .local(path: "/")
        )
        let environment = try #require(RemoteHostEnvironment(output: result.standardOutput, excluding: []))
        let expected: RemoteTrash? = FileManager.default.isExecutableFile(atPath: "/usr/bin/trash") ? .macOS : nil

        #expect(environment.trash == expected)
    }
}

// MARK: - Helpers

extension RepositoryTrashTests {
    /// 从废纸篓删除测试移进去的项。
    private static func empty(_ items: [TrashedItem]) {
        for location in items.compactMap(\.location) {
            try? FileManager.default.removeItem(atPath: location)
        }
    }

    /// 有一个已提交文件的临时仓库。
    private func committedRepository() async throws -> TemporaryRepository {
        let repository = try TemporaryRepository()
        try await repository.initialize()

        try write("base\n", to: "tracked [*].txt", in: repository)
        _ = try await repository.runner.run(["add", "--all"])
        _ = try await repository.runner.run(["commit", "-q", "-m", "base"])

        return repository
    }

    /// 有 ``tracked`` 各文件的临时仓库：`staged.txt` 有已暂存的改动，`partial.txt` 暂存后又改了工作区，
    /// `assumed.txt` 标为 assume-unchanged 后有看不到的改动。
    private func stagingRepository() async throws -> TemporaryRepository {
        let repository = try await committedRepository()
        let runner = repository.runner

        try FileManager.default.createDirectory(
            at: repository.directory.appending(path: "dir"),
            withIntermediateDirectories: true
        )

        for path in Self.tracked.dropFirst() {
            try write("base\n", to: path, in: repository)
        }

        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "files"])

        // 已暂存的改动与部分暂存
        try write("staged\n", to: "staged.txt", in: repository)
        try write("index\n", to: "partial.txt", in: repository)
        _ = try await runner.run(["add", "--", "staged.txt", "partial.txt"])
        try write("worktree\n", to: "partial.txt", in: repository)

        // assume-unchanged 之后的改动 Git 看不到
        _ = try await runner.run(["update-index", "--assume-unchanged", "--", "assumed.txt"])
        try write("hidden\n", to: "assumed.txt", in: repository)

        return repository
    }

    /// 写入仓库内的文件。
    private func write(_ content: String, to path: String, in repository: TemporaryRepository) throws {
        try Data(content.utf8).write(to: repository.directory.appending(path: path))
    }

    /// 读取仓库内的文件。
    private func read(_ path: String, in repository: TemporaryRepository) throws -> String {
        String(decoding: try Data(contentsOf: repository.directory.appending(path: path)), as: UTF8.self)
    }
}
