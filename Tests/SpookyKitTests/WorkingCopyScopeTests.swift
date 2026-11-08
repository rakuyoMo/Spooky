import Foundation
import Testing

@testable import SpookyKit

/// 精确文件范围和乐观快照必须经过实际读取与写入入口验证。
struct WorkingCopyScopeTests {
    /// 正反祖先重命名保留配对，旁支变化不污染补丁或指纹；两个方向各用一种对象格式。
    @Test("祖先重命名的单文件范围", arguments: [(false, "sha1"), (true, "sha256")])
    func ancestorRename(reverse: Bool, objectFormat: String) async throws {
        let fixture = try WorkingCopyScopeFixture(
            oldPath: reverse ? "node/sub/a.txt" : "node",
            newPath: reverse ? "node" : "node/sub/a.txt"
        )
        defer { fixture.repository.remove() }

        try await fixture.prepare(
            objectFormat: objectFormat,
            siblings: reverse ? ["node/side/file", "node/sub/side", "node/sub/deeper/file"] : []
        )
        try fixture.change()

        // 暂存与未暂存两侧都只读出所选文件，暂存侧保留重命名配对
        let entry = try await fixture.entry()
        let staged = try await fixture.service.patch(for: entry, side: .staged, options: DiffOptions())
        let parsed = try RepositoryDiff(patch: staged)
        #expect(parsed.files.count == 1)
        #expect(parsed.files[0].metadata.rename?.oldPath == fixture.oldPath)
        #expect(parsed.files[0].metadata.rename?.newPath == fixture.newPath)

        let snapshot = try await fixture.service.diff(for: entry, side: .unstaged)
        #expect(snapshot.diff?.files.count == 1)

        // 祖先变成目录时，取样之后在它下面加入旁支
        if !reverse {
            for path in ["node/side/one", "node/sub/side", "node/sub/deeper/file"] {
                try fixture.write(Data("sibling\n".utf8), path: path)
            }

            _ = try await fixture.runner.run(["add", "--", "node/side", "node/sub/side", "node/sub/deeper"])
        }

        // 范围外的变化不使快照过期，写入也不碰范围外文件的索引与内容
        try fixture.write(Data("outside changed\n".utf8), path: "outside")
        #expect(try await fixture.service.isCurrent(snapshot))

        let outsideIndex = try await fixture.runner.run(["ls-files", "--stage", "-z", "--", "outside"])
        let hunk = try #require(snapshot.diff?.files.first?.hunks.first)
        try await fixture.service.apply(snapshot, file: 0, hunk: hunk.id)

        let original = Data(WorkingCopyScopeFixture.original.utf8)
        #expect(try await fixture.runner.run(["show", ":" + fixture.newPath]) != original)
        #expect(try await fixture.runner.run(["ls-files", "--stage", "-z", "--", "outside"]) == outsideIndex)
        #expect(try fixture.read("outside") == Data("outside changed\n".utf8))

        // 旁支的工作区与索引保持原样
        if !reverse {
            #expect(try fixture.read("node/sub/deeper/file") == Data("sibling\n".utf8))
            #expect(try await fixture.runner.run(["show", ":node/sub/deeper/file"]) == Data("sibling\n".utf8))
        }
    }

    /// 文件和目录互换时，只读所选叶文件；索引结构冲突保留 Git 正式写入的原始错误。
    @Test("文件与目录互换的读取和写入", arguments: [false, true])
    func fileDirectory(reverse: Bool) async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let root = repository.directory.appending(path: "node")
        let path = reverse ? root.appending(path: "child") : root

        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("original child content\n".utf8).write(to: path)
        _ = try await repository.runner.run(["add", "--all"])
        _ = try await repository.runner.run(["commit", "-qm", "base"])

        // 把提交里的文件换成目录，或把目录换成文件
        try FileManager.default.removeItem(at: root)

        if reverse {
            try Data("new parent\n".utf8).write(to: root)
        } else {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try Data("new unrelated descendant\n".utf8).write(to: root.appending(path: "child"))
            try Data("another descendant\n".utf8).write(to: root.appending(path: "sibling"))
        }

        _ = try await repository.runner.run(["add", "--all"])

        // 暂存侧只有所选文件的一段补丁，未暂存侧为空
        let entry = try #require(try await repository.runner.status().entries.first { $0.path == "node" })
        let service = WorkingCopyOperations(runner: repository.runner)
        let snapshot = try await service.diff(for: entry, side: .staged)
        #expect(snapshot.diff?.files.count == 1)
        #expect(try await service.patch(for: entry, side: .unstaged, options: DiffOptions()).isEmpty)

        if reverse {
            try await service.apply(snapshot, file: 0, hunk: 0)
            #expect(try await repository.runner.run(["ls-files", "--stage", "-z"]).isEmpty)
            #expect(try Data(contentsOf: root) == Data("new parent\n".utf8))
            return
        }

        // 取消暂存会让同名的文件与目录同时进入索引，Git 拒绝时保留原始错误，索引与工作区不变
        let index = try await repository.runner.run(["ls-files", "--stage", "-z"])

        await #expect {
            try await service.apply(snapshot, file: 0, hunk: 0)
        } throws: { error in
            guard let error = error as? GitError else { return false }

            return error.exitCode == 128 && error.message.contains("both a file and as a directory")
        }

        #expect(try await repository.runner.run(["ls-files", "--stage", "-z"]) == index)
        #expect(try Data(contentsOf: root.appending(path: "child")) == Data("new unrelated descendant\n".utf8))
    }

    /// 旧配对可能仍产生一段合法补丁，必须按重命名身份拒绝，而不是只检查段数。
    @Test("首次取样前失效的重命名配对", arguments: ["node/sub", "cancelled", "side"])
    func staleRename(destination: String) async throws {
        let fixture = try WorkingCopyScopeFixture(oldPath: "node", newPath: "node/sub/a.txt")
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        let requested = try await fixture.entry()

        // 取样之前把重命名的目标挪到别处、撤销重命名，或只把旧路径移出索引
        try FileManager.default.moveItem(
            at: fixture.repository.directory.appending(path: fixture.newPath),
            to: fixture.repository.directory.appending(path: ".git/moved")
        )
        try FileManager.default.removeItem(at: fixture.repository.directory.appending(path: "node"))

        let path =
            switch destination {
            case "cancelled": "node"
            case "side": fixture.newPath
            default: destination
            }

        try fixture.write(Data(WorkingCopyScopeFixture.original.utf8), path: path)
        _ = try await fixture.runner.run(["add", "--all"])

        if destination == "side" {
            _ = try await fixture.runner.run(["reset", "-q", "HEAD", "--", "node"])
        }

        // 挪到旧目录之下时，旧的路径规格仍能读出一段合法补丁
        if destination == "node/sub" {
            let oldPlan = RepositoryFileViews.filePathspecs(requested.operationPaths)
            let mistaken = try await fixture.runner.run(
                ["--no-literal-pathspecs", "diff", "--cached"]
                    + WorkingCopyOperations.diffArguments
                    + ["--"]
                    + oldPlan
            )
            #expect(try RepositoryDiff(patch: mistaken).files.count == 1)
        }

        await #expect(throws: WorkingCopyError.staleSnapshot) {
            try await fixture.service.diff(for: requested, side: .staged)
        }

        await #expect(throws: WorkingCopyError.staleSnapshot) {
            try await fixture.service.patch(for: requested, side: .staged, options: DiffOptions())
        }
    }

    /// 文件类型互换保留 Git 的两个补丁段；按块入口不能裁掉其中一段强行写回。两个方向各取一侧。
    @Test("符号链接多段补丁保持只读", arguments: [(false, false), (true, true)])
    func symbolicLink(reverse: Bool, staged: Bool) async throws {
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }

        try await fixture.repository.initialize()
        let path = fixture.repository.directory.appending(path: "file")

        if reverse {
            try FileManager.default.createSymbolicLink(atPath: path.path, withDestinationPath: "missing")
        } else {
            try Data("regular\n".utf8).write(to: path)
        }

        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-qm", "base"])

        // 普通文件与符号链接互换
        try FileManager.default.removeItem(at: path)

        if reverse {
            try Data("regular\n".utf8).write(to: path)
        } else {
            try FileManager.default.createSymbolicLink(atPath: path.path, withDestinationPath: "missing")
        }

        if staged {
            _ = try await fixture.runner.run(["add", "--all"])
        }

        // 两段补丁都读出，按块写入被拒绝，索引与工作区不变
        let entry = try #require(try await fixture.runner.status().entries.first)
        let snapshot = try await fixture.service.diff(for: entry, side: staged ? .staged : .unstaged)
        #expect(snapshot.diff?.files.count == 2)

        let index = try await fixture.runner.run(["ls-files", "--stage", "-z"])

        await #expect(throws: WorkingCopyError.invalidSelection) {
            try await fixture.service.apply(snapshot, file: 0, hunk: 0)
        }

        #expect(try await fixture.runner.run(["ls-files", "--stage", "-z"]) == index)

        if reverse {
            #expect(try Data(contentsOf: path) == Data("regular\n".utf8))
        } else {
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: path.path) == "missing")
        }
    }

    /// tracked 与 no-index 都按真实字面路径读取：以短横线开头的名字不成为选项，路径规格魔法、通配符、
    /// 反斜杠、制表符、换行与分解形式的 Unicode 都不扩大路径范围。
    @Test("工作区补丁的字面特殊路径", arguments: [
        "-option [*]?",
        ":(glob)中文 back\\slash\ttab\nline cafe\u{301}",
    ])
    func specialPaths(path: String) async throws {
        let fixture = try WorkingCopyScopeFixture(oldPath: "base", newPath: "unused")
        defer { fixture.repository.remove() }

        try await fixture.repository.initialize()

        // 未跟踪文件经 no-index 补丁整块暂存
        try fixture.write(Data("first\nsecond\n".utf8), path: path)
        let entry = try #require(try await fixture.runner.status().entries.first)
        let initial = try await fixture.service.diff(for: entry, side: .unstaged)
        #expect(initial.diff?.files.count == 1)

        try await fixture.service.apply(initial, file: 0, hunk: 0)
        _ = try await fixture.runner.run(["commit", "-qm", "tracked"])

        // 已跟踪文件的改动经普通补丁暂存
        try fixture.write(Data("changed\nsecond\n".utf8), path: path)
        let changed = try #require(try await fixture.runner.status().entries.first)
        let snapshot = try await fixture.service.diff(for: changed, side: .unstaged)
        #expect(snapshot.diff?.files.count == 1)

        try await fixture.service.apply(snapshot, file: 0, hunk: 0)
        #expect(try await fixture.runner.run(["show", ":" + changed.path]) == Data("changed\nsecond\n".utf8))
    }
}
