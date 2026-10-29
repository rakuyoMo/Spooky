import Foundation
import Synchronization
import Testing

@testable import SpookyKit

// MARK: - Formatting

extension RevisionExportTests {
    /// 两种保存都把每个提交那一次 format-patch 交给调用方包住：按传入顺序各经过一次，合并提交不执行也不经过，写出的文件与直接执行时相同；
    /// 闭包抛出的错误照常抛出，任务取消后后面的提交不再执行，已写好的补丁保留。
    @Test("每个提交的 format-patch 经过调用方")
    func formattingEachCommit() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let root = runner.location.path

        // 先建好全部提交，之后写进根目录的补丁不会被提交进去
        let first = try await Self.commit(
            fixture,
            files: ["one.txt": Data("one\n".utf8)],
            message: "first one"
        )

        _ = try await runner.run(["switch", "-q", "-c", "side"])
        _ = try await Self.commit(
            fixture,
            files: ["side.txt": Data("s\n".utf8)],
            message: "side"
        )

        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["merge", "-q", "--no-ff", "-m", "merge", "side"])
        let merge = try await RepositoryReferences(runner: runner).resolve("HEAD")

        let second = try await Self.commit(
            fixture,
            files: ["two.txt": Data("two\n".utf8)],
            message: "second two"
        )

        let output = try Self.outputDirectory()
        defer { try? FileManager.default.removeItem(at: output) }

        let export = RevisionExport(runner: runner)
        let commits = [first, merge, second]
        let formatted = Mutex<[String]>([])

        // 对话框保存：记下经过的提交再照常执行
        let saved = try await export.savePatches(
            commits,
            omitsPrefixes: false,
            to: output
        ) { commit, format in
            formatted.withLock { $0.append(commit) }
            try await format()
        }

        #expect(formatted.withLock { $0 } == [first, second])
        #expect(saved.map(\.lastPathComponent) == ["0001-first-one.patch", "0003-second-two.patch"])
        #expect(try await export.savePatches(commits, omitsPrefixes: false, to: output) == saved)

        // 快速保存同样按提交经过
        formatted.withLock { $0.removeAll() }

        let quick = try await export.savePatchesToRepositoryRoot(
            commits,
            omitsPrefixes: false
        ) { commit, format in
            formatted.withLock { $0.append(commit) }
            try await format()
        }

        #expect(formatted.withLock { $0 } == [first, second])
        #expect(quick == [root + "/0001-first-one.patch", root + "/0003-second-two.patch"])

        // 闭包抛出的错误照常抛出，后面的提交不再经过
        formatted.withLock { $0.removeAll() }

        await #expect(throws: CancellationError.self) {
            try await export.savePatchesToRepositoryRoot(
                commits,
                omitsPrefixes: false
            ) { commit, _ in
                formatted.withLock { $0.append(commit) }
                throw CancellationError()
            }
        }

        #expect(formatted.withLock { $0 } == [first])

        // 第一个提交写完后任务被取消：它的补丁保留，后面的提交不再执行
        formatted.withLock { $0.removeAll() }

        let cancelled = output.appending(path: "cancelled")
        try FileManager.default.createDirectory(at: cancelled, withIntermediateDirectories: false)

        let task = Task {
            try await export.savePatches(
                commits,
                omitsPrefixes: false,
                to: cancelled
            ) { commit, format in
                formatted.withLock { $0.append(commit) }
                try await format()
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(formatted.withLock { $0 } == [first])
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: cancelled.path) == ["0001-first-one.patch"]
        )
    }
}
