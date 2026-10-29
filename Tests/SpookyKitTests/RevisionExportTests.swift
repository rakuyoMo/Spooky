import Foundation
import Synchronization
import Testing

@testable import SpookyKit

// MARK: - RevisionExportTests

/// 导出文件、归档与保存补丁都写到本机，输出边读边写；失败与取消不留下写了一半的文件。存进仓库根目录的补丁由 Git 直接写出。
struct RevisionExportTests {
    /// 导出成目录保留仓库里的目录结构、特殊字符路径与二进制内容；只导出所选路径时其余文件不出现。
    @Test("导出版本里的文件", arguments: ["sha1", "sha256"])
    func exportFiles(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let special = "目录 [*]/文件 '\"?.txt"
        let revision = try await Self.commit(fixture, files: [special: Data("one\n".utf8), "binary": Data([0, 1, 2, 255])])

        let output = try Self.outputDirectory()
        defer { try? FileManager.default.removeItem(at: output) }

        let export = RevisionExport(runner: fixture.runner)
        let whole = output.appending(path: "整个 版本")
        try await export.export(revision, to: whole)
        #expect(try Data(contentsOf: whole.appending(path: special)) == Data("one\n".utf8))
        #expect(try Data(contentsOf: whole.appending(path: "binary")) == Data([0, 1, 2, 255]))

        // 已存在的目录整个替换
        let partial = output.appending(path: "整个 版本")
        try await export.export(revision, paths: [special], to: partial)
        #expect(FileManager.default.fileExists(atPath: partial.appending(path: special).path))
        #expect(!FileManager.default.fileExists(atPath: partial.appending(path: "binary").path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: output.path) == ["整个 版本"])
    }

    /// zip 与 tar 归档的内容能被本机解开；路径按字面匹配，通配符不会多选文件。
    @Test("归档版本里的文件")
    func archives() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let revision = try await Self.commit(fixture, files: ["[*].txt": Data("star\n".utf8), "a.txt": Data("a\n".utf8)])

        let output = try Self.outputDirectory()
        defer { try? FileManager.default.removeItem(at: output) }

        let export = RevisionExport(runner: fixture.runner)
        let zip = output.appending(path: "归档.zip")
        try await export.archive(revision, format: .zip, to: zip)
        #expect(try Data(contentsOf: zip).prefix(2) == Data("PK".utf8))

        let tar = output.appending(path: "部分.tar")
        try await export.archive(revision, paths: ["[*].txt"], format: .tar, to: tar)

        let listing = try await CommandExecutor.execute(
            executable: "/usr/bin/tar",
            processArguments: ["-t", "-f", tar.path],
            arguments: ["tar"]
        )
        #expect(String(decoding: listing.standardOutput, as: UTF8.self) == "[*].txt\n")
    }

    /// 文件名与 format-patch 写进目录时相同；去掉前缀、跳过合并提交，同名文件被替换；封面信没配或配成 auto 时只写补丁本身。
    @Test("保存补丁", arguments: ["sha1", "sha256"])
    func patches(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let long = "Ünïcode [*] 'quoted' subject that is long enough to be truncated by git format patch"
        let first = try await Self.commit(fixture, files: ["one.txt": Data("one\n".utf8)], message: long)
        let second = try await Self.commit(fixture, files: ["two.bin": Data([0, 1])], message: "second: two")

        let output = try Self.outputDirectory()
        defer { try? FileManager.default.removeItem(at: output) }

        // 与 Git 自己写进目录的文件名逐个比对
        let reference = output.appending(path: "reference")
        _ = try await runner.run(["format-patch", "-q", "-o", reference.path, "-2", second])
        let expected = try FileManager.default.contentsOfDirectory(atPath: reference.path).sorted()

        let directory = output.appending(path: "补丁 目录")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let export = RevisionExport(runner: runner)
        let saved = try await export.savePatches([first, second], omitsPrefixes: false, to: directory)
        #expect(saved.map(\.lastPathComponent) == expected)

        let patch = String(decoding: try Data(contentsOf: saved[0]), as: UTF8.self)
        #expect(patch.contains("--- /dev/null\n+++ b/one.txt\n"))

        // 没配封面信时，与 Git 只输出这一个提交的补丁逐字节相同
        let plain = try Data(contentsOf: saved[1])
        #expect(try await runner.run(["format-patch", "--stdout", "-1", second]) == plain)

        let omitted = try await export.savePatches([first], omitsPrefixes: true, to: directory)
        #expect(String(decoding: try Data(contentsOf: omitted[0]), as: UTF8.self).contains("+++ one.txt\n"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 2)

        // 封面信配成 auto 时，每次只存一个提交，Git 不写封面信，文件与配置前逐字节相同
        _ = try await runner.run(["config", "--local", "format.coverLetter", "auto"])
        #expect(try await export.savePatches([first, second], omitsPrefixes: false, to: directory) == saved)
        #expect(try Data(contentsOf: saved[1]) == plain)
        #expect(String(decoding: plain, as: UTF8.self).contains("\nSubject: [PATCH] second: two\n"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 2)

        // 合并提交没有补丁
        _ = try await runner.run(["switch", "-q", "-c", "side", first])
        let side = try await Self.commit(fixture, files: ["side.txt": Data("s\n".utf8)])
        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["merge", "-q", "--no-ff", "-m", "merge", "side"])
        let merge = try await RepositoryReferences(runner: runner).resolve("HEAD")
        #expect(try await export.savePatches([side, merge], omitsPrefixes: false, to: directory).count == 1)
    }

    /// 补丁由 Git 直接写进仓库根目录，内容与输出到标准输出时相同；仓库的后缀配置不改变文件名，封面信配成 auto 时不写。
    @Test("补丁存进仓库根目录", arguments: ["sha1", "sha256"])
    func patchesInRepositoryRoot(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let root = runner.location.path

        // 先建好全部提交，之后写进根目录的补丁不会被提交进去
        let first = try await Self.commit(fixture, files: ["one.txt": Data("one\n".utf8)], message: "first: one")
        let second = try await Self.commit(fixture, files: ["two.bin": Data([0, 1])], message: "second two")
        _ = try await runner.run(["switch", "-q", "-c", "side", first])
        let side = try await Self.commit(fixture, files: ["side.txt": Data("s\n".utf8)], message: "side")
        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["merge", "-q", "--no-ff", "-m", "merge", "side"])
        let merge = try await RepositoryReferences(runner: runner).resolve("HEAD")

        let export = RevisionExport(runner: runner)
        let saved = try await export.savePatchesToRepositoryRoot([first, second], omitsPrefixes: false)
        #expect(saved == [root + "/0001-first-one.patch", root + "/0002-second-two.patch"])

        for (path, commit) in zip(saved, [first, second]) {
            let expected = try await runner.run(["format-patch", "--stdout", "-1", commit])
            #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == expected)
        }

        // 去掉前缀再存一次，同名文件被覆盖
        let omitted = try await export.savePatchesToRepositoryRoot([first], omitsPrefixes: true)
        #expect(omitted == [saved[0]])
        #expect(String(decoding: try Data(contentsOf: URL(fileURLWithPath: omitted[0])), as: UTF8.self).contains("+++ one.txt\n"))

        // 合并提交不写文件，序号仍按传入的位置计
        #expect(try await export.savePatchesToRepositoryRoot([merge, side], omitsPrefixes: false) == [root + "/0002-side.patch"])

        _ = try await runner.run(["config", "--local", "format.suffix", ".diff"])
        _ = try await runner.run(["config", "--local", "format.coverLetter", "auto"])
        #expect(try await export.savePatchesToRepositoryRoot([second], omitsPrefixes: false) == [root + "/0001-second-two.patch"])

        // 根目录里只有这几个补丁，没有封面信，也没有 .diff 文件
        let patches = try FileManager.default.contentsOfDirectory(atPath: root).filter { $0.hasPrefix("000") }.sorted()
        #expect(patches == ["0001-first-one.patch", "0001-second-two.patch", "0002-second-two.patch", "0002-side.patch"])

        // 写文件的 format-patch 与其它写操作一样排队，只输出到标准输出的仍是读取
        #expect(RepositoryOperationQueue.isReadOnly(["format-patch", "--stdout", "-1", first]))
        #expect(!RepositoryOperationQueue.isReadOnly(["format-patch", "-o", root, "-1", first]))

        // 没有提交时不执行 Git
        await #expect(throws: RepositoryReadError.self) {
            try await export.savePatchesToRepositoryRoot([], omitsPrefixes: false)
        }
    }

    /// 仓库配了封面信时，两种保存都在补丁旁边另写一封，补丁标题随之编号；补丁文件里只有一封邮件，不混进封面信。
    @Test("配了封面信时另写一个文件", arguments: ["sha1", "sha256"])
    func coverLetters(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let first = try await Self.commit(fixture, files: ["one.txt": Data("one\n".utf8)], message: "first one")
        let second = try await Self.commit(fixture, files: ["two.txt": Data("two\n".utf8)], message: "second two")
        _ = try await runner.run(["config", "--local", "format.coverLetter", "true"])

        let output = try Self.outputDirectory()
        defer { try? FileManager.default.removeItem(at: output) }

        let export = RevisionExport(runner: runner)
        let cover = output.appending(path: "0000-cover-letter.patch")

        // 存一个提交：封面信与补丁各一个文件
        let single = try await export.savePatches([first], omitsPrefixes: false, to: output)
        #expect(single == [cover, output.appending(path: "0001-first-one.patch")])

        let firstLetter = try String(contentsOf: cover, encoding: .utf8)
        #expect(firstLetter.contains("\nSubject: [PATCH 0/1] *** SUBJECT HERE ***\n"))

        let patch = try String(contentsOf: single[1], encoding: .utf8)
        #expect(patch.hasPrefix("From \(first) "))
        #expect(patch.components(separatedBy: "From \(first) ").count == 2)
        #expect(patch.contains("\nSubject: [PATCH 1/1] first one\n"))

        // 存两个提交：封面信只返回一次，留下的是较新的提交生成的
        let saved = try await export.savePatches([first, second], omitsPrefixes: false, to: output)
        #expect(saved == [cover, single[1], output.appending(path: "0002-second-two.patch")])

        let secondPatch = try String(contentsOf: saved[2], encoding: .utf8)
        #expect(secondPatch.contains("\nSubject: [PATCH 2/2] second two\n"))

        let letter = try String(contentsOf: cover, encoding: .utf8)
        #expect(letter.hasPrefix("From \(second) "))
        #expect(letter.contains("\nSubject: [PATCH 0/2] *** SUBJECT HERE ***\n"))
        #expect(letter.contains("\n  second two\n"))
        #expect(!letter.contains("first one"))

        // 快速保存写出同名的文件：补丁逐字节相同，封面信只有 Date 一行可能不同
        let quick = try await export.savePatchesToRepositoryRoot([first, second], omitsPrefixes: false)
        #expect(quick == saved.map { runner.location.path + "/" + $0.lastPathComponent })

        for (path, file) in zip(quick, saved).dropFirst() {
            #expect(try Data(contentsOf: URL(filePath: path)) == Data(contentsOf: file))
        }

        let undated = { (url: URL) in
            try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.hasPrefix("Date: ") }
        }

        #expect(try undated(URL(filePath: quick[0])) == undated(cover))
    }

    /// 输出流式交给回调，不收集进结果；失败或取消时目标与临时文件都不存在。
    @Test("流式写盘、失败与取消的清理")
    func cleanup() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let revision = try await Self.commit(fixture, files: ["a.txt": Data(repeating: 97, count: 100_000)])
        let runner = fixture.runner

        let received = Mutex(0)
        let result = try await CommandExecutor.$streamsStandardOutput.withValue(true) {
            try await runner.execute(["archive", "--format=tar", revision]) { event in
                if case .standardOutput(let data) = event {
                    received.withLock { $0 += data.count }
                }
            }
        }
        #expect(result.standardOutput.isEmpty)
        #expect(received.withLock { $0 } > 100_000)

        let output = try Self.outputDirectory()
        defer { try? FileManager.default.removeItem(at: output) }

        let export = RevisionExport(runner: runner)
        let missing = output.appending(path: "missing.zip")
        await #expect(throws: GitError.self) {
            try await export.archive(revision, paths: ["no such path"], format: .zip, to: missing)
        }

        let cancelled = output.appending(path: "cancelled.tar")
        let task = Task { try await export.archive(revision, format: .tar, to: cancelled) }
        task.cancel()
        _ = await task.result

        #expect(try FileManager.default.contentsOfDirectory(atPath: output.path).isEmpty)
        await #expect(throws: RepositoryReadError.self) { try await export.export("HEAD", to: missing) }
        await #expect(throws: RepositoryReadError.self) {
            try await export.savePatches([], omitsPrefixes: false, to: output)
        }
    }
}

// MARK: - Helpers

extension RevisionExportTests {
    /// 本机输出目录，路径带空格与中文。
    private static func outputDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Spooky 导出 \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 写入文件后提交全部改动，返回提交哈希。
    private static func commit(
        _ fixture: TemporaryRepository,
        files: [String: Data],
        message: String = "commit"
    ) async throws -> String {
        for (path, content) in files {
            let url = fixture.directory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url)
        }

        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-q", "-m", message])
        return try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
    }
}
