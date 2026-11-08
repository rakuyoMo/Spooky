import Foundation

// MARK: - RemoteAddress

/// 远端地址的主机：本机仓库的自动获取跳过解析不出主机的远端。
public enum RemoteAddress {
    /// 写得出主机的 URL 协议。
    private static let schemes: Set = ["ssh", "git", "http", "https", "ftp", "ftps"]

    /// 按 Git 的地址写法取出主机。
    ///
    /// - `<协议>://[用户@]主机[:端口]/路径`：协议限 ssh、git、http(s)、ftp(s)，IPv6 主机写在方括号里
    /// - scp 写法 `[用户@]主机:路径`：第一个 “:” 之前没有 “/” 时成立；主机带端口或是 IPv6 时整段写在方括号里
    /// - `file://`、本机路径与 `<传输>::<地址>` 等写不出主机的地址为 nil
    ///
    /// - Parameter url: `git remote get-url` 读出的地址。
    public static func host(in url: String) -> String? {
        if let range = url.range(of: "://") {
            let scheme = url[..<range.lowerBound].lowercased()

            guard schemes.contains(scheme) else {
                return nil
            }

            let authority = url[range.upperBound...].prefix { $0 != "/" }
            return host(inAuthority: authority, separatedByPort: true)
        }

        // 远端辅助程序的 `<传输>::<地址>`，传输名只有字母、数字与 “+” “-” “.”
        if let range = url.range(of: "::"), isTransportName(url[..<range.lowerBound]) {
            return nil
        }

        guard
            let colon = scpColon(in: url),
            !url[..<colon].contains("/")
        else {
            return nil
        }

        return host(inAuthority: url[..<colon], separatedByPort: false)
    }

    /// scp 写法里分开主机与路径的 “:”；主机段写在方括号里时是 “]” 之后的那个。
    private static func scpColon(in url: String) -> String.Index? {
        guard url.hasPrefix("[") else {
            return url.firstIndex(of: ":")
        }

        guard let close = url.range(of: "]:") else {
            return nil
        }

        return url.index(after: close.lowerBound)
    }

    /// 去掉用户名与端口后的主机；为空时为 nil。
    ///
    /// - Parameters:
    ///   - authority: 主机所在的一段，可带 `用户@`，也可整段写在方括号里。
    ///   - separatedByPort: URL 写法的端口直接跟在主机后面；scp 写法的端口只出现在方括号里。
    private static func host(inAuthority authority: Substring, separatedByPort: Bool) -> String? {
        var text = authority

        // 方括号里是 IPv6 地址，或 scp 写法的 `用户@主机:端口`
        if text.hasPrefix("["), let close = text.firstIndex(of: "]") {
            text = text[text.index(after: text.startIndex) ..< close]
            text = text.lastIndex(of: "@").map { text[text.index(after: $0)...] } ?? text

            let colons = text.count { $0 == ":" }
            let host = colons == 1 ? text.prefix { $0 != ":" } : text
            return host.isEmpty ? nil : String(host)
        }

        text = text.lastIndex(of: "@").map { text[text.index(after: $0)...] } ?? text

        if separatedByPort, text.hasPrefix("["), let close = text.firstIndex(of: "]") {
            text = text[text.index(after: text.startIndex) ..< close]
        } else if separatedByPort {
            text = text.prefix { $0 != ":" }
        }

        return text.isEmpty ? nil : String(text)
    }

    /// 是否是远端辅助程序的传输名。
    private static func isTransportName(_ text: Substring) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "+-.".contains($0)) }
    }
}
