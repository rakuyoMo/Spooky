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

    /// 删除已跟踪的文件与整个未跟踪的目录都移进废纸篓，Git 看到的是未暂存的删除；
    /// 撤销移回原处，内容与状态回到删除前。
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

        // 两项都在废纸篓里，原处没有文件，已跟踪的文件成为未暂存的删除
        let entries = try await runner.status().entries
        #expect(trashed.count == 2)
        #expect(trashed.allSatisfy { $0.location.map(FileManager.default.fileExists(atPath:)) ?? false })
        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: "build [x]").path))
        #expect(entries.map(\.path) == ["tracked [*].txt"])
        #expect(entries.first?.unstaged == .deleted)
        #expect(try await undo.canRestore(before, from: after, trashed: trashed))

        // 撤销后内容与状态回到删除前
        try await undo.restore(before, expecting: after, message: "undo", puttingBack: trashed)
        #expect(try await undo.capture() == before)
        #expect(try read("tracked [*].txt", in: repository) == "base\n")
        #expect(try read("build [x]/b.o", in: repository) == "b\n")
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

    /// 写入仓库内的文件。
    private func write(_ content: String, to path: String, in repository: TemporaryRepository) throws {
        try Data(content.utf8).write(to: repository.directory.appending(path: path))
    }

    /// 读取仓库内的文件。
    private func read(_ path: String, in repository: TemporaryRepository) throws -> String {
        String(decoding: try Data(contentsOf: repository.directory.appending(path: path)), as: UTF8.self)
    }
}
