import Foundation

// MARK: - Combined Diff

extension RepositoryDiff {
    /// 普通补丁的文件段以 `diff --git` 开头，合并提交的组合 Diff 以 `diff --combined` 或 `diff --cc` 开头。
    static func isFileHeader(_ line: Data) -> Bool {
        ["diff --git ", "diff --combined ", "diff --cc "].contains { line.starts(with: Data($0.utf8)) }
    }

    /// 组合 Diff 的块：块头有 “父提交数 + 1” 个 `@`，每行前面每个父提交各一列标记。
    ///
    /// 只读显示折成单列：任一列为 “-” 的行是删除行，否则任一列为 “+” 的行是新增行；
    /// 旧行号按第一父提交计，新增行与只在其它父提交里的删除行没有旧行号。
    static func combinedHunk(_ source: [Data], cursor: inout Int, id: Int) throws -> DiffHunk {
        let header = text(source[cursor])
        let marker = header.prefix { $0 == "@" }
        let parents = marker.count - 1
        let parts = header.split(separator: " ")

        guard
            parents >= 2,
            parts.count >= parents + 3,
            parts[0] == marker,
            parts[parents + 2] == marker
        else { throw WorkingCopyError.malformedDiff }

        // 每个父提交与合并结果各有一个范围，全部计数都用完时块才结束
        let olds = try (1 ... parents).map { try range(parts[$0], prefix: "-") }
        let new = try range(parts[parents + 1], prefix: "+")
        var counter = CombinedLineCounter(parents: parents, oldStart: olds[0].0, newStart: new.0)
        var lines: [DiffLine] = []
        cursor += 1

        while cursor < source.count {
            let raw = source[cursor]

            if raw == Data("\\ No newline at end of file".utf8) {
                guard !lines.isEmpty, !lines[lines.count - 1].noNewline else {
                    throw WorkingCopyError.malformedDiff
                }

                lines[lines.count - 1].noNewline = true
                cursor += 1
                continue
            }

            if counter.oldCounts == olds.map(\.1), counter.newCount == new.1 { break }

            lines.append(try counter.line(raw, id: lines.count))
            cursor += 1
        }

        guard counter.oldCounts == olds.map(\.1), counter.newCount == new.1 else {
            throw WorkingCopyError.malformedDiff
        }

        return DiffHunk(id: id, header: header, oldStart: olds[0].0, newStart: new.0, lines: lines)
    }
}

// MARK: - CombinedLineCounter

/// 组合 Diff 块内的行号与各侧行数。
private struct CombinedLineCounter {
    /// 父提交数，即每行前面的标记列数。
    let parents: Int

    /// 每个父提交已读到的行数。
    private(set) var oldCounts: [Int]

    /// 合并结果已读到的行数。
    private(set) var newCount = 0

    /// 下一行在第一父提交里的行号。
    private var oldNumber: Int

    /// 下一行在合并结果里的行号。
    private var newNumber: Int

    /// 从块头给出的起点开始计数。
    init(parents: Int, oldStart: Int, newStart: Int) {
        self.parents = parents
        oldCounts = Array(repeating: 0, count: parents)
        oldNumber = oldStart
        newNumber = newStart
    }

    /// 把一行折成单列的 Diff 行，并推进各侧计数。
    mutating func line(_ raw: Data, id: Int) throws -> DiffLine {
        let columns = Array(raw.prefix(parents))

        guard
            columns.count == parents,
            columns.allSatisfy({ [32, 43, 45].contains($0) })
        else { throw WorkingCopyError.malformedDiff }

        let removed = columns.contains(45)
        let prefix: UInt8 = removed ? 45 : (columns.contains(43) ? 43 : 32)

        // 第 i 个父提交里有这一行：该列是 “-”，或这一行不是删除行且该列是空格
        let present = columns.map { $0 == 45 || (!removed && $0 == 32) }

        let line = DiffLine(
            id: id,
            prefix: prefix,
            content: Data(raw.dropFirst(parents)),
            oldNumber: present[0] && prefix != 43 ? oldNumber : nil,
            newNumber: removed ? nil : newNumber
        )

        for index in present.indices where present[index] {
            oldCounts[index] += 1
        }

        if present[0] {
            oldNumber += 1
        }

        if !removed {
            newNumber += 1
            newCount += 1
        }

        return line
    }
}
