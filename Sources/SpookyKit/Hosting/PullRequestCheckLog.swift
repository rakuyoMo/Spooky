import Foundation

// MARK: - PullRequestCheckLog

/// 一个作业的日志：去掉时间戳、终端控制码与分组标记后的各行。
public struct PullRequestCheckLog: Sendable, Hashable {
    /// 日志的各行。
    public let lines: [String]

    /// 从作业日志的原文取出各行。
    ///
    /// - GitHub：每行开头是时间戳；`##[group]` 一行留下分组的标题，`##[endgroup]` 一行不留。
    /// - GitLab：新版 Runner 每行开头是时间戳与输出流标记，过长的行被拆开、由标记接回；
    ///   `section_start` 与 `section_end` 不留，同一行里它后面的文字是分组的标题。
    /// - 回车之后的内容盖掉这一行前面的内容，只留最后写下的一段。
    ///
    /// - Parameters:
    ///   - text: 日志的原文。
    ///   - service: 日志所在的服务。
    public init(text: String, service: HostingService) {
        // 每行开头的时间戳，后面跟一个空格
        let timestamp = #/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z /#

        // GitLab 在时间戳后面写的输出流编号与种类，最后一位是 “+” 时这一行接在上一行后面
        let stream = #/^[0-9a-f]{2}[OE](?<flag>[ +])/#

        var joined: [Substring] = []

        // 先去掉时间戳，把 GitLab 拆开的行接回去：控制码可能正好被拆成两半；回车加换行在字符串里是一个字符，先换成换行
        for raw in text.replacing("\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let untimed = raw.trimmingPrefix("\u{FEFF}")
            var line = untimed.trimmingPrefix(timestamp)

            // 输出流标记只跟在时间戳后面
            guard
                service == .gitlab,
                line.startIndex != untimed.startIndex,
                let match = line.prefixMatch(of: stream)
            else {
                joined.append(line)
                continue
            }

            line = line[match.range.upperBound...]

            if match.output.flag == "+", let last = joined.indices.last {
                joined[last] += line
            } else {
                joined.append(line)
            }
        }

        // 原文以换行结尾，最后那个空段不是一行
        if joined.last?.isEmpty ?? false {
            joined.removeLast()
        }

        // 终端控制码：以 `ESC [` 开头的颜色、清行与光标移动，以及以 `ESC ]` 开头的窗口标题一类
        let control = #/\u{1B}(\[[0-9;?]*[ -\/]*[@-~]|\][^\u{07}\u{1B}]*(\u{07}|\u{1B}\\)?)/#

        lines = joined.compactMap { line in
            service == .github ? Self.githubLine(line, control: control) : Self.gitlabLine(line, control: control)
        }
    }

    /// 创建日志；测试使用。
    public init(lines: [String]) {
        self.lines = lines
    }

    /// GitHub 一行里看得见的文字：分组开头留下标题；分组结尾不留，为 nil。
    private static func githubLine(_ line: Substring, control: some RegexComponent) -> String? {
        guard line != "##[endgroup]" else {
            return nil
        }

        return String(line.trimmingPrefix("##[group]")).replacing(control, with: "")
    }

    /// GitLab 一行里看得见的文字：回车分开的各段里，分组标记不算内容，留下最后一段有内容的；只有分组标记时为 nil。
    private static func gitlabLine(_ line: Substring, control: some RegexComponent) -> String? {
        var hasMarker = false

        let segments = line.split(separator: "\r").map { $0.replacing(control, with: "") }.filter {
            guard $0.wholeMatch(of: #/section_(start|end):\d+:.*/#) == nil else {
                hasMarker = true
                return false
            }

            return !$0.isEmpty
        }

        guard let last = segments.last else {
            return hasMarker ? nil : ""
        }

        return String(last)
    }
}
