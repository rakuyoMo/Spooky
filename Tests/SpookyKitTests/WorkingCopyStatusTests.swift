import Foundation
import Testing

@testable import SpookyKit

/// porcelain v2 输出的解析
struct WorkingCopyStatusTests {
    @Test("分支头信息：分支名、提交、上游、领先与落后")
    func branchHeaders() throws {
        let status = try WorkingCopyStatus(porcelainV2: output(
            "# branch.oid 1234567890abcdef1234567890abcdef12345678",
            "# branch.head main",
            "# branch.upstream origin/main",
            "# branch.ab +3 -1",
            "# stash 2"
        ))

        #expect(status.branch == BranchStatus(
            head: "main",
            oid: "1234567890abcdef1234567890abcdef12345678",
            upstream: "origin/main",
            ahead: 3,
            behind: 1
        ))

        #expect(status.entries.isEmpty)
    }

    @Test("还没有提交的新仓库，以及分离 HEAD")
    func initialAndDetached() throws {
        let status = try WorkingCopyStatus(porcelainV2: output(
            "# branch.oid (initial)",
            "# branch.head (detached)"
        ))

        #expect(status.branch.oid == nil)
        #expect(status.branch.head == nil)
    }

    @Test("各类条目：普通、重命名、冲突、未跟踪、忽略；路径里的空格与中文原样保留")
    func entries() throws {
        let status = try WorkingCopyStatus(porcelainV2: output(
            "1 M. N... 100644 100644 100644 aaaa bbbb src/a.swift",
            "1 .D N... 100644 100644 000000 aaaa aaaa src/b.swift",
            "2 R. N... 100644 100644 100644 aaaa aaaa R100 docs/新 名字.md",
            "docs/old name.md",
            "u UU N... 100644 100644 100644 100644 aaaa bbbb cccc conflict.txt",
            "? notes/草稿 1.txt",
            "! build/out.o"
        ))

        #expect(status.entries == [
            StatusEntry(
                kind: .tracked,
                path: "src/a.swift",
                originalPath: nil,
                staged: .modified,
                unstaged: nil
            ),
            StatusEntry(
                kind: .tracked,
                path: "src/b.swift",
                originalPath: nil,
                staged: nil,
                unstaged: .deleted
            ),
            StatusEntry(
                kind: .tracked,
                path: "docs/新 名字.md",
                originalPath: "docs/old name.md",
                staged: .renamed,
                unstaged: nil
            ),
            StatusEntry(
                kind: .conflicted,
                path: "conflict.txt",
                originalPath: nil,
                staged: .unmerged,
                unstaged: .unmerged
            ),
            StatusEntry(
                kind: .untracked,
                path: "notes/草稿 1.txt",
                originalPath: nil,
                staged: nil,
                unstaged: nil
            ),
            StatusEntry(
                kind: .ignored,
                path: "build/out.o",
                originalPath: nil,
                staged: nil,
                unstaged: nil
            ),
        ])
    }

    @Test("格式不对的记录抛出 StatusParseError")
    func malformedRecords() {
        #expect(throws: StatusParseError(record: "1 M.")) {
            try WorkingCopyStatus(porcelainV2: output("1 M."))
        }

        #expect(throws: StatusParseError(record: "1 X. N... 100644 100644 100644 aaaa bbbb a.txt")) {
            try WorkingCopyStatus(porcelainV2: output("1 X. N... 100644 100644 100644 aaaa bbbb a.txt"))
        }

        // 重命名记录后面缺了原路径
        #expect(throws: StatusParseError.self) {
            try WorkingCopyStatus(porcelainV2: output("2 R. N... 100644 100644 100644 aaaa aaaa R100 new.txt"))
        }
    }

    /// 空路径、截断记录与损坏的分支计数都必须让整份快照失败。
    @Test("损坏的分隔符、路径和分支头", arguments: [
        "? missing terminator",
        "?\0",
        "? \0",
        "?file\0",
        "? file\0\0",
        "# branch.ab +x -1\0",
        "# branch.ab +1\0",
        "# branch.ab 1 -2\0",
        "# branch.head\0",
        "# branch.oid invalid\0",
        "2 R. N... 100644 100644 100644 aaaa aaaa R100 new.txt\0\0",
        "1 M. N... 100644 100644 100644 aaaa bbbb \0",
    ])
    func truncatedAndMalformed(_ record: String) {
        #expect(throws: StatusParseError.self) {
            try WorkingCopyStatus(porcelainV2: Data(record.utf8))
        }
    }

    /// 把若干条记录按 `-z` 的格式拼成 git 的输出：每条以 NUL 结尾
    private func output(_ records: String...) -> Data {
        Data(records.map { $0 + "\0" }.joined().utf8)
    }

}
