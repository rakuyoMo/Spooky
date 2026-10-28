import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryTrashTests

/// 丢弃与删除经废纸篓：本机移进废纸篓、撤销时移回、重做时再移进去；服务器上 macOS 的废纸篓脚本在本机执行同一份，核对输出的解析与移回前的核对。
///
/// 移进本机废纸篓的项在测试结束时从废纸篓删除。
@Suite(.serialized)
struct RepositoryTrashTests {
    /// 名字覆盖空格、中文、引号与方括号的未跟踪文件。
    private static let untracked = "新 文件 ' \" [1].txt"

    /// 丢弃把已跟踪的改动恢复到最后一次提交，未跟踪文件移进废纸篓、内容不变；永久删除时不进废纸篓。
    @Test("丢弃：已跟踪的恢复，未跟踪的进废纸篓")
    func discardMovesUntrackedToTrash() async throws {
        let repository = try await committedRepository()
        defer { repository.remove() }
        let service = WorkingCopyOperations(runner: repository.runner)

        try write("changed\n", to: "tracked [*].txt", in: repository)
        try write("new\n", to: Self.untracked, in: repository)

        let trashed = try await service.discard(try await repository.runner.status().entries)
        defer { Self.empty(trashed) }

        #expect(try read("tracked [*].txt", in: repository) == "base\n")
        #expect(trashed.map(\.path) == [repository.directory.appending(path: Self.untracked).path])
        #expect(try String(contentsOfFile: try #require(trashed.first?.location), encoding: .utf8) == "new\n")
        #expect(try await repository.runner.status().entries.isEmpty)

        // 服务器没有废纸篓、用户确认后的永久删除不进废纸篓
        try write("gone\n", to: "gone.txt", in: repository)
        #expect(try await service.discard(try await repository.runner.status().entries, removal: .permanent).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: "gone.txt").path))
    }

    /// 撤销丢弃：未跟踪文件从废纸篓移回原处，已跟踪的改动按快照恢复；重做把它重新移进废纸篓，新的位置记进当前的记录。
    @Test("撤销与重做丢弃：从废纸篓移回，再移进废纸篓")
    func undoDiscardThroughTrash() async throws {
        let repository = try await committedRepository()
        defer { repository.remove() }
        let runner = repository.runner
        let undo = RepositoryUndo(runner: runner)

        try FileManager.default.createDirectory(
            at: repository.directory.appending(path: "目录"),
            withIntermediateDirectories: true
        )
        try write("changed\n", to: "tracked [*].txt", in: repository)
        try write("untracked\n", to: "目录/" + Self.untracked, in: repository)

        let before = try await undo.capture()
        let log = TrashLog()

        try await TrashLog.$current.withValue(log) {
            _ = try await WorkingCopyOperations(runner: runner).discard(try await runner.status().entries)
        }

        let after = try await undo.capture()
        var trashed = log.items
        defer { Self.empty(trashed) }

        #expect(trashed.count == 1)
        #expect(try await undo.canRestore(before, from: after, trashed: trashed))

        try await undo.restore(before, expecting: after, message: "undo", puttingBack: trashed)
        #expect(try await undo.capture() == before)
        #expect(try read("目录/" + Self.untracked, in: repository) == "untracked\n")
        #expect(try read("tracked [*].txt", in: repository) == "changed\n")

        let redo = TrashLog()

        try await TrashLog.$current.withValue(redo) {
            try await undo.restore(after, expecting: before, message: "redo", trashing: trashed)
        }

        trashed = redo.items
        #expect(try await undo.capture() == after)
        #expect(trashed.map(\.path) == log.items.map(\.path))
        #expect(trashed.first?.location.map(FileManager.default.fileExists(atPath:)) ?? false)
    }

    /// 删除已跟踪的文件与整个未跟踪的目录都移进废纸篓；撤销移回原处，内容与状态回到删除前。
    @Test("撤销删除：文件与目录从废纸篓移回")
    func undoDeleteThroughTrash() async throws {
        let repository = try await committedRepository()
        defer { repository.remove() }
        let runner = repository.runner
        let undo = RepositoryUndo(runner: runner)

        try FileManager.default.createDirectory(
            at: repository.directory.appending(path: "build [x]"),
            withIntermediateDirectories: true
        )
        try write("a\n", to: "build [x]/a.o", in: repository)
        try write("b\n", to: "build [x]/b.o", in: repository)

        let before = try await undo.capture()
        let log = TrashLog()

        try await TrashLog.$current.withValue(log) {
            _ = try await WorkingCopyOperations(runner: runner).delete(["tracked [*].txt", "build [x]/"])
        }

        let after = try await undo.capture()
        let trashed = log.items
        defer { Self.empty(trashed) }

        #expect(trashed.count == 2)
        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: "build [x]").path))
        #expect(try await undo.canRestore(before, from: after, trashed: trashed))

        try await undo.restore(before, expecting: after, message: "undo", puttingBack: trashed)
        #expect(try await undo.capture() == before)
        #expect(try read("tracked [*].txt", in: repository) == "base\n")
        #expect(try read("build [x]/b.o", in: repository) == "b\n")
    }

    /// 移进废纸篓的项已经不在废纸篓里：撤销被拒绝，仓库保持操作后的样子。
    @Test("废纸篓里的项不在了，撤销被拒绝")
    func trashedItemMissing() async throws {
        let repository = try await committedRepository()
        defer { repository.remove() }
        let runner = repository.runner
        let undo = RepositoryUndo(runner: runner)

        try write("new\n", to: Self.untracked, in: repository)

        let before = try await undo.capture()
        let log = TrashLog()

        try await TrashLog.$current.withValue(log) {
            _ = try await WorkingCopyOperations(runner: runner).discard(try await runner.status().entries)
        }

        let after = try await undo.capture()

        // 用户清空了废纸篓
        Self.empty(log.items)

        await #expect(throws: RepositoryUndoError.trashedItemsUnavailable) {
            try await undo.restore(before, expecting: after, message: "undo", puttingBack: log.items)
        }

        #expect(try await undo.capture() == after)
    }

    /// 服务器上 macOS 的废纸篓脚本在本机执行同一份：输出与路径一一对应，名字里的引号、换行与中文都能取出位置；移回前先核对，原位置被占用时一项也不移动。
    @Test("废纸篓脚本：逐项移进与移回", .enabled(if: FileManager.default.isExecutableFile(atPath: "/usr/bin/trash")))
    func trashScripts() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-trash-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory.appending(path: "目录 x"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let names = ["a \"q\" \" to \".txt", "line\nbreak.txt", "中文 名.txt", "目录 x"]
        let paths = names.map { directory.appending(path: $0).path }

        for path in paths.dropLast() {
            try Data(path.utf8).write(to: URL(fileURLWithPath: path))
        }

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

        let blocked = try await HostExecution.run(arguments, at: location, writing: true, acceptedExitCodes: [0, 3])
        #expect(blocked.exitCode == 3)
        #expect(items.allSatisfy { $0.location.map(FileManager.default.fileExists(atPath:)) ?? false })

        try FileManager.default.removeItem(atPath: paths[2])

        _ = try await HostExecution.run(arguments, at: location, writing: true)
        #expect(try String(contentsOfFile: paths[1], encoding: .utf8) == paths[1])
        #expect(FileManager.default.fileExists(atPath: paths[3]))
        #expect(items.allSatisfy { !($0.location.map(FileManager.default.fileExists(atPath:)) ?? true) })
    }

    /// `/usr/bin/trash -v` 每一项的输出取出废纸篓里的位置；格式不符、不是绝对路径或缺少的项没有位置。
    @Test("废纸篓脚本的输出解析")
    func trashOutput() {
        let paths = ["/r/a \"b\" c.txt", "/r/x", "/r/y", "/r/z"]
        let output = "# Moved \"/r/a \"b\" c.txt\" to \"/Users/u/.Trash/a \"b\" c.txt 10-20-30-400.txt\"\n\u{0}"
            + "unexpected\n\u{0}"
            + "# Moved \"/r/y\" to \"relative\"\n\u{0}"
        let items = RemoteConnection.trashedItems(paths, output: Data(output.utf8))

        #expect(items.map(\.path) == paths)
        #expect(items.map(\.location) == ["/Users/u/.Trash/a \"b\" c.txt 10-20-30-400.txt", nil, nil, nil])
    }

    /// 体检记下的废纸篓程序：认得出的三种写法，以及体检脚本在本机执行时找到的系统程序。
    @Test("体检找到的废纸篓程序")
    func environmentTrash() async throws {
        #expect(RemoteTrash(probe: "trash:/usr/bin/trash") == .macOS)
        #expect(RemoteTrash(probe: "gio:/usr/bin/gio") == .gio("/usr/bin/gio"))
        #expect(RemoteTrash(probe: "trash-put:/home/b/.local/bin/trash-put") == .trashPut("/home/b/.local/bin/trash-put"))

        for probe in ["", "gio:relative", "trash:/opt/trash", "rm:/bin/rm"] {
            #expect(RemoteTrash(probe: probe) == nil)
        }

        let result = try await HostExecution.run(["/bin/sh", "-c", RemoteHostEnvironment.script], at: .local(path: "/"))
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

    /// 写入仓库内的文件。
    private func write(_ content: String, to path: String, in repository: TemporaryRepository) throws {
        try Data(content.utf8).write(to: repository.directory.appending(path: path))
    }

    /// 读取仓库内的文件。
    private func read(_ path: String, in repository: TemporaryRepository) throws -> String {
        String(decoding: try Data(contentsOf: repository.directory.appending(path: path)), as: UTF8.self)
    }
}
