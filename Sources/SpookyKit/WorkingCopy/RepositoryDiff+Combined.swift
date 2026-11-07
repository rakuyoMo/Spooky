import Foundation

// MARK: - Combined Diff

extension RepositoryDiff {
    /// 普通补丁的文件段以 `diff --git` 开头，合并提交的组合 Diff 以 `diff --combined` 或 `diff --cc` 开头。
    static func isFileHeader(_ line: Data) -> Bool {
        ["diff --git ", "diff --combined ", "diff --cc "].contains { line.starts(with: Data($0.utf8)) }
    }

    /// 组合块保留每个父提交及结果的范围；双侧行号仍表示第一父提交与结果。
    static func combinedHunk(_ source: [Data], cursor: inout Int, id: Int) throws -> DiffHunk {
        let start = cursor
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

        // 每个父提交与合并结果各有一个范围，全部计数都用完时块才结束。
        let ranges = try (1 ... parents + 1).map {
            let value = try range(parts[$0], prefix: $0 <= parents ? "-" : "+")
            return CombinedDiffRange(start: value.0, count: value.1)
        }
        var counter = CombinedLineCounter(ranges: ranges)
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

            if counter.isComplete { break }

            lines.append(try counter.line(raw, id: lines.count))
            cursor += 1
        }

        guard counter.isComplete else { throw WorkingCopyError.malformedDiff }

        return DiffHunk(
            id: id,
            header: header,
            oldStart: ranges[0].start,
            newStart: ranges[parents].start,
            lines: lines,
            rawContent: rawContent(source[start ..< cursor]),
            combinedRanges: ranges
        )
    }
}

// MARK: - CombinedLineCounter

/// 组合 Diff 块内的行号与各侧行数。
private struct CombinedLineCounter {
    /// 每个父提交与结果侧的范围，结果始终在最后。
    let ranges: [CombinedDiffRange]

    /// 每侧已读到的行数。
    private var counts: [Int]

    /// 每侧当前显示行号，未推进的侧保持上一行号。
    private var numbers: [Int]

    /// 所有侧均消耗完整范围后，块才完整。
    var isComplete: Bool { counts == ranges.map(\.count) }

    /// 组合零范围同样以起点前一行为显示锚点。
    init(ranges: [CombinedDiffRange]) {
        self.ranges = ranges
        counts = Array(repeating: 0, count: ranges.count)
        numbers = ranges.map { max(0, $0.start - 1) }
    }

    /// 按真实存在关系推进各侧，保留全部前缀与兼容双侧投影。
    mutating func line(_ raw: Data, id: Int) throws -> DiffLine {
        let parents = ranges.count - 1
        let columns = Array(raw.prefix(parents))

        guard
            columns.count == parents,
            columns.allSatisfy({ [32, 43, 45].contains($0) }),
            !(columns.contains(43) && columns.contains(45))
        else { throw WorkingCopyError.malformedDiff }

        let removed = columns.contains(45)
        let prefix: UInt8 = removed ? 45 : (columns.contains(43) ? 43 : 32)

        // 删除行只存在于带减号的父侧；其它行存在于空格父侧和结果侧。
        let present = columns.map { $0 == 45 || (!removed && $0 == 32) } + [!removed]

        for index in present.indices where present[index] {
            guard counts[index] < ranges[index].count else { throw WorkingCopyError.malformedDiff }

            numbers[index] = ranges[index].start + counts[index]
            counts[index] += 1
        }

        return DiffLine(
            id: id,
            prefix: prefix,
            content: Data(raw.dropFirst(parents)),
            oldNumber: present[0] && prefix != 43 ? numbers[0] : nil,
            newNumber: removed ? nil : numbers[parents],
            combined: CombinedDiffLine(prefixes: columns, numbers: numbers)
        )
    }
}
