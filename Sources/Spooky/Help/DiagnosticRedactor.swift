import Foundation

// MARK: - DiagnosticRedactor

/// 诊断报告与崩溃报告离开这台 Mac 之前的脱敏：主目录与用户名、邮箱、地址里的账号口令、令牌与 IP 地址换成占位文字。
enum DiagnosticRedactor {
    /// 依次替换的规则：正则与替换成的文字。
    private static let rules: [(pattern: String, replacement: String)] = [
        // 地址里的账号与口令，如 https://user:token@host
        (#"(?<=://)[^/\s:@]+:[^/\s@]+@"#, "<credentials>@"),
        (#"\bgh[pousr]_[A-Za-z0-9]{20,}\b"#, "<token>"),
        (#"\bglpat-[A-Za-z0-9_\-]{20,}\b"#, "<token>"),
        (#"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#, "<email>"),
        (#"/Users/[^/\s"']+"#, "/Users/<user>"),
        (#"\b(?:\d{1,3}\.){3}\d{1,3}\b"#, "<ip>"),
    ]

    /// 脱敏后的文字。
    ///
    /// - Parameters:
    ///   - text: 原文。
    ///   - home: 当前用户的主目录，换成 `~`。
    ///   - userName: 当前用户的短名，单独出现时换成占位文字。
    static func redact(_ text: String, home: String = NSHomeDirectory(), userName: String = NSUserName()) -> String {
        var result = text.replacingOccurrences(of: home, with: "~")

        for rule in rules {
            result = result.replacingOccurrences(of: rule.pattern, with: rule.replacement, options: .regularExpression)
        }

        // 太短的用户名会误伤普通单词，只替换至少三个字符的
        guard userName.count >= 3 else {
            return result
        }

        return result.replacingOccurrences(
            of: "\\b" + NSRegularExpression.escapedPattern(for: userName) + "\\b",
            with: "<user>",
            options: .regularExpression
        )
    }
}
