import Foundation
import SpookyKit

// MARK: - MentionCompletion

/// 评论里 `@` 的补全：识别光标处正在输入的提及，从请求的参与者与项目成员里筛选候选。
enum MentionCompletion {
    /// 光标处正在输入的提及。
    struct Trigger: Equatable {
        /// `@` 之后、光标之前的查询。
        let query: String

        /// 选中候选后被替换的文字范围，从 `@` 到光标，以 UTF-16 计。
        let range: NSRange
    }

    /// 查找光标处的提及：光标前、空白之后的这个词里最后一个 `@`，它在词首，或前面不是字母、数字与下划线。
    ///
    /// 托管服务只把这样的 `@` 认作提及，邮箱地址里的不算。
    ///
    /// - Parameters:
    ///   - text: 评论的全文。
    ///   - caret: 光标的 UTF-16 位置。
    static func detect(in text: String, caret: Int) -> Trigger? {
        guard (0 ... text.utf16.count).contains(caret) else {
            return nil
        }

        let end = String.Index(utf16Offset: caret, in: text)
        let start = text[..<end].lastIndex(where: \.isWhitespace).map { text.index(after: $0) } ?? text.startIndex

        guard let mark = text[start ..< end].lastIndex(of: "@") else {
            return nil
        }

        if mark > start {
            let previous = text[text.index(before: mark)]

            guard !previous.isLetter, !previous.isNumber, previous != "_" else {
                return nil
            }
        }

        return Trigger(
            query: String(text[text.index(after: mark) ..< end]),
            range: NSRange(mark ..< end, in: text)
        )
    }

    /// 能提及的用户：请求的作者、评论的作者与指派人在前，项目成员在后。
    ///
    /// 用户名不分大小写相同的只留第一个；已删除的用户没有用户名，GitHub 上机器人的用户名以 `[bot]` 结尾，都不能提及。
    ///
    /// - Parameters:
    ///   - request: 正在评论的请求。
    ///   - comments: 请求下已有的评论。
    ///   - members: 项目的成员。
    static func candidates(
        for request: PullRequest,
        comments: [PullRequestComment],
        members: [HostingUser]
    ) -> [HostingUser] {
        var seen: Set<String> = []

        return ([request.author] + comments.map(\.author) + request.assignees + members).filter {
            !$0.username.isEmpty && !$0.username.hasSuffix("[bot]") && seen.insert($0.username.lowercased()).inserted
        }
    }

    /// 按查询筛选用户：用户名或显示名包含查询即命中，不区分大小写，保持传入的顺序。
    ///
    /// 选中后插入 `@用户名` 与一个空格，可以接着往下写。
    ///
    /// - Parameters:
    ///   - query: `@` 之后的查询；为空时列出全部。
    ///   - users: 能提及的用户。
    static func matches(_ query: String, in users: [HostingUser]) -> [CommitCompletion] {
        users
            .filter {
                query.isEmpty
                    || $0.username.localizedCaseInsensitiveContains(query)
                    || ($0.name?.localizedCaseInsensitiveContains(query) ?? false)
            }
            .map { CommitCompletion(id: "@" + $0.username, content: .user($0), insertion: "@" + $0.username + " ") }
    }
}
