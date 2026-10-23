import Foundation

// MARK: - DiffSide

/// 工作区详情的两个比较方向。
public enum DiffSide: String, Sendable, CaseIterable {
    /// 暂存区相对 HEAD。
    case staged

    /// 工作区相对暂存区。
    case unstaged
}

// MARK: - WorkingCopyError

/// 补丁操作失败的明确类别，显示文案由 App 本地化。
public enum WorkingCopyError: Error, Sendable, Equatable {
    /// 文件或暂存区已经偏离生成补丁时的快照。
    case staleSnapshot

    /// 补丁结构或行数不符合统一 diff 格式。
    case malformedDiff

    /// 当前选择没有可应用的文本改动。
    case invalidSelection

    /// 目录或子模块不能当作普通文件丢弃。
    case unsupportedFile
}

// MARK: - DiffLine

/// 一行 diff 的原始字节与两侧行号，显示解码不影响补丁内容。
public struct DiffLine: Sendable, Equatable, Identifiable {
    /// 块内稳定序号。
    public let id: Int

    /// 空格、加号或减号。
    public let prefix: UInt8

    /// 不含 diff 前缀与换行符的内容，CRLF 的 CR 保留。
    public let content: Data

    /// 旧版行号；新增行为空。
    public let oldNumber: Int?

    /// 新版行号；删除行为空。
    public let newNumber: Int?

    /// 原文件此行没有末尾换行。
    public var noNewline = false

    /// 只有增删行可以参与按行操作。
    public var isChange: Bool { prefix == 43 || prefix == 45 }
}

// MARK: - DiffHunk

/// 一块带上下文的文本改动。
public struct DiffHunk: Sendable, Equatable, Identifiable {
    /// 文件内的块序号。
    public let id: Int

    /// Git 原始块标题，包含函数上下文。
    public let header: String

    /// 旧版范围起点。
    public let oldStart: Int

    /// 新版范围起点。
    public let newStart: Int

    /// 包含上下文与增删的行序列。
    public let lines: [DiffLine]
}

// MARK: - DiffFile

/// 一个文件的单个 diff 段；类型变化可能产生删除和新增两个段。
public struct DiffFile: Sendable, Equatable, Identifiable {
    /// 补丁内段序号。
    public let id: Int

    /// Git 原始扩展头，用于显示重命名、复制和模式变化。
    public let headers: [String]

    /// 二进制内容只显示提示。
    public let isBinary: Bool

    /// 新增文件模式，旧侧不存在时使用。
    public let addedMode: String?

    /// 删除文件模式，新侧不存在时使用。
    public let deletedMode: String?

    /// 可选择的文本改动块。
    public let hunks: [DiffHunk]
}

// MARK: - RepositoryDiff

/// 一次单文件 diff 的解析结果，保留多个段以表示类型变化。
public struct RepositoryDiff: Sendable, Equatable {
    /// 文件段按 Git 输出顺序排列。
    public let files: [DiffFile]

    /// 严格解析字节行，不从含歧义的 diff 头中猜测路径。
    public init(patch: Data) throws {
        if patch.isEmpty {
            files = []
            return
        }

        guard patch.last == 10 else { throw WorkingCopyError.malformedDiff }
        let lines = patch.dropLast().split(separator: 10, omittingEmptySubsequences: false).map(Data.init)
        var cursor = 0
        var files: [DiffFile] = []

        while cursor < lines.count {
            guard Self.text(lines[cursor]).hasPrefix("diff --git ") else {
                throw WorkingCopyError.malformedDiff
            }

            var headers: [String] = []
            var hunks: [DiffHunk] = []
            var binary = false
            var added: String?
            var deleted: String?

            repeat {
                let line = Self.text(lines[cursor])

                if line.hasPrefix("@@ ") {
                    hunks.append(try Self.hunk(lines, cursor: &cursor, id: hunks.count))
                    continue
                }

                guard hunks.isEmpty else { throw WorkingCopyError.malformedDiff }
                headers.append(line)
                binary = binary || line.hasPrefix("Binary files ") || line == "GIT binary patch"
                if line.hasPrefix("new file mode ") { added = String(line.dropFirst(14)) }
                if line.hasPrefix("deleted file mode ") { deleted = String(line.dropFirst(18)) }
                cursor += 1
            } while cursor < lines.count && !Self.text(lines[cursor]).hasPrefix("diff --git ")

            files.append(DiffFile(
                id: files.count,
                headers: headers,
                isBinary: binary,
                addedMode: added,
                deletedMode: deleted,
                hunks: hunks
            ))
        }

        self.files = files
    }

    /// 块内计数必须与标题完全一致，截断或损坏的输出不能成为可写补丁。
    private static func hunk(_ source: [Data], cursor: inout Int, id: Int) throws -> DiffHunk {
        let header = text(source[cursor])
        let parts = header.split(separator: " ")
        guard parts.count >= 4, parts[0] == "@@", parts[3] == "@@" else {
            throw WorkingCopyError.malformedDiff
        }

        let old = try range(parts[1], prefix: "-")
        let new = try range(parts[2], prefix: "+")
        var oldNumber = old.0
        var newNumber = new.0
        var oldCount = 0
        var newCount = 0
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

            if oldCount == old.1, newCount == new.1 { break }
            guard let prefix = raw.first, [32, 43, 45].contains(prefix) else {
                throw WorkingCopyError.malformedDiff
            }

            lines.append(DiffLine(
                id: lines.count,
                prefix: prefix,
                content: Data(raw.dropFirst()),
                oldNumber: prefix == 43 ? nil : oldNumber,
                newNumber: prefix == 45 ? nil : newNumber
            ))
            if prefix != 43 { oldNumber += 1
                oldCount += 1
            }
            if prefix != 45 { newNumber += 1
                newCount += 1
            }
            cursor += 1
        }

        guard oldCount == old.1, newCount == new.1 else { throw WorkingCopyError.malformedDiff }
        return DiffHunk(id: id, header: header, oldStart: old.0, newStart: new.0, lines: lines)
    }

    /// 缺省行数为 1，空文件范围允许起点和行数为 0。
    private static func range(_ value: Substring, prefix: Character) throws -> (Int, Int) {
        let parts = value.dropFirst().split(separator: ",", omittingEmptySubsequences: false)
        guard
            value.first == prefix,
            (1 ... 2).contains(parts.count),
            let start = Int(parts[0]),
            let count = parts.count == 2 ? Int(parts[1]) : 1,
            start >= 0, count >= 0, start <= Int.max - count
        else { throw WorkingCopyError.malformedDiff }
        return (start, count)
    }

    /// 头部只用于结构判断；正文始终保留 Data。
    private static func text(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self)
    }

    /// Git 的 C 风格路径引号按 UTF-8 字节编码控制字符。
    private static func quotedPath(_ path: String) -> String {
        var result = "\""

        for byte in path.utf8 {
            switch byte {
            case 34: result += "\\\""
            case 92: result += "\\\\"
            case 32 ... 126: result.append(Character(UnicodeScalar(byte)))
            default: result += String(format: "\\%03o", Int(byte))
            }
        }

        return result + "\""
    }

    /// 从选中块生成目标文件补丁，非连续行与无换行末行保持原始字节。
    public func patch(
        path: String,
        file index: Int,
        hunk hunkIndex: Int,
        selectedLines: Set<Int>,
        reverse: Bool
    ) throws -> Data {
        guard
            files.indices.contains(index),
            files[index].hunks.indices.contains(hunkIndex)
        else { throw WorkingCopyError.invalidSelection }

        let file = files[index]
        let hunk = file.hunks[hunkIndex]
        let selection = selectedLines.isEmpty
            ? Set(hunk.lines.filter(\.isChange).map(\.id))
            : selectedLines
        guard
            !selection.isEmpty,
            selection.allSatisfy({ id in hunk.lines.contains { $0.id == id && $0.isChange } })
        else { throw WorkingCopyError.invalidSelection }

        var body = Data()
        var oldCount = 0
        var newCount = 0

        // 正向保留旧侧，反向保留新侧；未选中的改动变为上下文或从补丁移除。
        for line in hunk.lines {
            var prefix = line.prefix

            if line.isChange, !selection.contains(line.id) {
                if prefix == (reverse ? 45 : 43) { continue }
                prefix = 32
            }

            if prefix != 43 { oldCount += 1 }
            if prefix != 45 { newCount += 1 }
            body.append(prefix)
            body.append(line.content)
            body.append(10)

            if line.noNewline {
                body.append(Data("\\ No newline at end of file\n".utf8))
            }
        }

        // 目标侧的行号是唯一锚点，另一侧按本块实际增量重算，避免前面块的偏移泄漏。
        let anchor = reverse ? hunk.newStart : hunk.oldStart
        let oldStart = oldCount == 0 ? max(0, anchor - (reverse ? 1 : 0)) : max(1, anchor)
        let newStart = newCount == 0 ? max(0, anchor - (reverse ? 0 : 1)) : max(1, anchor)
        let entireFile = file.hunks.count == 1 && selection == Set(hunk.lines.filter(\.isChange).map(\.id))
        let oldAbsent = file.addedMode != nil && (!reverse || entireFile)
        let newAbsent = file.deletedMode != nil && (reverse || entireFile)
        let oldPath = Self.quotedPath("a/" + path)
        let newPath = Self.quotedPath("b/" + path)
        var header = "diff --git \(oldPath) \(newPath)\n"

        if oldAbsent { header += "new file mode \(file.addedMode!)\n" }
        if newAbsent { header += "deleted file mode \(file.deletedMode!)\n" }
        header += "--- \(oldAbsent ? "/dev/null" : oldPath)\n"
        header += "+++ \(newAbsent ? "/dev/null" : newPath)\n"
        header += "@@ -\(oldAbsent ? 0 : oldStart),\(oldCount) +\(newAbsent ? 0 : newStart),\(newCount) @@\n"
        return Data(header.utf8) + body
    }

}
