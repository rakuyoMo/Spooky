import Foundation
import Testing

@testable import SpookyKit

// MARK: - Items

extension RevisionExportTests {
    /// 条目导出进已有的目录时放在它在仓库里的相对位置上：同名文件与目录被替换，目录里的其它内容保留，缺少的上层目录随之创建；
    /// 有的条目写不进目标时其余条目照常导出，没写进去的条目连同原因一并报告。
    @Test("导出条目进已有目录：替换同名条目、保留其余内容、部分失败如实报告")
    func exportItemsIntoFolder() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let special = "深い/目录 [*]/文件 '\"?.txt"

        let revision = try await Self.commit(
            fixture,
            files: [
                special: Data("special\n".utf8),
                "dir/a.txt": Data("new a\n".utf8),
                "dir/sub/b.txt": Data("b\n".utf8),
                "top.txt": Data("new top\n".utf8),
                "locked/x.txt": Data("x\n".utf8),
            ]
        )

        let output = try Self.outputDirectory()
        defer { try? FileManager.default.removeItem(at: output) }

        // 目标里已有同名的文件与其它内容
        try Self.write(["dir/a.txt": "old a\n", "dir/keep.txt": "keep\n", "top.txt": "old top\n"], in: output)

        let export = RevisionExport(runner: fixture.runner)

        // 已存在的条目按传入顺序列出，没有的不列
        #expect(RevisionExport.existingItems([special, "top.txt", "dir"], in: output) == ["top.txt", "dir"])

        // 同名文件被替换，同一目录里的其它文件保留，缺少的上层目录随之创建
        try await export.export(revision, paths: ["dir/a.txt", "top.txt", special], into: output)

        #expect(try String(contentsOf: output.appending(path: "dir/a.txt"), encoding: .utf8) == "new a\n")
        #expect(try String(contentsOf: output.appending(path: "dir/keep.txt"), encoding: .utf8) == "keep\n")
        #expect(try String(contentsOf: output.appending(path: "top.txt"), encoding: .utf8) == "new top\n")
        #expect(try String(contentsOf: output.appending(path: special), encoding: .utf8) == "special\n")

        // 目录条目整个替换；目录里的文件同时被选中时随目录一起导出，不算失败
        try await export.export(revision, paths: ["dir", "dir/a.txt"], into: output)

        let entries = try FileManager.default.contentsOfDirectory(atPath: output.appending(path: "dir").path)

        #expect(entries.sorted() == ["a.txt", "sub"])

        // 写不进只读目录的条目连同原因报告，其余条目照常导出
        let locked = output.appending(path: "locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        try Self.write(["top.txt": "old top\n"], in: output)

        let failure = await #expect(throws: RevisionExportFailure.self) {
            try await export.export(revision, paths: ["locked/x.txt", "top.txt"], into: output)
        }

        #expect(failure?.items.map(\.path) == ["locked/x.txt"])
        #expect(!(failure?.items.first?.reason.isEmpty ?? true))
        #expect(try String(contentsOf: output.appending(path: "top.txt"), encoding: .utf8) == "new top\n")
        #expect(try FileManager.default.contentsOfDirectory(atPath: locked.path).isEmpty)
    }
}

// MARK: - Helpers

extension RevisionExportTests {
    /// 在目录里按相对路径写入文本文件，缺少的上层目录随之创建。
    static func write(_ files: [String: String], in folder: URL) throws {
        for (path, content) in files {
            let url = folder.appending(path: path)

            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            try Data(content.utf8).write(to: url)
        }
    }
}
