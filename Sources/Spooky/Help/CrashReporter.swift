import AppKit
import Foundation

// MARK: - CrashReport

/// 系统为 Spooky 记下的一份崩溃报告（`.ips`）：第一行是报告头，其余是崩溃的详情，两段都是 JSON。
struct CrashReport {
    /// 报告头：App 版本、构建号与系统版本。
    private struct Header: Decodable {
        /// App 的版本号。
        let app_version: String?

        /// App 的构建号。
        let build_version: String?

        /// 系统版本。
        let os_version: String?
    }

    /// 崩溃详情：异常、终止原因、触发崩溃的线程与载入的映像。
    private struct Body: Decodable {
        /// 异常类型与信号。
        struct Exception: Decodable {
            /// 异常类型，如 EXC_BAD_ACCESS。
            let type: String?

            /// 信号，如 SIGSEGV。
            let signal: String?
        }

        /// 终止原因。
        struct Termination: Decodable {
            /// 简短的说明，如 Trace/BPT trap: 5。
            let indicator: String?
        }

        /// 一个线程。
        struct Thread: Decodable {
            /// 是否是触发崩溃的线程。
            let triggered: Bool?

            /// 调用栈，栈顶在前。
            let frames: [Frame]?
        }

        /// 调用栈的一帧。
        struct Frame: Decodable {
            /// 所在映像在 `usedImages` 里的序号。
            let imageIndex: Int?

            /// 相对映像起点的偏移。
            let imageOffset: Int?

            /// 符号名；没有符号时为 nil。
            let symbol: String?

            /// 相对符号起点的偏移。
            let symbolLocation: Int?
        }

        /// 载入的映像。
        struct Image: Decodable {
            /// 映像名，如 Spooky、AppKit。
            let name: String?
        }

        /// 异常。
        let exception: Exception?

        /// 终止原因。
        let termination: Termination?

        /// 全部线程。
        let threads: [Thread]?

        /// 载入的映像。
        let usedImages: [Image]?
    }

    /// 报告摘要里最多列出的栈帧数。
    private static let frameLimit = 30

    /// 写进问题正文的摘要：版本、系统、异常与崩溃线程的调用栈，已脱敏。
    let summary: String

    /// 解析一份报告；不是 `.ips` 格式时为 nil。
    init?(data: Data) {
        let text = String(decoding: data, as: UTF8.self)

        guard
            let newline = text.firstIndex(of: "\n"),
            let header = try? JSONDecoder().decode(Header.self, from: Data(text[..<newline].utf8)),
            let body = try? JSONDecoder().decode(Body.self, from: Data(text[text.index(after: newline)...].utf8))
        else {
            return nil
        }

        summary = DiagnosticRedactor.redact(Self.summary(header: header, body: body))
    }

    /// 摘要的 Markdown：先是三行概况，再是崩溃线程的调用栈。
    private static func summary(header: Header, body: Body) -> String {
        let version = (header.app_version ?? "?") + " (" + (header.build_version ?? "?") + ")"
        let exception = [body.exception?.type, body.exception?.signal].compactMap(\.self).joined(separator: " ")
        let images = body.usedImages ?? []
        let frames = body.threads?.first { $0.triggered ?? false }?.frames ?? []

        let lines = frames.prefix(frameLimit).enumerated().map { index, frame in
            let image = frame.imageIndex.flatMap { images.indices.contains($0) ? images[$0].name : nil } ?? "???"
            let location = frame.symbol.map { $0 + " + " + String(frame.symbolLocation ?? 0) }
                ?? String(format: "0x%llx", frame.imageOffset ?? 0)

            return String(index) + "  " + image + "  " + location
        }

        return """
            **Spooky:** \(version)
            **macOS:** \(header.os_version ?? "?")
            **Exception:** \(exception.isEmpty ? "?" : exception) \(body.termination?.indicator ?? "")

            ```
            \(lines.joined(separator: "\n"))
            ```
            """
    }
}

// MARK: - CrashReporter

/// 启动时查看上次运行有没有崩溃：有新的崩溃报告时脱敏，再按设置直接或询问后打开 GitHub 上预填的新问题页。
///
/// 报告不会自动上传：最终由用户在浏览器里决定是否提交。处理过的报告记下时间，之后不再提示。
@MainActor
enum CrashReporter {
    /// “Always send crash reports” 的偏好键：打开时不再询问，直接打开新问题页。
    static let alwaysSendKey = "alwaysSendCrashReports"

    /// 已经处理过的最新一份报告的时间。
    static let handledKey = "lastHandledCrashReport"

    /// 系统存放崩溃报告的目录。
    static var reportsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/DiagnosticReports")
    }

    /// 目录里还没处理过的 Spooky 崩溃报告，最新的在前。
    ///
    /// - Parameters:
    ///   - directory: 崩溃报告所在的目录。
    ///   - handled: 已经处理过的最新一份报告的时间，不晚于它的报告不再列出。
    static func pendingReports(in directory: URL, after handled: Date) -> [(url: URL, date: Date)] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []

        return files
            .filter { $0.lastPathComponent.hasPrefix("Spooky-") && $0.pathExtension == "ips" }
            .compactMap { url in
                let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                return date.flatMap { $0 > handled ? (url, $0) : nil }
            }
            .sorted { $0.date > $1.date }
    }

    /// 启动后检查一次；第一次运行只记下当前时间，不提示安装前留下的报告。
    static func checkOnLaunch(defaults: UserDefaults = .standard) {
        guard let handled = defaults.object(forKey: handledKey) as? Date else {
            defaults.set(Date(), forKey: handledKey)
            return
        }

        let pending = pendingReports(in: reportsDirectory, after: handled)

        guard let newest = pending.first else {
            return
        }

        defaults.set(newest.date, forKey: handledKey)

        guard
            let data = try? Data(contentsOf: newest.url),
            let report = CrashReport(data: data),
            let url = HelpLinks.newIssue(title: AppLocalization.text("crash.issueTitle"), body: report.summary)
        else {
            return
        }

        if defaults.bool(forKey: alwaysSendKey) || ask(defaults: defaults) {
            NSWorkspace.shared.open(url)
        }
    }

    /// 询问是否在 GitHub 上报告；勾选 “Always send crash reports” 后之后不再询问。
    private static func ask(defaults: UserDefaults) -> Bool {
        let alert = NSAlert()
        alert.messageText = AppLocalization.text("crash.title")
        alert.informativeText = AppLocalization.text("crash.message")
        alert.addButton(withTitle: AppLocalization.text("crash.report"))
        alert.addButton(withTitle: AppLocalization.text("crash.dontReport"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = AppLocalization.text("settings.crashReports.always")

        let reports = alert.runModal() == .alertFirstButtonReturn

        if alert.suppressionButton?.state == .on {
            defaults.set(true, forKey: alwaysSendKey)
        }

        return reports
    }
}
