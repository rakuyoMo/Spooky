import Foundation

// MARK: - CommitMessage

/// 提交信息的文本规则：拼接、注释行与按字数折行；结果统一为 NFC。
public enum CommitMessage {
    /// 标题与正文拼成 Git 接受的信息，正文与标题之间空一行。
    public static func text(subject: String, body: String) -> String {
        (subject + (body.isEmpty ? "\n" : "\n\n" + body + "\n")).precomposedStringWithCanonicalMapping
    }

    /// 把完整信息拆回标题与正文：第一行是标题，其余去掉首尾空行后是正文。
    public static func parts(of message: String) -> (subject: String, body: String) {
        let lines = message.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let subject = lines.first.map(String.init) ?? ""
        let body = lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .newlines) : ""
        return (subject, body)
    }

    /// 是否有以注释前缀开头的行；前缀为 nil 时没有注释行。
    public static func hasComments(_ message: String, prefix: String?) -> Bool {
        guard let prefix else {
            return false
        }

        return message.split(separator: "\n", omittingEmptySubsequences: false).contains { $0.hasPrefix(prefix) }
    }

    /// 去掉以注释前缀开头的整行，与 Git 的 strip 清理使用同一判定：前缀必须位于行首。
    public static func removingComments(_ message: String, prefix: String?) -> String {
        guard let prefix else {
            return message
        }

        return message.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix(prefix) }
            .joined(separator: "\n")
    }

    /// 把单个段落在空格处断开，使每行不超过上限；比上限还长的单词独占一行，不从中间截断。
    ///
    /// - Parameters:
    ///   - paragraph: 不含换行的一行文字。
    ///   - limit: 每行字数上限，按字符计。
    public static func wrapped(_ paragraph: String, limit: Int) -> String {
        guard limit > 0, paragraph.count > limit else {
            return paragraph
        }

        var lines: [String] = []
        var current: String?

        // 只把作为分隔的那个空格换成换行；行首缩进只由空格组成，继续留在第一行。
        for word in paragraph.split(separator: " ", omittingEmptySubsequences: false) {
            guard let line = current else {
                current = String(word)
                continue
            }

            if !line.trimmingCharacters(in: .whitespaces).isEmpty, line.count + 1 + word.count > limit {
                lines.append(line)
                current = String(word)
            } else {
                current = line + " " + word
            }
        }

        lines.append(current ?? "")
        return lines.joined(separator: "\n").precomposedStringWithCanonicalMapping
    }

    /// 硬折行模式下提交的正文：每个超长的段落按上限断行。
    public static func hardWrapped(_ body: String, limit: Int) -> String {
        body.split(separator: "\n", omittingEmptySubsequences: false)
            .map { wrapped(String($0), limit: limit) }
            .joined(separator: "\n")
    }
}
