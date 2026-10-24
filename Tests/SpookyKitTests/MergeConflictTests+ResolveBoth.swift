import Foundation
import Testing

@testable import SpookyKit

// MARK: - Resolve Using Both

/// 采用两侧版本：在仓库所在的机器上按冲突块合并两侧，经临时文件与对象库写回索引和工作区。
extension MergeConflictTests {
    /// 采用两侧时冲突块里两侧的行都要保留、我方在前，不冲突的改动照常合并；结果直接标记解决，横幅仍能数出它。
    @Test("采用两侧版本：按冲突块保留两侧并标记解决")
    func resolveUsingBoth() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let path = "日志 [*].txt"
        let file = repository.directory.appending(path: path)

        _ = try await diverge(
            repository,
            base: [path: "one\ntwo\nthree\nfour\nfive\n"],
            ours: [path: "one\nours\nthree\nfour\nfive\n", "added.txt": "shared\nmine\n"],
            theirs: [path: "one\ntheirs\nthree\nfour\n5\n", "added.txt": "shared\nyours\n"]
        )

        _ = try await repository.runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: repository.runner)
        let entries = Dictionary(uniqueKeysWithValues: try await repository.runner.status().entries.map { ($0.path, $0) })

        try await service.resolveUsingBoth(try #require(entries[path]))

        // 第二行在两侧都改了，按冲突块保留两侧；第五行只有对方改了，照常合并
        #expect(try Data(contentsOf: file) == Data("one\nours\ntheirs\nthree\nfour\n5\n".utf8))

        // 两侧各自新增的文件没有共同祖先，相同的开头只保留一份
        try await service.resolveUsingBoth(try #require(entries["added.txt"]))

        let added = repository.directory.appending(path: "added.txt")
        #expect(try Data(contentsOf: added) == Data("shared\nmine\nyours\n".utf8))

        let status = try await repository.runner.status()
        #expect(status.entries.allSatisfy { $0.kind != .conflicted })

        let progress = try #require(try await service.context(head: status.branch.oid).progress)
        #expect(progress.resolvedPaths == [path, "added.txt"])

        // 合并用的临时文件都已删除，不会出现在工作区里
        #expect(try temporaryFiles(in: repository).isEmpty)
    }

    /// 临时文件是检出后的工作区形式，写入索引前必须按文件的真实路径转换换行；符号链接不能逐行合并；合并失败也不能留下临时文件。
    @Test("采用两侧版本：按真实路径转换换行，符号链接不合并，二进制失败后清理")
    func resolveUsingBothFilters() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let path = "换行 [*].txt"

        _ = try await diverge(
            repository,
            base: [
                ".gitattributes": "*.txt text eol=crlf\n",
                path: "one\r\ntwo\r\nthree\r\nfour\r\nfive\r\n",
                "data.bin": "\0base",
            ],
            ours: [path: "one\r\nours\r\nthree\r\nfour\r\nfive\r\n", "data.bin": "\0ours"],
            theirs: [path: "one\r\ntheirs\r\nthree\r\nfour\r\n5\r\n", "data.bin": "\0theirs"]
        )

        // 我方新增指向文件的符号链接，对方新增同名的普通文件
        let runner = repository.runner
        _ = try await runner.run(["checkout", "-q", "side"])
        try await commit(repository, ["link": "regular\n"], message: "regular file")
        _ = try await runner.run(["checkout", "-q", "main"])

        try FileManager.default.createSymbolicLink(
            atPath: repository.directory.appending(path: "link").path,
            withDestinationPath: path
        )

        _ = try await runner.run(["add", "-A"])
        _ = try await runner.run(["commit", "-q", "-m", "symbolic link"])
        _ = try await runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

        let service = WorkingCopyOperations(runner: runner)
        let entries = Dictionary(uniqueKeysWithValues: try await runner.status().entries.map { ($0.path, $0) })

        try await service.resolveUsingBoth(try #require(entries[path]))

        // 工作区保持 CRLF，索引里是规范化后的 LF
        let merged = "one\nours\ntheirs\nthree\nfour\n5\n"
        let file = try Data(contentsOf: repository.directory.appending(path: path))

        #expect(file == Data(merged.replacingOccurrences(of: "\n", with: "\r\n").utf8))
        #expect(try await runner.run(["cat-file", "-p", ":" + path]) == Data(merged.utf8))

        let link = try #require(entries["link"])
        let stages = try #require(link.conflict)
        #expect(!stages.hasRegularFilesOnBothSides)

        await #expect(throws: ConflictResolutionError.versionUnavailable) {
            try await service.resolveUsingBoth(link)
        }

        #expect(try await runner.status().entries.first { $0.path == "link" }?.kind == .conflicted)

        // 二进制内容由 merge-file 拒绝合并，原样报告 Git 的错误，临时文件已经删除
        await #expect(throws: GitError.self) {
            try await service.resolveUsingBoth(try #require(entries["data.bin"]))
        }

        #expect(try await runner.status().entries.first { $0.path == "data.bin" }?.kind == .conflicted)
        #expect(try temporaryFiles(in: repository).isEmpty)
    }
}
