import Foundation
import Testing

@testable import SpookyKit

/// 原始状态读取与普通展示共用严格解析，路径过滤不能丢失模式、哈希或重复条目。
struct WorkingCopyStatusRecordsTests {
    /// 由隔离 Git 2.54、固定身份与 2000-01-01 时间生成的完整输出。
    struct Fixture: Decodable {
        /// Git 对象哈希格式。
        let format: String

        /// 包含 NUL 的原始状态字节。
        let raw: Data
    }

    /// 两种对象格式覆盖普通、双 NUL 重命名、冲突、子模块、未跟踪、忽略和同路径双条目。
    @Test("原始状态记录完整保留真实 Git 输出")
    func fixtures() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/status-records.json")
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        #expect(fixtures.map(\.format) == ["sha1", "sha256"])

        for fixture in fixtures {
            let parsed = try WorkingCopyStatus.records(in: fixture.raw)
            let status = try WorkingCopyStatus(porcelainV2: fixture.raw)
            #expect(parsed.branch == status.branch)
            #expect(parsed.records.compactMap(\.entry) == status.entries)
            #expect(parsed.records.reduce(into: Data()) { $0.append($1.raw) } == fixture.raw)
            #expect(status.branch.oid?.count == (fixture.format == "sha1" ? 40 : 64))
            let duplicate = parsed.records.filter { $0.entry?.path == "duplicate" }
            #expect(duplicate.count == 2)
            #expect(duplicate[0].entry?.staged == .deleted)
            #expect(duplicate[1].entry?.kind == .untracked)
            #expect(status.entries.contains { $0.kind == .conflicted && $0.conflict != nil })
            #expect(status.entries.contains { $0.kind == .ignored })
            #expect(
                parsed.records
                    .contains { $0.entry?.path == "module" && String(decoding: $0.raw, as: UTF8.self).contains("S") }
            )
            let rename = try #require(parsed.records.first { $0.entry?.originalPath != nil })
            #expect(rename.raw.filter { $0 == 0 }.count == 2)
            #expect(rename.entry?.originalPath == "old\tname\n[*]")
            #expect(rename.entry?.path == "新 café\t\nname")
        }
    }

    /// 过滤后的快照仍包含同一路径的删除记录和未跟踪记录。
    @Test("快照保留同一路径的全部原始状态", arguments: ["sha1", "sha256"])
    func duplicateScope(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize(objectFormat: objectFormat)
        try Data("file\n".utf8).write(to: fixture.directory.appending(path: "file"))
        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-qm", "base"])
        _ = try await fixture.runner.run(["rm", "--cached", "--", "file"])
        let entries = try await fixture.runner.status().entries
        let entry = try #require(entries.first { $0.kind == .tracked })
        let scope = try await WorkingCopyOperations(runner: fixture.runner).scope(for: entry)
        let records = try WorkingCopyStatus.records(in: scope.status).records
        #expect(records.compactMap(\.entry).map(\.path) == ["file", "file"])
        #expect(records[0].entry?.staged == .deleted)
        #expect(records[1].entry?.kind == .untracked)
        let expected = try await fixture.runner.run(["status", "--porcelain=v2", "-z", "--untracked-files=all"])
        #expect(scope.status == expected)
    }

    /// 固定的真实 Git 输出经过生产取样入口，按所选路径保留完整记录并丢弃分支头和其它文件。
    @Test("快照过滤完整原始记录")
    func filteredRecords() async throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/status-records.json")
        let inputs = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }
        try await fixture.repository.initialize()
        let runner = try fixture.wrappedRunner(after: """
            if [ "$kind" = status ]; then cp "$root/records" "$output"; fi
            """)
        let service = WorkingCopyOperations(runner: runner)

        for input in inputs {
            try fixture.write(input.raw, path: ".git/records")
            let records = try WorkingCopyStatus.records(in: input.raw).records

            for record in records {
                guard let entry = record.entry else { continue }

                let scope = try await service.scope(for: entry)
                let expected = entry.path == "duplicate"
                    ? records.filter { $0.entry?.path == "duplicate" }.reduce(into: Data()) { $0.append($1.raw) }
                    : record.raw
                #expect(scope.status == expected)
            }
        }
    }

    /// 原始读取不能比既有状态解析宽松，也不能额外拒绝既有允许的普通对象字段。
    @Test("原始状态记录严格校验")
    func malformed() throws {
        let ordinary = "1 M. N... 100644 100644 100644 123 456 file\0"
        #expect(try WorkingCopyStatus.records(in: Data(ordinary.utf8)).records.count == 1)

        for malformed in [
            String(ordinary.dropLast()),
            ordinary + "1 broken\0",
            "1 Z. N... 100644 100644 100644 123 456 file\0",
            "1 M.  100644 100644 100644 123 456 file\0",
            "1 M. N... 100644 100644 100644 123 456 \0",
            "2 R. N... 100644 100644 100644 123 456 R100 new\0",
            "2 R. N... 100644 100644 100644 123 456 R100 new\0\0",
            "? \0", "! \0", "u UU broken\0", "\0",
        ] {
            #expect(throws: StatusParseError.self) { try WorkingCopyStatus.records(in: Data(malformed.utf8)) }
            #expect(throws: StatusParseError.self) { try WorkingCopyStatus(porcelainV2: Data(malformed.utf8)) }
        }
    }

    /// 排除计划按原始字节判断变化，NFC 与 NFD 在 Git 中不是同一个路径。
    @Test("动态路径计划不折叠 Unicode 字节")
    func byteIdentity() {
        let first = WorkingCopyDiffScope(status: Data(), staged: ["café"], unstaged: ["new"])
        let second = WorkingCopyDiffScope(status: Data(), staged: ["cafe\u{301}"], unstaged: ["new"])
        #expect(!first.hasSamePaths(as: second))
        #expect(first.hasSamePaths(as: first))
    }
}
