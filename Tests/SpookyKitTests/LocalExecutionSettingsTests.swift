import Foundation
import Subprocess
import Testing

@testable import SpookyKit

// MARK: - LocalExecutionSettingsTests

/// 本机执行 Git 的程序与环境：登录 shell 的变量、自定义变量与 SSH agent 按固定顺序覆盖，所选程序缺失时给出可判断的错误。
struct LocalExecutionSettingsTests {
    /// 启动文件的问候语在标记之前被跳过，值里的换行与等号原样保留，shell 自身状态与不合法的名称不交给 Git；
    /// 没有标记、或标记不在行首时视为输出无法识别，不把启动文件打印的文字当成变量。
    @Test("解析登录 shell 输出的变量")
    func loginShellOutput() throws {
        let marker = "spooky-environment-test"
        let records = [
            "PATH=/opt/homebrew/bin:/usr/bin",
            "MULTI=第一行\n第二行=仍是值",
            "PWD=/Users/someone",
            "SHLVL=2",
            "=没有名字",
            "EMPTY=",
        ]

        let output = Data(("欢迎回来\n" + marker + "\0" + records.joined(separator: "\0") + "\0").utf8)
        let variables = try #require(LoginShellEnvironment.parse(output, marker: marker))

        #expect(variables["PATH"] == "/opt/homebrew/bin:/usr/bin")
        #expect(variables["MULTI"] == "第一行\n第二行=仍是值")
        #expect(variables["EMPTY"]?.isEmpty ?? false)
        #expect(variables["PWD"] == nil)
        #expect(variables["SHLVL"] == nil)
        #expect(variables.count == 3)

        // 没有标记，或标记只出现在启动文件打印的文字中间
        #expect(LoginShellEnvironment.parse(Data("PATH=/usr/bin\0".utf8), marker: marker) == nil)
        #expect(LoginShellEnvironment.parse(Data(("echo " + marker + "\0PATH=/x\0").utf8), marker: marker) == nil)
    }

    /// 自定义变量覆盖登录 shell 的同名变量，所选 agent 的 socket 最后写入；
    /// 系统 Git 的目录已在 PATH 里时不改写 PATH，别处的 Git 把它的目录补在最前；
    /// SSH Agent 只有系统 agent 一项，它取继承的 SSH_AUTH_SOCK，空值视为没有。
    @Test("变量的覆盖顺序、PATH 与 SSH agent")
    func overrides() {
        let settings = LocalExecutionSettings(
            loginShellVariables: ["EDITOR": "vim", "TOKEN": "来自登录 shell", "SSH_AUTH_SOCK": "/tmp/shell.sock"],
            customVariables: ["TOKEN": "自定义", "BAD=NAME": "跳过"],
            sshAuthSocket: "/tmp/agent.sock"
        )

        let overrides = named(settings.gitOverrides(inheritedPath: "/usr/bin:/bin"))
        #expect(overrides["EDITOR"] == "vim")
        #expect(overrides["TOKEN"] == "自定义")
        #expect(overrides["SSH_AUTH_SOCK"] == "/tmp/agent.sock")
        #expect(overrides["BAD=NAME"] == nil)

        // PATH 补上所选 Git 的目录
        let system = LocalExecutionSettings()
        #expect(named(system.gitOverrides(inheritedPath: "/usr/bin:/bin"))["PATH"] == nil)

        let homebrew = LocalExecutionSettings(gitExecutable: "/opt/homebrew/bin/git")
        let path = named(homebrew.gitOverrides(inheritedPath: "/usr/bin:/bin"))["PATH"]
        #expect(path == "/opt/homebrew/bin:/usr/bin:/bin")

        let shell = LocalExecutionSettings(
            gitExecutable: "/opt/homebrew/bin/git",
            loginShellVariables: ["PATH": "/opt/homebrew/bin:/usr/bin"]
        )
        #expect(named(shell.gitOverrides(inheritedPath: "/usr/bin"))["PATH"] == "/opt/homebrew/bin:/usr/bin")

        // 系统 agent 的 socket
        #expect(SSHAgent.allCases == [.system])
        #expect(SSHAgent.system.socket(environment: ["SSH_AUTH_SOCK": "/tmp/launchd.sock"]) == "/tmp/launchd.sock")
        #expect(SSHAgent.system.socket(environment: ["SSH_AUTH_SOCK": ""]) == nil)
        #expect(SSHAgent.system.socket(environment: [:]) == nil)
    }

    /// 所选的 Git 程序不存在时打开仓库报出它的路径，探测不到版本；系统 Git 的版本满足最低要求；
    /// 自定义变量真正交给本机 git，在隔离的配置里读回它设置的配置参数。
    @Test("Git 程序的缺失、版本探测与自定义变量")
    func gitProgram() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        let missing = repository.directory.appending(path: "没有这个 git").path
        let unavailable = GitRunner(
            location: .local(path: repository.directory.path),
            settings: LocalExecutionSettings(gitExecutable: missing)
        )

        await #expect {
            _ = try await unavailable.openLocalRepository()
        } throws: { error in
            guard case .gitUnavailable(let path) = error as? RepositoryOpenError else { return false }

            return path == missing
        }

        // 版本探测
        let probed = await GitProgram.probe(missing)
        #expect(probed.version == nil)
        #expect(!probed.isSupported)

        let system = await GitProgram.probe(LocalExecutionSettings.defaultGitExecutable)
        #expect(system.isSystem)
        #expect(system.version != nil)

        // 自定义变量经 GIT_CONFIG_COUNT 设置一项配置
        try await repository.initialize()
        let runner = GitRunner(
            location: .local(path: repository.directory.path),
            settings: LocalExecutionSettings(customVariables: [
                "GIT_CONFIG_COUNT": "1",
                "GIT_CONFIG_KEY_0": "spooky.marker",
                "GIT_CONFIG_VALUE_0": "来自自定义变量",
            ]),
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )

        let value = try await runner.run(["config", "--get", "spooky.marker"])
        #expect(String(decoding: value, as: UTF8.self).trimmingCharacters(in: .newlines) == "来自自定义变量")
    }

    /// 子进程环境的覆盖项按变量名取值。
    private func named(_ overrides: [Environment.Key: String?]) -> [String: String?] {
        Dictionary(uniqueKeysWithValues: overrides.map { ($0.key.rawValue, $0.value) })
    }
}
