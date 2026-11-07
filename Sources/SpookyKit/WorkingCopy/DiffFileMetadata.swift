import Foundation

// MARK: - DiffFileMode

/// Git 扩展头中的六位八进制模式，原数值与文件类别分别保存。
public struct DiffFileMode: Sendable, Equatable, Hashable {
    /// 摘要支持的文件类别。
    public enum Kind: String, Sendable {
        /// 普通文件。
        case regular

        /// 可执行文件。
        case executable

        /// 符号链接。
        case symbolicLink

        /// 目录树。
        case directory

        /// 子模块。
        case submodule

        /// 不存在或其它合法模式。
        case unspecified = "none"
    }

    /// Git 输出的原始模式文本。
    public let value: String

    /// 模式对应的摘要类别。
    public var kind: Kind {
        switch value {
        case "100644": .regular
        case "100755": .executable
        case "120000": .symbolicLink
        case "040000": .directory
        case "160000": .submodule
        default: .unspecified
        }
    }

    /// 零模式表示该侧没有文件。
    public var exists: Bool { value != "000000" }

    /// 只接受六位八进制数字，不将损坏字段解释成普通文件。
    init?(_ value: String) {
        guard value.utf8.count == 6, value.utf8.allSatisfy({ (48 ... 55).contains($0) }) else { return nil }

        self.value = value
    }
}

// MARK: - DiffFileMetadata

/// 解析时提取的文件摘要信息；原始扩展头仍用于对象哈希与补丁写回。
public struct DiffFileMetadata: Sendable, Equatable {
    /// 已解码的重命名路径与相似度。
    public struct Rename: Sendable, Equatable {
        /// 原文件的完整相对路径。
        public let oldPath: String

        /// 新文件的完整相对路径。
        public let newPath: String

        /// Git 检测的百分比，范围为 0–100。
        public let similarity: Int
    }

    /// 各父侧的模式，按父顺序保留重复项和零模式。
    public let oldModes: [DiffFileMode]

    /// 结果侧的模式，缺失或无合法字段时为空。
    public let newMode: DiffFileMode?

    /// 新建文件的明确标记。
    public let isAdded: Bool

    /// 删除文件的明确标记。
    public let isDeleted: Bool

    /// 三个必需字段均合法时才保留重命名信息。
    public let rename: Rename?

    /// 从扩展头一次生成结构化元数据，不从有歧义的 diff 路径头猜测路径。
    init(headers: [String]) {
        let added = Self.value("new file mode ", in: headers).flatMap(DiffFileMode.init)
        let deleted = Self.value("deleted file mode ", in: headers).flatMap(Self.modes)
        isAdded = added != nil
        isDeleted = deleted != nil
        rename = Self.rename(in: headers)

        if let added {
            oldModes = []
            newMode = added
        } else if let deleted {
            oldModes = deleted
            newMode = nil
        } else if let combined = Self.value("mode ", in: headers) {
            let sides = combined.components(separatedBy: "..")
            oldModes = sides.count == 2 ? Self.modes(sides[0]) ?? [] : []
            newMode = sides.count == 2 ? DiffFileMode(sides[1]) : nil
        } else if headers.contains(where: { $0.hasPrefix("old mode ") || $0.hasPrefix("new mode ") }) {
            oldModes = Self.value("old mode ", in: headers).flatMap(DiffFileMode.init).map { [$0] } ?? []
            newMode = Self.value("new mode ", in: headers).flatMap(DiffFileMode.init)
        } else {
            let fields = Self.value("index ", in: headers)?.split(separator: " ") ?? []
            let mode = fields.count == 2 ? DiffFileMode(String(fields[1])) : nil
            let parentCount = fields.first?.components(separatedBy: "..").first?.split(separator: ",").count ?? 1
            oldModes = mode.map { Array(repeating: $0, count: parentCount) } ?? []
            newMode = mode
        }
    }

    /// 所有逐父模式都必须合法，不以部分列表替代损坏输入。
    private static func modes(_ value: String) -> [DiffFileMode]? {
        let parts = value.split(separator: ",", omittingEmptySubsequences: false)
        let result = parts.compactMap { DiffFileMode(String($0)) }
        return result.count == parts.count ? result : nil
    }

    /// 重命名只采信明确的两条路径头与合法相似度。
    private static func rename(in headers: [String]) -> Rename? {
        guard
            let old = value("rename from ", in: headers).flatMap(path),
            let new = value("rename to ", in: headers).flatMap(path),
            let similarity = value("similarity index ", in: headers),
            similarity.last == "%"
        else { return nil }

        let digits = similarity.dropLast()
        guard
            !digits.isEmpty,
            digits.utf8.allSatisfy({ (48 ... 57).contains($0) }),
            let percent = Int(digits),
            (0 ... 100).contains(percent)
        else { return nil }

        return Rename(oldPath: old, newPath: new, similarity: percent)
    }

    /// 保留路径空白与字节转义，闭引号必须是字段的最后一个字符。
    private static func path(_ value: String) -> String? {
        let decoded = value.hasPrefix("\"") ? PatchPreimage.unquoted(value, requiresEnd: true) : value
        guard let decoded, !decoded.isEmpty else { return nil }

        return decoded
    }

    /// 提取已知扩展头的值，保留值里的所有空白。
    private static func value(_ prefix: String, in headers: [String]) -> String? {
        headers.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }
}
