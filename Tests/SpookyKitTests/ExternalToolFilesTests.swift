import Foundation
import Testing

@testable import SpookyKit

// MARK: - ExternalToolFilesTests

/// 外部比较、合并工具与编辑器拿到的都是本机文件：用真实 Git 在临时仓库里核对各版本的内容、结果判定与写回前的核对。
struct ExternalToolFilesTests {
    /// 比较的每一侧都取自对应的版本；版本里没有的文件是同名空文件，本机工作区文件直接交出原路径。
    @Test("比较两侧的版本内容")
    func comparedVersions() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let path = "目 录/文件 '[*]'.txt"
        let first = try await commit(repository, [path: "first\n"], message: "first")
        try await commit(repository, [path: "second\n"], message: "second")

        // 暂存区与工作区各是不同的内容
        try write("staged\n", to: path, in: repository)
        _ = try await repository.runner.run(["add", "--", path])
        try write("working\n", to: path, in: repository)

        let cache = RepositoryFileCache(runner: repository.runner)
        defer { cache.removeAll() }
        let files = ExternalToolFiles(cache: cache)

        #expect(try await text(files.file(path, at: .commit(first))) == "first\n")
        #expect(try await text(files.file(path, at: .head)) == "second\n")
        #expect(try await text(files.file(path, at: .index)) == "staged\n")

        // 工具里对工作区一侧的修改直接落在工作区
        let working = try await files.file(path, at: .workingTree)
        #expect(working.standardizedFileURL == repository.directory.appending(path: path).standardizedFileURL)

        // 版本里没有的文件给出同名的空文件，副本只保留文件名
        let missing = try await files.file("新文件.txt", at: .head)
        #expect(missing.lastPathComponent == "新文件.txt")
        #expect(try Data(contentsOf: missing).isEmpty)

        let empty = try await files.file(path, at: .blob(nil))
        #expect(try Data(contentsOf: empty).isEmpty)
    }

    /// 还没有提交的仓库没有 HEAD，比较 HEAD 一侧是空文件而不是失败。
    @Test("没有提交时 HEAD 一侧为空")
    func unbornHead() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        try write("new\n", to: "a.txt", in: repository)

        let cache = RepositoryFileCache(runner: repository.runner)
        defer { cache.removeAll() }
        let files = ExternalToolFiles(cache: cache)

        #expect(try await Data(contentsOf: files.file("a.txt", at: .head)).isEmpty)
        #expect(try await Data(contentsOf: files.file("a.txt", at: .index)).isEmpty)
    }

    /// 目录对比的两侧按仓库内的相对路径放入文件，一侧没有的文件不放入；重命名的左侧按原路径读取。
    @Test("目录对比的两侧")
    func directoryComparison() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let parent = try await commit(repository, ["a/old.txt": "same\n", "gone.txt": "gone\n"], message: "parent")
        _ = try await repository.runner.run(["mv", "a/old.txt", "a/new.txt"])
        let child = try await commit(repository, ["gone.txt": nil, "b/added.txt": "added\n"], message: "child")

        let cache = RepositoryFileCache(runner: repository.runner)
        defer { cache.removeAll() }

        let (left, right) = try await ExternalToolFiles(cache: cache).directories(
            [
                ComparedFile(path: "a/new.txt", originalPath: "a/old.txt"),
                ComparedFile(path: "gone.txt"),
                ComparedFile(path: "b/added.txt"),
            ],
            left: (.commit(parent), String(parent.prefix(7))),
            right: (.commit(child), String(child.prefix(7)))
        )

        #expect(left.lastPathComponent == String(parent.prefix(7)))
        #expect(try String(contentsOf: left.appending(path: "a/old.txt"), encoding: .utf8) == "same\n")
        #expect(try String(contentsOf: left.appending(path: "gone.txt"), encoding: .utf8) == "gone\n")
        #expect(!FileManager.default.fileExists(atPath: left.appending(path: "b/added.txt").path))

        #expect(try String(contentsOf: right.appending(path: "a/new.txt"), encoding: .utf8) == "same\n")
        #expect(try String(contentsOf: right.appending(path: "b/added.txt"), encoding: .utf8) == "added\n")
        #expect(!FileManager.default.fileExists(atPath: right.appending(path: "gone.txt").path))
    }

    /// 合并工具的四个文件：三方取自索引，结果文件是带冲突标记的工作区内容；没有动过结果文件就没有结果。
    @Test("合并工具的文件与结果判定")
    func mergeFiles() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let path = "src/冲突 [1].swift"
        try await diverge(repository, path: path)
        _ = try await repository.runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

        let entry = try #require(try await repository.runner.status().entries.first { $0.path == path })
        let cache = RepositoryFileCache(runner: repository.runner)
        defer { cache.removeAll() }
        let files = try await ExternalToolFiles(cache: cache).prepareMerge(entry)

        #expect(files.hasBase)
        #expect(files.base.lastPathComponent == "冲突 [1].BASE.swift")
        #expect(files.local.lastPathComponent == "冲突 [1].LOCAL.swift")
        #expect(files.remote.lastPathComponent == "冲突 [1].REMOTE.swift")
        #expect(files.merged.lastPathComponent == "冲突 [1].swift")
        #expect(try text(files.base) == "base\n")
        #expect(try text(files.local) == "ours\n")
        #expect(try text(files.remote) == "theirs\n")
        #expect(try text(files.merged).contains("<<<<<<<"))

        // 工具没有写结果文件：没有结果
        #expect(try files.result() == nil)

        // 只保存不改内容也算产生了结果：修改时间晚于准备时
        let later = Date().addingTimeInterval(5)
        try FileManager.default.setAttributes([.modificationDate: later], ofItemAtPath: files.merged.path)
        #expect(try files.result() == (try Data(contentsOf: files.merged)))

        // 内容改了即是结果
        try Data("merged\n".utf8).write(to: files.merged)
        #expect(try files.result() == Data("merged\n".utf8))
    }

    /// 写回前核对工作区文件仍是准备时的内容；改过就拒绝覆盖，确认后才覆盖；写回后文件不再是冲突，按需留下备份。
    @Test("合并结果写回前的核对与备份")
    func applyMergeResult() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let path = "file.txt"
        try await diverge(repository, path: path)
        _ = try await repository.runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

        let entry = try #require(try await repository.runner.status().entries.first)
        let cache = RepositoryFileCache(runner: repository.runner)
        defer { cache.removeAll() }
        let files = try await ExternalToolFiles(cache: cache).prepareMerge(entry)
        let service = WorkingCopyOperations(runner: repository.runner)
        let marked = try Data(contentsOf: repository.directory.appending(path: path))

        // 合并工具运行期间文件在别处被改：不覆盖
        try write("edited elsewhere\n", to: path, in: repository)

        await #expect(throws: ExternalToolError.fileChanged) {
            try await service.applyMergeResult(Data("merged\n".utf8), for: files, keepBackup: true)
        }

        #expect(try text(repository.directory.appending(path: path)) == "edited elsewhere\n")
        #expect(try await repository.runner.status().entries.first?.kind == .conflicted)

        // 改回准备时的内容后写回：结果进入工作区与索引，被覆盖的内容留作 .orig
        try marked.write(to: repository.directory.appending(path: path))
        try await service.applyMergeResult(Data("merged\n".utf8), for: files, keepBackup: true)

        #expect(try text(repository.directory.appending(path: path)) == "merged\n")
        #expect(try Data(contentsOf: repository.directory.appending(path: path + ".orig")) == marked)

        let status = try await repository.runner.status()
        #expect(!status.entries.contains { $0.kind == .conflicted })
        #expect(status.entries.first { $0.path == path }?.staged == .modified)
    }

    /// 用户确认覆盖时，即使文件已在别处改过也写入；不保留备份时不留下 .orig。
    @Test("确认后覆盖别处的修改")
    func overwriteMergeResult() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let path = "file.txt"
        try await diverge(repository, path: path)
        _ = try await repository.runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

        let entry = try #require(try await repository.runner.status().entries.first)
        let cache = RepositoryFileCache(runner: repository.runner)
        defer { cache.removeAll() }
        let files = try await ExternalToolFiles(cache: cache).prepareMerge(entry)

        try write("edited elsewhere\n", to: path, in: repository)
        try await WorkingCopyOperations(runner: repository.runner)
            .applyMergeResult(Data("merged\n".utf8), for: files, keepBackup: false, overwrite: true)

        #expect(try text(repository.directory.appending(path: path)) == "merged\n")
        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: path + ".orig").path))
    }

    /// 删除与修改的冲突没有可合并的两侧，不交给合并工具。
    @Test("删除冲突不交给合并工具")
    func deletionConflict() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        try await commit(repository, ["file.txt": "base\n"], message: "base")
        _ = try await repository.runner.run(["checkout", "-q", "-b", "side"])
        try await commit(repository, ["file.txt": nil], message: "theirs")
        _ = try await repository.runner.run(["checkout", "-q", "main"])
        try await commit(repository, ["file.txt": "ours\n"], message: "ours")
        _ = try await repository.runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

        let entry = try #require(try await repository.runner.status().entries.first)
        let cache = RepositoryFileCache(runner: repository.runner)
        defer { cache.removeAll() }

        await #expect(throws: ConflictResolutionError.versionUnavailable) {
            _ = try await ExternalToolFiles(cache: cache).prepareMerge(entry)
        }
    }

    /// 编辑器副本：没改不写回；改了且原文件没动过就写回；原文件在别处改过时拒绝，确认后覆盖。关闭仓库时副本随缓存删除。
    @Test("编辑器副本的写回与清理")
    func editingCopy() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        let path = ".gitignore"
        try write("*.o\n", to: path, in: repository)

        let cache = RepositoryFileCache(runner: repository.runner)
        let copy = try await cache.editingCopy(of: path)

        #expect(copy.file.lastPathComponent == ".gitignore")
        #expect(copy.path == repository.directory.path + "/" + path)
        #expect(try await !cache.writeBack(copy))

        try Data("*.o\n*.a\n".utf8).write(to: copy.file)
        #expect(try await cache.writeBack(copy))
        #expect(try text(repository.directory.appending(path: path)) == "*.o\n*.a\n")

        // 原文件在别处被改：不覆盖，原文件保持别处的修改
        try write("changed elsewhere\n", to: path, in: repository)
        try Data("*.o\n*.a\n*.so\n".utf8).write(to: copy.file)

        await #expect(throws: ExternalToolError.fileChanged) {
            try await cache.writeBack(copy)
        }

        #expect(try text(repository.directory.appending(path: path)) == "changed elsewhere\n")

        #expect(try await cache.writeBack(copy, overwrite: true))
        #expect(try text(repository.directory.appending(path: path)) == "*.o\n*.a\n*.so\n")

        // 关闭仓库时缓存连同副本一起删除
        cache.removeAll()
        #expect(!FileManager.default.fileExists(atPath: copy.file.path))
    }

    /// 版本标记插在扩展名之前；没有扩展名或以点开头的文件名，标记放在最后。
    @Test("三方副本的文件名")
    func markedNames() {
        #expect(ExternalToolFiles.name("dir/a.tar.gz", marker: "LOCAL") == "a.tar.LOCAL.gz")
        #expect(ExternalToolFiles.name("Makefile", marker: "BASE") == "Makefile.BASE")
        #expect(ExternalToolFiles.name(".gitignore", marker: "REMOTE") == ".gitignore.REMOTE")
    }
}

// MARK: - Helpers

extension ExternalToolFilesTests {
    /// 文件内容按 UTF-8 读出。
    private func text(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    /// 在工作区写入文件，按需创建目录。
    private func write(_ content: String, to path: String, in repository: TemporaryRepository) throws {
        let url = repository.directory.appending(path: path)

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }

    /// 写入或删除文件后提交全部改动，返回新提交的哈希。
    ///
    /// - Parameter files: 相对路径与内容；值为 nil 的文件被删除。
    @discardableResult
    private func commit(
        _ repository: TemporaryRepository,
        _ files: [String: String?],
        message: String
    ) async throws -> String {
        for (path, content) in files {
            if let content {
                try write(content, to: path, in: repository)
            } else {
                try FileManager.default.removeItem(at: repository.directory.appending(path: path))
            }
        }

        _ = try await repository.runner.run(["add", "-A"])
        _ = try await repository.runner.run(["commit", "-q", "-m", message])

        return try #require(try await repository.runner.status().branch.oid)
    }

    /// 同一文件在 main 与 side 上各改一次，合并 side 时产生两侧都修改的冲突。
    private func diverge(_ repository: TemporaryRepository, path: String) async throws {
        try await commit(repository, [path: "base\n"], message: "base")

        _ = try await repository.runner.run(["checkout", "-q", "-b", "side"])
        try await commit(repository, [path: "theirs\n"], message: "theirs")

        _ = try await repository.runner.run(["checkout", "-q", "main"])
        try await commit(repository, [path: "ours\n"], message: "ours")
    }
}
