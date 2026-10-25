import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - SettingsPreferencesTests

/// 设置页写入的偏好与校验规则：窗口恢复交还系统设置时必须删掉键，Issue 追踪的模板与前缀不合法时不能保存。
@MainActor
struct SettingsPreferencesTests {
    /// 三种窗口恢复方式写进 App 自己的偏好域；交给系统设置时删除键，读出时不受全局域影响。
    @Test("窗口恢复方式的读写")
    func windowRestoration() throws {
        let domain = "com.rakuyo.spooky.tests.restoration." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }

        #expect(WindowRestoration.current(in: defaults, domain: domain) == .system)

        WindowRestoration.always.save(in: defaults)
        #expect(defaults.persistentDomain(forName: domain)?[WindowRestoration.key] as? Bool ?? false)
        #expect(WindowRestoration.current(in: defaults, domain: domain) == .always)

        WindowRestoration.never.save(in: defaults)
        #expect(WindowRestoration.current(in: defaults, domain: domain) == .never)

        WindowRestoration.system.save(in: defaults)
        #expect(defaults.persistentDomain(forName: domain)?[WindowRestoration.key] == nil)
        #expect(WindowRestoration.current(in: defaults, domain: domain) == .system)
    }

    /// 克隆目录的候选：主目录在前，已选的目录只列一次。
    @Test("克隆目录的候选")
    func cloneDirectoryCandidates() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "spooky-home-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: home.appending(path: "Development"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let development = home.appending(path: "Development").path

        #expect(CloneDirectory.candidates(selected: home.path, home: home.path) == [home.path, development])
        #expect(
            CloneDirectory.candidates(selected: "/tmp/克隆 目录", home: home.path)
                == [home.path, development, "/tmp/克隆 目录"]
        )
    }

    /// 都不填表示不使用 Issue 追踪；默认的 # 可以单独使用，自定义前缀必须配上模板。
    @Test("Issue 追踪的前缀规则")
    func issuePrefix() {
        #expect(IssueTracking.problem(template: "", prefix: "") == nil)
        #expect(IssueTracking.problem(template: "", prefix: "#") == nil)
        #expect(IssueTracking.problem(template: "", prefix: "JIRA-") != nil)
        let template = "https://example.invalid/{ISSUE_NUMBER}"

        #expect(IssueTracking.problem(template: template, prefix: "JIRA-") == nil)
        #expect(IssueTracking.problem(template: template, prefix: "A B") != nil)
        #expect(IssueTracking.problem(template: template, prefix: String(repeating: "x", count: 21)) != nil)
    }

    /// 模板必须是带主机名的网页地址、带编号占位符，只用支持的占位符，不含空白。
    @Test("Issue 追踪的地址模板规则")
    func issueTemplate() {
        #expect(IssueTracking.templateProblem("https://example.invalid/{OWNER}/{REPOSITORY}/issues/{ISSUE_NUMBER}") == nil)
        #expect(IssueTracking.templateProblem("http://tracker.invalid/browse/{ISSUE_NUMBER}") == nil)
        #expect(IssueTracking.templateProblem("https://example.invalid/issues/") != nil)
        #expect(IssueTracking.templateProblem("https://example.invalid/{TICKET}/{ISSUE_NUMBER}") != nil)
        #expect(IssueTracking.templateProblem("https://example.invalid/my issues/{ISSUE_NUMBER}") != nil)
        #expect(IssueTracking.templateProblem("ftp://example.invalid/{ISSUE_NUMBER}") != nil)
        #expect(IssueTracking.templateProblem("{ISSUE_NUMBER}") != nil)
    }

    /// 环境设置写进偏好并立即交给核心库；登录 shell 的变量只在开启时带上，重新创建时读回保存的值。
    @Test("本机执行设置的持久化")
    func localExecutionPreferences() async throws {
        let domain = "com.rakuyo.spooky.tests.environment." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }

        var applied: [LocalExecutionSettings] = []
        let preferences = LocalExecutionPreferences(
            defaults: defaults,
            readLoginShell: { ["EDITOR": "nano"] },
            apply: { applied.append($0) }
        )

        preferences.saveCustomVariables([CustomEnvironmentVariable(name: "TOKEN", value: "值")])
        preferences.selectSSHAgent(.onePassword)
        preferences.selectGitExecutable("/opt/homebrew/bin/git")
        preferences.setUsesLoginShell(true)

        // 登录 shell 在后台读取，读完后再交一次设置。
        for _ in 0 ..< 100 where preferences.loginShellState != .loaded {
            try await Task.sleep(for: .milliseconds(20))
        }

        let last = try #require(applied.last)
        #expect(last.customVariables == ["TOKEN": "值"])
        #expect(last.gitExecutable == "/opt/homebrew/bin/git")
        #expect(last.loginShellVariables == ["EDITOR": "nano"])
        #expect(last.sshAuthSocket?.hasSuffix("2BUA8C4S2C.com.1password/t/agent.sock") ?? false)

        let reloaded = LocalExecutionPreferences(defaults: defaults, readLoginShell: { [:] }, apply: { _ in })
        #expect(reloaded.customVariables.map(\.name) == ["TOKEN"])
        #expect(reloaded.sshAgent == .onePassword)
        #expect(reloaded.gitExecutable == "/opt/homebrew/bin/git")
        #expect(reloaded.usesLoginShell)

        preferences.setUsesLoginShell(false)
        #expect(applied.last?.loginShellVariables.isEmpty ?? false)
    }

    /// Gerrit 为评审分支收取变更的引用写在 refs/for/ 之下。
    @Test("Gerrit 的评审引用")
    func gerritReviewReference() {
        #expect(GerritPush.reviewReference("main") == "refs/for/main")
        #expect(GerritPush.reviewReference("feature/登录") == "refs/for/feature/登录")
    }
}
