import Foundation
import Testing

@testable import SpookyKit

// MARK: - WorkingCopyFileOperationsTests

/// 工作区文件操作用真实 Git 验证结果：路径按字面处理，失败时不改动工作区。
struct WorkingCopyFileOperationsTests {
    /// 文件名覆盖空格、中文、引号、反斜杠与通配符，确认没有被当作路径规格展开。
    private static let special = "文件 ' \\ [*]?.txt"

    /// 停止跟踪只改暂存区：文件留在工作区并成为未跟踪文件，名字相近的文件不受影响。
    @Test("停止跟踪保留工作区文件")
    func untrack() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        let service = try await committedRepository(repository, files: [Self.special, "文件 x.txt"])

        try await service.untrack([Self.special])

        let entries = try await repository.runner.status().entries
        #expect(entries.contains { $0.path == Self.special && $0.staged == .deleted })
        #expect(entries.contains { $0.path == Self.special && $0.kind == .untracked })
        #expect(!entries.contains { $0.path == "文件 x.txt" })
        #expect(FileManager.default.fileExists(atPath: repository.directory.appending(path: Self.special).path))
    }

    /// 本机删除把文件移到废纸篓，用户还能找回；Git 看到的是未暂存的删除。
    @Test("本机删除移到废纸篓")
    func deleteMovesToTrash() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        let service = try await committedRepository(repository, files: [Self.special])

        let trashed = try await service.delete([Self.special])
        defer { for location in trashed.compactMap(\.location) { try? FileManager.default.removeItem(atPath: location) } }

        #expect(trashed.count == 1)
        #expect(trashed.allSatisfy { $0.location.map(FileManager.default.fileExists(atPath:)) ?? false })
        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: Self.special).path))
        #expect(try await repository.runner.status().entries.first?.unstaged == .deleted)
    }

    /// 已跟踪文件经 git mv 移动并记为重命名；未跟踪文件直接移动；目标已存在时都不覆盖。
    @Test("移动与重命名不覆盖已有文件")
    func move() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        let service = try await committedRepository(repository, files: [Self.special, "-dash.txt"])
        let untracked = repository.directory.appending(path: "新 文件.txt")
        try Data("new\n".utf8).write(to: untracked)

        // 以 “-” 开头的路径不能被当作选项
        try await service.move("-dash.txt", to: "renamed [*].txt", tracked: true)
        let renamed = try #require(try await repository.runner.status().entries.first { $0.path == "renamed [*].txt" })
        #expect(renamed.staged == .renamed && renamed.originalPath == "-dash.txt")

        try await service.move("新 文件.txt", to: "移动后.txt", tracked: false)
        #expect(FileManager.default.fileExists(atPath: repository.directory.appending(path: "移动后.txt").path))

        // 目标已存在：git mv 报错并保留原始输出，未跟踪文件的移动在 Spooky 这一层拒绝
        let error = await #expect(throws: GitError.self) {
            try await service.move(Self.special, to: "renamed [*].txt", tracked: true)
        }
        #expect(error?.exitCode == 128)
        #expect(error?.message.contains("destination exists") ?? false)

        await #expect(throws: WorkingCopyFileError.destinationExists) {
            try await service.move("移动后.txt", to: Self.special, tracked: false)
        }
        #expect(try Data(contentsOf: repository.directory.appending(path: Self.special)) == Data("\(Self.special)\n".utf8))
    }

    /// assume-unchanged 让 Git 不再报告文件的改动，清除后改动重新出现；索引清单标出被标记的文件。
    @Test("设置与清除 assume-unchanged")
    func assumeUnchanged() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        let service = try await committedRepository(repository, files: [Self.special, "other.txt"])
        try Data("changed\n".utf8).write(to: repository.directory.appending(path: Self.special))

        try await service.setAssumeUnchanged([Self.special], true)
        #expect(try await repository.runner.status().entries.isEmpty)
        #expect(
            try await repository.runner.indexFiles() == [
                IndexFile(path: "other.txt", assumeUnchanged: false),
                IndexFile(path: Self.special, assumeUnchanged: true),
            ]
        )

        try await service.setAssumeUnchanged([Self.special], false)
        #expect(try await repository.runner.status().entries.first?.path == Self.special)

        // 不在暂存区里的路径让整批失败，已在暂存区里的文件也不会被改动
        let error = await #expect(throws: GitError.self) {
            try await service.setAssumeUnchanged(["other.txt", "missing.txt"], true)
        }
        #expect(error?.exitCode == 128)
        #expect(try await repository.runner.indexFiles().allSatisfy { !$0.assumeUnchanged })
    }

    /// 生成的规则只匹配所选文件本身，名字相近的文件仍然可见；重复的规则不再写入。
    @Test("忽略规则按字面匹配且不重复写入")
    func ignorePatterns() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)

        for name in [Self.special, "文件 x.txt", "#注释 ", "logs/a.log", "logs/b.log", "keep.txt"] {
            let url = repository.directory.appending(path: name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("x\n".utf8).write(to: url)
        }

        let items = WorkingCopyOperations.ignorePatterns(for: [Self.special, "#注释 "], scope: .items)
        #expect(items == ["/文件 ' \\\\ \\[\\*]\\?.txt", "/#注释\\ "])
        #expect(WorkingCopyOperations.ignorePatterns(for: ["logs/a.log", "keep"], scope: .type) == ["*.log"])
        #expect(WorkingCopyOperations.ignorePatterns(for: ["build/"], scope: .name) == ["build/"])

        // 名字规则从行首开始，开头的 # 不能被当作注释
        #expect(WorkingCopyOperations.ignorePatterns(for: ["dir/#注释 "], scope: .name) == ["\\#注释\\ "])

        try await service.addIgnorePatterns(items, to: .gitignore)
        try await service.addIgnorePatterns(items + ["*.log"], to: .gitignore)

        let content = String(decoding: try Data(contentsOf: repository.directory.appending(path: ".gitignore")), as: UTF8.self)
        #expect(content == items.joined(separator: "\n") + "\n*.log\n")

        let ignored = try await repository.runner.ignoredFiles()
        #expect(Set(ignored) == [Self.special, "#注释 ", "logs/"])

        let visible = try await repository.runner.status().entries.map(\.path)
        #expect(visible.contains("文件 x.txt") && visible.contains("keep.txt"))
    }

    /// 排除规则写进 Git 定位的 info/exclude，目录不存在时创建；NFD 写法的已有规则视为同一条。
    @Test("排除规则写入 info/exclude 并按 Unicode 规范化去重")
    func excludePatterns() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        let info = repository.directory.appending(path: ".git/info")
        try? FileManager.default.removeItem(at: info)

        try Data("cafe\u{301}.txt\n".utf8).write(to: repository.directory.appending(path: "café.txt"))
        try await service.addIgnorePatterns(["/café.txt"], to: .exclude)
        try await service.addIgnorePatterns(["/cafe\u{301}.txt"], to: .exclude)

        let content = try String(contentsOf: info.appending(path: "exclude"), encoding: .utf8)
        #expect(content.split(separator: "\n").count == 1)
        #expect(try await repository.runner.ignoredFiles() == ["café.txt"])
        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: ".gitignore").path))
    }

    /// 补丁应用前核对前像：文件已被改动时即使上下文仍能对上也拒绝，工作区保持原样。
    @Test("应用补丁并核对生成时的文件状态")
    func applyPatch() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        let service = try await committedRepository(repository, files: [Self.special])
        let file = repository.directory.appending(path: Self.special)
        let original = Data("1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n".utf8)
        try original.write(to: file)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "lines", body: "")

        try Data("1\nTWO\n3\n4\n5\n6\n7\n8\n9\n10\n".utf8).write(to: file)
        let patch = try await repository.runner.run(["diff", "--full-index", "--", Self.special])
        try original.write(to: file)

        try await service.applyPatch(patch)
        #expect(try Data(contentsOf: file) == Data("1\nTWO\n3\n4\n5\n6\n7\n8\n9\n10\n".utf8))

        // 远处的一行变了，git apply 本身仍能应用；前像核对发现文件不是生成补丁时的版本
        let edited = Data("1\n2\n3\n4\n5\n6\n7\n8\n9\nTEN\n".utf8)
        try edited.write(to: file)
        await #expect(throws: WorkingCopyFileError.patchPreimageMismatch([Self.special])) {
            try await service.applyPatch(patch)
        }
        #expect(try Data(contentsOf: file) == edited)

        // 损坏的补丁由 Git 预检拒绝，原始输出保留
        let error = await #expect(throws: GitError.self) {
            try await service.applyPatch(Data("diff --git a/x b/x\n@@ broken\n".utf8))
        }
        #expect(error?.exitCode == 128)
        #expect(!(error?.message.isEmpty ?? true))
        #expect(try Data(contentsOf: file) == edited)
    }

    /// 补丁的文件头：引号路径反转义，重命名取原路径，新增文件与块内的 “---” 行不产生前像。
    @Test("读取补丁文件头里的前像")
    func patchPreimages() throws {
        let patch = Data(
            """
            From 1234 Mon Sep 17 00:00:00 2001
            Subject: [PATCH] 改动

            diff --git "a/\\344\\275\\240 \\"q\\".txt" "b/\\344\\275\\240 \\"q\\".txt"
            index 1111111..2222222 100644
            --- "a/\\344\\275\\240 \\"q\\".txt"
            +++ "b/\\344\\275\\240 \\"q\\".txt"
            @@ -1 +1 @@
            --- 被删掉的一行
            +++ 新的一行
            diff --git a/old name.txt b/new name.txt
            similarity index 90%
            rename from old name.txt
            rename to new name.txt
            index 3333333333333333333333333333333333333333..4444444444444444444444444444444444444444 100644
            --- a/old name.txt\t
            +++ b/new name.txt\t
            @@ -1 +1 @@
            -a
            +b
            diff --git a/added.txt b/added.txt
            new file mode 100644
            index 0000000..5555555
            --- /dev/null
            +++ b/added.txt
            @@ -0,0 +1 @@
            +new
            diff --git a/module b/module
            index 6666666..7777777 160000
            --- a/module
            +++ b/module
            @@ -1 +1 @@
            -Subproject commit 6666666
            +Subproject commit 7777777

            """.utf8
        )

        #expect(
            PatchPreimage.preimages(in: patch) == [
                PatchPreimage(path: "你 \"q\".txt", hash: "1111111"),
                PatchPreimage(path: "old name.txt", hash: "3333333333333333333333333333333333333333"),
            ]
        )

        // 不完整的转义无法还原成路径
        #expect(PatchPreimage.unquoted("\"a\\3\"") == nil)
        #expect(PatchPreimage.unquoted("\"a") == nil)
    }

    /// 索引清单按路径去重，assume-unchanged 由小写标记识别；截断或格式错误的输出整体作废。
    @Test("解析 ls-files 输出")
    func parseIndexFiles() throws {
        let output = Data("M c.txt\0M c.txt\0h a b.txt\0S skip.txt\0".utf8)
        #expect(
            try IndexFile.parse(lsFilesVerbose: output) == [
                IndexFile(path: "c.txt", assumeUnchanged: false),
                IndexFile(path: "a b.txt", assumeUnchanged: true),
                IndexFile(path: "skip.txt", assumeUnchanged: false),
            ]
        )

        #expect(throws: RepositoryReadError.malformedOutput("ls-files")) {
            try IndexFile.parse(lsFilesVerbose: Data("H x.txt".utf8))
        }
        #expect(throws: RepositoryReadError.malformedOutput("ls-files")) {
            try IndexFile.parse(lsFilesVerbose: Data("Hx.txt\0".utf8))
        }
        #expect(throws: RepositoryReadError.malformedOutput("ls-files")) {
            try IndexFile.parse(lsFilesVerbose: Data("\0".utf8))
        }
    }

    /// 被忽略的目录只列一项，其中的文件不逐个展开。
    @Test("被忽略的目录只列一项")
    func ignoredDirectory() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let build = repository.directory.appending(path: "build/sub")
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try Data("o\n".utf8).write(to: build.appending(path: "x.o"))
        try Data("build/\n".utf8).write(to: repository.directory.appending(path: ".gitignore"))

        #expect(try await repository.runner.ignoredFiles() == ["build/"])
    }
}

// MARK: - Helpers

extension WorkingCopyFileOperationsTests {
    /// 初始化仓库并提交给定文件，每个文件的内容是自己的名字加换行。
    private func committedRepository(
        _ repository: TemporaryRepository,
        files: [String]
    ) async throws -> WorkingCopyOperations {
        try await repository.initialize()

        for name in files {
            try Data("\(name)\n".utf8).write(to: repository.directory.appending(path: name))
        }

        let service = WorkingCopyOperations(runner: repository.runner)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")
        return service
    }
}
