import AppKit
import OSLog
import SpookyKit

// MARK: - DiagnosticReport

/// Help › Create Diagnostic Report… 导出的报告：版本与系统、本机 Git、相关设置、仓库与操作的概况，以及最近的日志，全文已脱敏。
///
/// 只写数量与状态，不写仓库路径、主机别名、凭据与环境变量的值；报告由用户自己保存与分享。
@MainActor
enum DiagnosticReport {
    /// 写进报告的偏好键：都是界面与执行方式的选择，不含路径以外的个人数据。
    private static let preferenceKeys = [
        AppAppearance.key, UpdateChannel.key, WindowRestoration.key, SpookyApplicationController.showsLaunchWindowKey,
        "terminalApplication", ExternalTool.diffToolKey, ExternalTool.mergeToolKey, LocalExecutionPreferences.sshAgentKey,
        LocalExecutionPreferences.gitExecutableKey, LocalExecutionPreferences.loginShellKey, GerritPush.key,
        CrashReporter.alwaysSendKey,
    ]

    /// 生成报告的全文。
    ///
    /// - Parameters:
    ///   - bookmarks: 仓库书签，只统计数量。
    ///   - activities: 最近的操作，只写标题与状态。
    static func make(bookmarks: RepositoryBookmarks, activities: [RepositoryActivity]) async -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = (info["CFBundleShortVersionString"] as? String ?? "?") + " (" +
            (info["CFBundleVersion"] as? String ?? "?") +
            ")"
        let git = await gitVersion()
        let locations = bookmarks.repositories.compactMap(\.location)

        let preferences = preferenceKeys.map { key in
            "- " + key + ": " + (UserDefaults.standard.object(forKey: key).map { String(describing: $0) } ?? "–")
        }

        let recent = activities.prefix(20).map { activity in
            "- " + activity.started.formatted(date: .numeric, time: .standard) + "  " + activity.title + "  "
                + AppLocalization.text(activity.state)
        }

        let report = """
            # Spooky Diagnostic Report

            - Spooky: \(version)
            - macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
            - Languages: \(Locale.preferredLanguages.prefix(3).joined(separator: ", "))
            - Git: \(git)

            ## Settings

            \(preferences.joined(separator: "\n"))

            ## Repositories

            - Local: \(locations.filter { $0.host == nil }.count)
            - Server: \(locations.filter { $0.host != nil }.count)

            ## Recent Activity

            \(recent.isEmpty ? "–" : recent.joined(separator: "\n"))

            ## Log

            \(await Task.detached { recentLog() }.value)
            """

        return DiagnosticRedactor.redact(report)
    }

    /// 本机选用的 Git 程序与它的版本；读不到时写明原因。
    private static func gitVersion() async -> String {
        let executable = LocalExecutionSettings.current.gitExecutable

        do {
            let output = try await GitRunner(location: .local(path: NSHomeDirectory())).run(["--version"])
            return executable + ", " + String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return executable + ", " + AppFailure(error: error, opening: false, location: nil).title
        }
    }

    /// 本次运行最近一小时的日志；读不到时写明。读取日志库较慢，在后台执行。
    private nonisolated static func recentLog() -> String {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else {
            return "–"
        }

        let since = store.position(date: Date().addingTimeInterval(-3600))
        let entries = (try? store.getEntries(at: since)) ?? AnySequence([])

        let lines = entries
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem == "com.rakuyo.spooky" }
            .suffix(500)
            .map { $0.date.formatted(date: .omitted, time: .standard) + " [" + $0.category + "] " + $0.composedMessage }

        return lines.isEmpty ? "–" : lines.joined(separator: "\n")
    }
}
