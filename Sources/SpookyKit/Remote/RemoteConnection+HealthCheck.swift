import Foundation

extension RemoteConnection {
    /// 依次检查 Git、路径权限、工作区与状态格式，返回 Git 确认的工作区根；
    /// 全部检查与复用已安装的包装器新建会话在一次往返里执行。
    func verifyRepository() async throws -> RemoteRepository {
        let checks = try await runHealthCheck(RemoteHealthCheck.Step.allCases)

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

    /// 主机连接的体检：读出 B 的主目录与环境，确认非交互环境能找到满足最低版本的 Git；
    /// 全部检查与复用已安装的包装器新建会话在一次往返里执行。
    func verifyHost() async throws {
        let checks = try await runHealthCheck(RemoteHealthCheck.hostSteps)
        environment = try readEnvironment(checks)

        // 主目录是浏览与默认目标路径的起点，读不到环境说明 B 缺少包装器同样依赖的 Perl
        guard environment != nil else {
            throw RemoteConnectionError(.deployment, diagnostic: "environment probe failed")
        }

        try verifyGitAvailable(checks)
        try verifyGitVersion(checks)
    }

    /// 在一次往返里执行体检脚本的 `steps`，按本次随机的分隔标记切开各步骤的输出。
    ///
    /// 会话步骤新建了会话时立即记下，之后任何一步失败，关闭连接的流程都会关掉这个会话。
    /// 使用常驻通道时，体检的会话在会话步骤成功之后转成常驻通道，记作还没启用的通道，由 ``startSession()`` 启用。
    private func runHealthCheck(_ steps: [RemoteHealthCheck.Step]) async throws -> RemoteHealthCheck {
        guard let bundled = Self.bundledWrapper else { throw RemoteConnectionError(.deployment) }

        let marker = UUID().uuidString
        let entersChannel = configuration.usesResidentChannel

        // 分隔标记与新建会话的报文经标准输入交给脚本；包装器的文件名与字节数、看守的容忍期与保留期是位置参数
        let command = [
            "/bin/sh", "-c", RemoteHealthCheck.script(steps, entersChannel: entersChannel), "spooky-check",
            requestedPath, bundled.filename, String(bundled.source.count),
            String(configuration.heartbeatTolerance),
            String(configuration.operationRetention),
        ]
        let input = try Data((marker + "\n").utf8) + sessionRequest()

        let result = try await entersChannel
            ? runChannelHealthCheck(command, input: input, marker: marker)
            : commandChannel(command, input: input, arguments: ["health-check"])

        let checks = RemoteHealthCheck(result, marker: marker, steps: steps)
        let session = checks.completed(.session, argument: RemoteConnectionError.Kind.deployment.rawValue)

        guard let session, session.exitCode == 0 else {
            // 会话步骤没有成功时脚本已经结束，体检的会话没有转成通道
            pendingChannel?.close()
            pendingChannel = nil
            return checks
        }

        try recordSession(session)
        return checks
    }

    /// 体检的会话直接开成常驻通道：先记下还没启用的通道，再等体检脚本写完前导。
    private func runChannelHealthCheck(_ command: [String], input: Data, marker: String) async throws -> GitCommandResult {
        let preamble = RemoteCommandChannel.Preamble(
            input: input,
            marker: RemoteHealthCheck.channelMarker(marker),
            arguments: ["health-check"]
        )

        guard let channel = makeChannel(command, preamble: preamble) else { throw RemoteConnectionError(.unavailable) }

        pendingChannel = channel
        return try await channel.preambleResult()
    }

    /// 确认非交互环境能找到 Git 并记下它的路径；找不到时把这个环境的 PATH 写进诊断，修复方向一目了然。
    private func verifyGitAvailable(_ checks: RemoteHealthCheck) throws {
        do {
            let found = try checks.require(.gitPath, kind: .gitUnavailable)
            gitExecutable = RemoteHealthCheck.gitExecutable(in: found.standardOutput)
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
