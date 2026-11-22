import Foundation

extension RemoteConnection {
    /// 依次检查 Git、路径权限、工作区与状态格式，返回 Git 确认的工作区根；全部检查在一次往返里执行。
    func verifyRepository() async throws -> RemoteRepository {
        let checks = try await runHealthCheck(through: .root)

        // 先记下 B 的非交互环境，后面任何一步失败时界面都能据此给出修复方向
        environment = try readEnvironment(checks)

        // B 的非交互环境必须能找到 Git，且版本满足最低要求。
        try verifyGitAvailable(checks)
        try verifyGitVersion(checks)

        // 存在、读取和搜索权限分别检查，路径只作为位置参数进入固定脚本。
        _ = try checks.require(.directory, kind: .pathUnavailable)
        _ = try checks.require(.permission, kind: .pathPermission)
        _ = try checks.requireAccess(.listing, kind: .pathPermission)

        let worktree = try checks.requireAccess(.workTree, kind: .notWorkingTree)
        guard worktree.standardOutput == Data("true\n".utf8) else {
            throw RemoteConnectionError(.notWorkingTree, result: worktree)
        }

        let status = try checks.requireAccess(.status, kind: .statusFormat)

        do { _ = try WorkingCopyStatus(porcelainV2: status.standardOutput) }
        catch { throw RemoteConnectionError(.statusFormat, result: status) }

        // 仓库身份取 Git 返回的工作区根，从子目录打开时据此共享同一会话。
        let root = try checks.require(.root, kind: .notWorkingTree)
        guard
            let rootPath = String(data: root.standardOutput, encoding: .utf8),
            rootPath.hasPrefix("/"), rootPath.hasSuffix("\n")
        else { throw RemoteConnectionError(.notWorkingTree, result: root) }

        return RemoteRepository(host: host, path: String(rootPath.dropLast()))
    }

    /// 主机连接的体检：读出 B 的主目录与环境，确认非交互环境能找到满足最低版本的 Git；全部检查在一次往返里执行。
    func verifyHost() async throws {
        let checks = try await runHealthCheck(through: .gitVersion)
        environment = try readEnvironment(checks)

        // 主目录是浏览与默认目标路径的起点，读不到环境说明 B 缺少包装器同样依赖的 Perl
        guard environment != nil else {
            throw RemoteConnectionError(.deployment, diagnostic: "environment probe failed")
        }

        try verifyGitAvailable(checks)
        try verifyGitVersion(checks)
    }

    /// 在一次往返里执行体检脚本到 `last` 为止，按本次随机的分隔标记切开各步骤的输出。
    private func runHealthCheck(through last: RemoteHealthCheck.Step) async throws -> RemoteHealthCheck {
        let marker = UUID().uuidString

        let result = try await commandChannel(
            ["/bin/sh", "-c", RemoteHealthCheck.script(through: last), "spooky-check", requestedPath],
            input: Data((marker + "\n").utf8),
            arguments: ["health-check"]
        )

        return RemoteHealthCheck(result, marker: marker)
    }

    /// 确认非交互环境能找到 Git；找不到时把这个环境的 PATH 写进诊断，修复方向一目了然。
    private func verifyGitAvailable(_ checks: RemoteHealthCheck) throws {
        do {
            _ = try checks.require(.gitPath, kind: .gitUnavailable)
        } catch let error as RemoteConnectionError where error.kind == .gitUnavailable {
            let path = environment.map { "PATH=" + $0.searchPath.joined(separator: ":") }
            throw RemoteConnectionError(.gitUnavailable, result: error.result, diagnostic: path)
        }
    }

    /// 读取 `git --version` 并记进环境；低于最低版本时抛出版本错误。
    private func verifyGitVersion(_ checks: RemoteHealthCheck) throws {
        let version = try checks.require(.gitVersion, kind: .gitUnavailable)
        environment?.gitVersion = String(decoding: version.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let parsed = GitVersion(output: version.standardOutput), parsed >= .minimum else {
            throw RemoteConnectionError(.gitVersion, result: version)
        }
    }

    /// 读取 B 端非交互 shell 的环境；脚本失败时返回 nil，输出含环境变量的值，不放进错误对象。
    private func readEnvironment(_ checks: RemoteHealthCheck) throws -> RemoteHostEnvironment? {
        let result = try checks.result(.environment, argument: "environment")

        if result.exitCode == 255 { throw RemoteConnectionError.ssh(result) }
        guard result.exitCode == 0 else { return nil }

        // Spooky 自己在远端命令里设置的变量不算 B 的环境问题
        let assigned = Set(configuration.remoteEnvironment.keys).union(["GIT_TERMINAL_PROMPT"])
        return RemoteHostEnvironment(output: result.standardOutput, excluding: assigned)
    }
}
