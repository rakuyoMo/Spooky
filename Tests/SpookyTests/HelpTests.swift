import Foundation
import Testing

@testable import Spooky

// MARK: - HelpTests

/// Help 与崩溃报告：离开这台 Mac 的文字都经脱敏；崩溃报告只取新的 Spooky 报告并写成摘要；更新说明按行渲染。
@MainActor
struct HelpTests {
    /// 主目录、用户名、邮箱、地址里的账号口令、令牌与 IP 地址都换成占位文字，版本号不受影响。
    @Test("诊断文字的脱敏")
    func redaction() {
        let text = """
            /Users/alice/Projects/app 打开失败；/Users/bob/x
            git@github.com:me/app.git https://alice:s3cret@example.invalid/a.git
            token ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123 from 192.168.1.20, Git 2.41.0, alice wrote it
            """

        let redacted = DiagnosticRedactor.redact(text, home: "/Users/alice", userName: "alice")

        #expect(redacted.contains("~/Projects/app"))
        #expect(redacted.contains("/Users/<user>/x"))
        #expect(redacted.contains("<email>:me/app.git"))
        #expect(redacted.contains("https://<credentials>@example.invalid"))
        #expect(redacted.contains("token <token>"))
        #expect(redacted.contains("<ip>"))
        #expect(redacted.contains("Git 2.41.0"))
        #expect(redacted.contains("<user> wrote it"))
        #expect(!redacted.contains("alice"))
        #expect(!redacted.contains("s3cret"))
    }

    /// 摘要写出版本、系统、异常与崩溃线程的栈帧，没有符号的帧写偏移；不是 ips 格式时为 nil。
    @Test("崩溃报告的摘要")
    func crashSummary() throws {
        let header = #"{"app_name":"Spooky","app_version":"0.8.0","build_version":"12","os_version":"macOS 26.0 (25A100)"}"#
        let body = """
            {"exception":{"type":"EXC_BAD_ACCESS","signal":"SIGSEGV"},"termination":{"indicator":"Segmentation fault: 11"},
            "threads":[{"frames":[{"imageIndex":1,"imageOffset":16}]},
            {"triggered":true,"frames":[{"imageIndex":0,"imageOffset":4096,"symbol":"RepositorySession.refresh()","symbolLocation":42},
            {"imageIndex":1,"imageOffset":255}]}],
            "usedImages":[{"name":"Spooky"},{"name":"AppKit"}]}
            """

        let report = try #require(CrashReport(data: Data((header + "\n" + body).utf8)))

        #expect(report.summary.contains("**Spooky:** 0.8.0 (12)"))
        #expect(report.summary.contains("**macOS:** macOS 26.0 (25A100)"))
        #expect(report.summary.contains("EXC_BAD_ACCESS SIGSEGV Segmentation fault: 11"))
        #expect(report.summary.contains("0  Spooky  RepositorySession.refresh() + 42"))
        #expect(report.summary.contains("1  AppKit  0xff"))
        #expect(CrashReport(data: Data("not a report".utf8)) == nil)
    }

    /// 只列出处理时间之后的 Spooky 报告，最新的在前；别的 App 的报告与旧报告不算。
    @Test("待处理的崩溃报告")
    func pendingReports() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-crash-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let handled = Date(timeIntervalSince1970: 1_000_000)
        let files: [(String, TimeInterval)] = [
            ("Spooky-old.ips", 900_000),
            ("Spooky-new.ips", 1_100_000),
            ("Spooky-newest.ips", 1_200_000),
            ("Other-new.ips", 1_300_000),
            ("Spooky-new.txt", 1_300_000),
        ]

        for (name, time) in files {
            let url = directory.appending(path: name)
            try Data("x".utf8).write(to: url)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: time)], ofItemAtPath: url.path)
        }

        let pending = CrashReporter.pendingReports(in: directory, after: handled)
        #expect(pending.map(\.url.lastPathComponent) == ["Spooky-newest.ips", "Spooky-new.ips"])
    }

    /// 新问题页预填标题与正文，正文过长时截短。
    @Test("预填的新问题页")
    func newIssue() throws {
        let url = try #require(HelpLinks.newIssue(title: "Spooky 崩溃", body: String(repeating: "a", count: 10_000)))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        #expect(url.host == "github.com")
        #expect(items.first { $0.name == "title" }?.value == "Spooky 崩溃")
        #expect((items.first { $0.name == "body" }?.value?.count ?? 0) == 6000)
    }

    /// 更新说明按行拆成节标题、列表项与段落，空行不单独成块。
    @Test("更新说明的分块")
    func releaseNoteBlocks() {
        let blocks = ReleaseNotesView.blocks(of: "### New\n\n- **Clone** repositories\n* Scan folders\nThanks!\n")

        #expect(blocks == [.heading("New"), .item("**Clone** repositories"), .item("Scan folders"), .paragraph("Thanks!")])
    }
}
