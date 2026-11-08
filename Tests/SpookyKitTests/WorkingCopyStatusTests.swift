import Foundation
import Testing

@testable import SpookyKit

// MARK: - WorkingCopyStatusTests

/// porcelain v2 输出的解析
struct WorkingCopyStatusTests {
    /// 分支头的名字、提交、上游与领先落后，新仓库与分离 HEAD，以及各类条目；
    /// 路径里的空格与中文原样保留，复制记录独立于来源文件，NFC 与 NFD 写法的路径比较时等价。
    @Test("分支头、新仓库与分离 HEAD、各类条目与复制记录")
    func parsing() throws {
        let headers = try WorkingCopyStatus(porcelainV2: output(
            "# branch.oid 1234567890abcdef1234567890abcdef12345678",
            "# branch.head main",
            "# branch.upstream origin/main",
            "# branch.ab +3 -1",
            "# stash 2"
        ))

        #expect(headers.branch == BranchStatus(
            head: "main",
            oid: "1234567890abcdef1234567890abcdef12345678",
            upstream: "origin/main",
            ahead: 3,
            behind: 1
        ))
        #expect(headers.entries.isEmpty)

        // 还没有提交的新仓库，以及分离 HEAD
        let initial = try WorkingCopyStatus(porcelainV2: output(
            "# branch.oid (initial)",
            "# branch.head (detached)"
        ))

        #expect(initial.branch.oid == nil)
        #expect(initial.branch.head == nil)

        // 普通、重命名、冲突、未跟踪、忽略
        let status = try WorkingCopyStatus(porcelainV2: output(
            "1 M. N... 100644 100644 100644 aaaa bbbb src/a.swift",
            "1 .D N... 100644 100644 000000 aaaa aaaa src/b.swift",
            "2 R. N... 100644 100644 100644 aaaa aaaa R100 docs/新 名字.md",
            "docs/old name.md",
            "u UU N... 100644 100644 100644 100644 aaaa bbbb cccc conflict.txt",
            "? notes/草稿 1.txt",
            "! build/out.o"
        ))

        #expect(status.entries == expectedEntries)

        // 复制记录的操作路径只有副本本身
        let copied = try WorkingCopyStatus(porcelainV2: output(
            "2 C. N... 100644 100644 100644 aaaa aaaa C100 café.txt",
            "source.txt"
        ))
        let copy = try #require(copied.entries.first)

        #expect(copy.staged == .copied)
        #expect(copy.path == "cafe\u{301}.txt")
        #expect(copy.operationPaths == ["café.txt"])
    }

    /// 格式不对的记录、空路径、截断记录与损坏的分支计数都必须让整份快照失败。
    @Test("格式不对的记录、分隔符、路径和分支头")
    func malformed() {
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

        // 原样的输出字节，包括缺少终止符与多余的 NUL
        let records = [
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
        ]

        for record in records {
            #expect(throws: StatusParseError.self) {
                try WorkingCopyStatus(porcelainV2: Data(record.utf8))
            }
        }
    }
}

// MARK: - Helpers

extension WorkingCopyStatusTests {
    /// 各类条目记录对应的期望模型，顺序与输出一致。
    private var expectedEntries: [StatusEntry] {
        [
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
                unstaged: .unmerged,
                conflict: ConflictStages(
                    base: "aaaa",
                    ours: "bbbb",
                    theirs: "cccc",
                    existsInWorktree: true,
                    baseMode: "100644",
                    oursMode: "100644",
                    theirsMode: "100644"
                )
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
        ]
    }

    /// 把若干条记录按 `-z` 的格式拼成 git 的输出：每条以 NUL 结尾
    private func output(_ records: String...) -> Data {
        Data(records.map { $0 + "\0" }.joined().utf8)
    }
}
