import Foundation
import Subprocess

// MARK: - Channel

extension RemoteConnection {
    /// 连续打不开常驻通道的次数上限，到了就不再尝试，等到重新连接。
    static let channelAttempts = 3

    /// 本机 SSH 进程的环境：继承本机环境，套上 SSH 的覆盖项并固定 locale；逐条执行与常驻通道共用。
    static var sshEnvironment: Environment {
        .inherit
            .updating(LocalExecutionSettings.current.sshOverrides)
            .updating(["LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"])
    }

    /// 能经常驻通道执行时经它执行；通道不在时在后台重新打开。
    ///
    /// 只有以包装器开头、标准输入在内存里、不按块转交标准输出且编码后不超出上限的命令经通道执行。
    ///
    /// - Returns: 命令的结果；通道没有执行这条命令时返回 nil，由调用方另开会话执行。
    func executeThroughChannel(
        _ command: [String],
        input: Data?,
        inputFile: URL?,
        arguments: [String],
        onOutput: (@Sendable (GitOutputEvent) -> Void)?
    ) async throws -> GitCommandResult? {
        guard
            let wrapper,
            command.first == wrapper,
            inputFile == nil,
            !CommandExecutor.streamsStandardOutput
        else { return nil }

        guard let channel = resident, channel.isReady else {
            reopenChannel()
            return nil
        }

        do {
            let result = try await channel.execute(
                Array(command.dropFirst()),
                input: input ?? Data(),
                resultArguments: arguments,
                onOutput: onOutput
            )

            channelCommands += 1
            return result
        } catch is RemoteCommandChannel.NotExecuted {
            return nil
        }
    }

    /// 把本机中继转发进体检新建的会话并启用常驻通道：体检没能复用已安装的包装器时先安装它。
    ///
    /// 新建会话时 B 已经分出会话看守，看守等到转发的 socket 出现才开始心跳。
    /// 体检会话转成的通道直接等它就绪；安装了包装器时另开 serve 会话，与转发同时进行。
    /// 通道没有就绪时关掉它并记一次失败，命令逐条另开会话执行，之后在后台重新打开。
    func startSession() async throws {
        if wrapper == nil { try await deployWrapper() }

        guard let relay, let wrapper, let remoteDirectory else { throw RemoteConnectionError(.deployment) }

        if pendingChannel == nil, configuration.usesResidentChannel {
            pendingChannel = makeChannel([wrapper, "serve", remoteDirectory])
        }

        // 转发失败时连接建立失败，关闭连接的流程关掉还没启用的通道
        let forward = try await ssh([
            "-O", "forward",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "StreamLocalBindUnlink=yes",
            "-R", remoteDirectory + "/relay.sock:" + relay.path,
        ], arguments: ["relay-forward"])

        guard forward.exitCode == 0 else { throw RemoteConnectionError(.deployment, result: forward) }
        guard let channel = pendingChannel else { return }

        let ready = await channel.waitUntilReady()
        pendingChannel = nil

        // 建立连接被取消时不启用通道，也不记作打不开
        guard !Task.isCancelled else {
            channel.close()
            throw CancellationError()
        }

        guard ready else {
            channel.close()
            channelFailures = 1
            logChannelFailure()
            return
        }

        adoptChannel(channel)
    }

    /// 关掉常驻通道与还没启用的通道，并停下正在进行的重新打开。
    func closeChannel() {
        reopening?.cancel()
        reopening = nil

        let channels = [resident, pendingChannel]
        resident = nil
        pendingChannel = nil

        for channel in channels {
            channel?.close()
        }
    }

    /// 在主连接上开一个会话运行 `command`，作为常驻通道；`command` 套上与逐条执行相同的环境前缀。
    ///
    /// - Parameters:
    ///   - command: B 上的命令：包装器的 serve 模式，或带前导的连接体检。
    ///   - preamble: 帧之前的前导，``RemoteCommandChannel/Preamble``。
    func makeChannel(_ command: [String], preamble: RemoteCommandChannel.Preamble? = nil) -> RemoteCommandChannel? {
        guard let localDirectory else { return nil }

        let control = localDirectory.appending(path: "master.sock").path
        let shell = (configuration.environmentPrefix + command)
            .map(GitRunner.shellQuoted)
            .joined(separator: " ")

        return RemoteCommandChannel(
            executable: "/usr/bin/ssh",
            arguments: configuration.options + [
                "-S", control,
                "-o", "ControlMaster=no",
                "-o", "ProxyCommand=/usr/bin/false",
                "--", host, shell,
            ],
            environment: Self.sshEnvironment,
            preamble: preamble,
            onDisconnect: { [weak self] channel in
                Task { await self?.channelDidClose(channel) }
            }
        )
    }
}

// MARK: - Private

extension RemoteConnection {
    /// 在后台重新打开常驻通道：只在连接可用、通道不在且没有连续失败到上限时进行。
    ///
    /// 新通道就绪之前占着本连接的一个会话名额，同时打开的会话数不超过 B 的上限。
    private func reopenChannel() {
        guard
            configuration.usesResidentChannel,
            canonical == nil,
            resident == nil,
            reopening == nil,
            channelFailures < Self.channelAttempts,
            state == .connected,
            let wrapper,
            let remoteDirectory
        else { return }

        reopening = Task {
            let opened = try? await sessions.withPermit {
                let channel = await self.makeChannel([wrapper, "serve", remoteDirectory])
                return (channel: channel, ready: await channel?.waitUntilReady() ?? false)
            }

            finishReopening(opened?.channel, ready: opened?.ready ?? false)
        }
    }

    /// 收下重新打开的结果；等待期间连接已关闭或重新建立时不用这条通道。
    private func finishReopening(_ channel: RemoteCommandChannel?, ready: Bool) {
        // 关闭连接时会取消并清掉重新打开的任务，此后的结果与当前连接无关
        guard !Task.isCancelled else {
            channel?.close()
            return
        }

        reopening = nil

        guard let channel, ready, state == .connected else {
            channel?.close()
            channelFailures += 1
            logChannelFailure()
            return
        }

        adoptChannel(channel)
    }

    /// 启用就绪的通道并清零连续失败的次数。
    private func adoptChannel(_ channel: RemoteCommandChannel) {
        resident = channel
        channelFailures = 0

        let host = host
        Self.logger.info("常驻通道已就绪：\(host, privacy: .private)")
    }

    /// 常驻通道自行断开：下一条命令另开会话执行并在后台重新打开通道；先确认一次主连接，主连接也断了时立即转为不可用。
    private func channelDidClose(_ channel: RemoteCommandChannel) async {
        guard resident === channel else { return }

        resident = nil

        let host = host
        Self.logger.info("常驻通道已断开：\(host, privacy: .private)")

        guard state == .connected else { return }

        try? await check()
    }

    /// 记下一次没能打开常驻通道。
    private func logChannelFailure() {
        let host = host
        Self.logger.error("常驻通道没能打开：\(host, privacy: .private)")
    }
}
