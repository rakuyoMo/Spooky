import Foundation
import SpookyKit
import Testing
import TestSupport

@testable import Spooky

// MARK: - SettingsPreferencesTests

/// 设置页写入的偏好：窗口恢复交还系统设置时必须删掉键，克隆目录的候选不重复，本机执行设置立即交给核心库并能读回，
/// 登录 shell 环境默认读取。
@MainActor
struct SettingsPreferencesTests {
    /// 三种窗口恢复方式写进 App 自己的偏好域；交给系统设置时删除键，读出时不受全局域影响。
    @Test("窗口恢复方式的读写")
    func windowRestoration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.restoration." + UUID().uuidString)
        let domain = directory.appending(path: "defaults").path
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { try? FileManager.default.removeItem(at: directory) }

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
        try FileManager.default.createDirectory(
            at: home.appending(path: "Development"),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: home) }

        let development = home.appending(path: "Development").path

        #expect(CloneDirectory.candidates(selected: home.path, home: home.path) == [home.path, development])
        #expect(
            CloneDirectory.candidates(selected: "/tmp/克隆 目录", home: home.path)
                == [home.path, development, "/tmp/克隆 目录"]
        )
    }

    /// 环境设置写进偏好并立即交给核心库；登录 shell 的变量只在开启时带上，重新创建时读回保存的值。
    /// 没有改过设置时读取登录 shell 的变量，本机 Git 才能找到 shell 配置里补进 PATH 的工具；存过关闭的不被默认值覆盖。
    @Test("本机执行设置的持久化，登录 shell 环境默认读取")
    func localExecutionPreferences() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.environment." + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defer { try? FileManager.default.removeItem(at: directory) }

        var applied: [LocalExecutionSettings] = []
        let preferences = LocalExecutionPreferences(
            defaults: defaults,
            readLoginShell: { ["EDITOR": "nano"] },
            apply: { applied.append($0) }
        )

        // 没有改过设置时默认读取登录 shell 环境
        #expect(preferences.usesLoginShell)

        preferences.saveCustomVariables([CustomEnvironmentVariable(name: "TOKEN", value: "值")])
        preferences.selectGitExecutable("/opt/homebrew/bin/git")
        preferences.setUsesLoginShell(true)

        // 登录 shell 在后台读取，读完后再交一次设置
        await until { preferences.loginShellState != .reading }
        #expect(preferences.loginShellState == .loaded)

        let last = try #require(applied.last)
        #expect(last.customVariables == ["TOKEN": "值"])
        #expect(last.gitExecutable == "/opt/homebrew/bin/git")
        #expect(last.loginShellVariables == ["EDITOR": "nano"])
        #expect(last.sshAuthSocket == SSHAgent.system.socket())

        let reloaded = LocalExecutionPreferences(defaults: defaults, readLoginShell: { [:] }, apply: { _ in })
        #expect(reloaded.customVariables.map(\.name) == ["TOKEN"])
        #expect(reloaded.gitExecutable == "/opt/homebrew/bin/git")
        #expect(reloaded.usesLoginShell)

        preferences.setUsesLoginShell(false)
        #expect(applied.last?.loginShellVariables.isEmpty ?? false)

        // 存过关闭的不被默认值覆盖
        let saved = LocalExecutionPreferences(defaults: defaults, readLoginShell: { [:] }, apply: { _ in })
        #expect(!saved.usesLoginShell)
    }
}
