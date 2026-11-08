import Foundation
import Testing

@testable import SpookyKit

// MARK: - WorkingCopyStatusRecordsTests

/// 原始状态读取与普通展示共用严格解析，路径过滤不能丢失模式、哈希或重复条目。
struct WorkingCopyStatusRecordsTests {
    /// 由隔离 Git 2.54、固定身份与 2000-01-01 时间生成的完整输出。
    struct Fixture: Decodable {
        /// Git 对象哈希格式。
        let format: String

        /// 包含 NUL 的原始状态字节。
        let raw: Data
    }

    /// 两种对象格式的真实输出覆盖普通、双 NUL 重命名、冲突、子模块、未跟踪、忽略和同路径双条目，
    /// 原始记录完整保留；原始读取不能比既有状态解析宽松，也不能额外拒绝既有允许的普通对象字段。
    @Test("原始状态记录的解析与严格校验")
    func parsing() throws {
        let fixtures = try Self.fixtures()
        #expect(fixtures.map(\.format) == ["sha1", "sha256"])

        for fixture in fixtures {
            let parsed = try WorkingCopyStatus.records(in: fixture.raw)
            let status = try WorkingCopyStatus(porcelainV2: fixture.raw)

            #expect(parsed.branch == status.branch)
            #expect(parsed.records.compactMap(\.entry) == status.entries)
            #expect(parsed.records.reduce(into: Data()) { $0.append($1.raw) } == fixture.raw)
            #expect(status.branch.oid?.count == (fixture.format == "sha1" ? 40 : 64))

            // 同一路径的删除与未跟踪是两条记录
            let duplicate = parsed.records.filter { $0.entry?.path == "duplicate" }
            #expect(duplicate.count == 2)
            #expect(duplicate[0].entry?.staged == .deleted)
            #expect(duplicate[1].entry?.kind == .untracked)

            // 冲突、忽略与子模块的记录都在
            #expect(status.entries.contains { $0.kind == .conflicted && $0.conflict != nil })
            #expect(status.entries.contains { $0.kind == .ignored })
            #expect(
                parsed.records.contains {
                    $0.entry?.path == "module" && String(decoding: $0.raw, as: UTF8.self).contains("S")
                }
            )

            // 重命名记录带两个 NUL，两侧路径里的控制字符原样保留
            let rename = try #require(parsed.records.first { $0.entry?.originalPath != nil })
            #expect(rename.raw.filter { $0 == 0 }.count == 2)
            #expect(rename.entry?.originalPath == "old\tname\n[*]")
            #expect(rename.entry?.path == "新 café\t\nname")
        }

        // 普通记录可以解析，截断、字段缺失或取值不合法的记录两种入口都拒绝
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
            #expect(throws: StatusParseError.self) {
                try WorkingCopyStatus.records(in: Data(malformed.utf8))
            }
            #expect(throws: StatusParseError.self) {
                try WorkingCopyStatus(porcelainV2: Data(malformed.utf8))
            }
        }
    }

    /// 快照经生产取样入口按所选路径保留完整记录：同一路径的删除记录与未跟踪记录都留下，
    /// 固定的真实 Git 输出只留所选路径的记录并丢弃分支头和其它文件；排除计划按原始字节判断变化，
    /// NFC 与 NFD 在 Git 中不是同一个路径。
    @Test("快照按路径保留完整原始记录")
    func scope() async throws {
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }

        try await fixture.repository.initialize()

        // 已提交的文件移出索引后，同一路径同时是暂存的删除与未跟踪文件
        try fixture.write(Data("file\n".utf8), path: "file")
        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-qm", "base"])
        _ = try await fixture.runner.run(["rm", "--cached", "--", "file"])

        let entry = try #require(try await fixture.runner.status().entries.first { $0.kind == .tracked })
        let duplicate = try await fixture.service.scope(for: entry)
        let pair = try WorkingCopyStatus.records(in: duplicate.status).records

        #expect(pair.compactMap(\.entry).map(\.path) == ["file", "file"])
        #expect(pair[0].entry?.staged == .deleted)
        #expect(pair[1].entry?.kind == .untracked)

        let status = try await fixture.runner.run(["status", "--porcelain=v2", "-z", "--untracked-files=all"])
        #expect(duplicate.status == status)

        // 状态读取换成固定的真实输出，逐条记录取范围
        let runner = try fixture.wrappedRunner(after: """
            if [ "$kind" = status ]; then cp "$root/records" "$output"; fi
            """)
        let service = WorkingCopyOperations(runner: runner)

        for input in try Self.fixtures() {
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

        // 路径计划按字节比较
        let first = WorkingCopyDiffScope(status: Data(), staged: ["café"], unstaged: ["new"])
        let second = WorkingCopyDiffScope(status: Data(), staged: ["cafe\u{301}"], unstaged: ["new"])
        #expect(!first.hasSamePaths(as: second))
        #expect(first.hasSamePaths(as: first))
    }
}

// MARK: - Helpers

extension WorkingCopyStatusRecordsTests {
    /// 读取两种对象格式的固定状态输出。
    private static func fixtures() throws -> [Fixture] {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/status-records.json")

        return try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    }
}
