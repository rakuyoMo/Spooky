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

    /// 打开常驻通道，并把启动会话看守作为它的第一个请求；通道没有就绪时改为另开会话启动看守。
    ///
    /// 看守在就绪之前就写进通道，等待就绪与启动看守共用一次往返。
    func startWatcher(wrapper: String, remoteDirectory: String) async throws {
        let watch = [
            wrapper, "watch", remoteDirectory,
            String(configuration.heartbeatTolerance),
            String(configuration.operationRetention),
        ]

        guard
            configuration.usesResidentChannel,
            let channel = makeChannel(wrapper: wrapper, remoteDirectory: remoteDirectory)
        else {
            _ = try await probe(watch, kind: .deployment)
            return
        }

        // B 在就绪帧之后才执行请求，看守执行完就说明通道已就绪
        do {
            let result = try await channel.execute(
                Array(watch.dropFirst()),
                input: Data(),
                resultArguments: [RemoteConnectionError.Kind.deployment.rawValue]
            )

            if result.exitCode == 255 { throw RemoteConnectionError.ssh(result) }
            guard result.exitCode == 0 else { throw RemoteConnectionError(.deployment, result: result) }
        } catch is RemoteCommandChannel.NotExecuted {
            // 通道没有就绪时看守没有执行，照常另开会话启动
            channel.close()
            channelFailures = 1
            logChannelFailure()

            _ = try await probe(watch, kind: .deployment)
            return
        } catch {
            channel.close()
            throw error
        }

        adoptChannel(channel)
    }

    /// 关掉常驻通道，并停下正在进行的重新打开。
    func closeChannel() {
        reopening?.cancel()
        reopening = nil

        let channel = resident
        resident = nil
        channel?.close()
    }
}

// MARK: - Private

extension RemoteConnection {
    /// 在后台重新打开常驻通道：只在连接可用、通道不在且没有连续失败到上限时进行。
    ///
    /// 新通道就绪之前占着主机的一个执行槽，同时打开的会话数不超过 B 的上限。
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

        let location = repository?.location ?? .remote(host: host, path: requestedPath)

        reopening = Task {
            let opened = try? await RepositoryOperationQueue.shared.perform(at: location, writing: false) {
                let channel = await self.makeChannel(wrapper: wrapper, remoteDirectory: remoteDirectory)
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

    /// 在主连接上开一个运行包装器 serve 模式的会话。
    private func makeChannel(wrapper: String, remoteDirectory: String) -> RemoteCommandChannel? {
        guard let localDirectory else { return nil }

        let control = localDirectory.appending(path: "master.sock").path
        let command = (configuration.environmentPrefix + [wrapper, "serve", remoteDirectory])
            .map(GitRunner.shellQuoted)
            .joined(separator: " ")

        return RemoteCommandChannel(
            executable: "/usr/bin/ssh",
            arguments: configuration.options + [
                "-S", control,
                "-o", "ControlMaster=no",
                "-o", "ProxyCommand=/usr/bin/false",
                "--", host, command,
            ],
            environment: Self.sshEnvironment,
            onDisconnect: { [weak self] channel in
                Task { await self?.channelDidClose(channel) }
            }
        )
    }

    /// 记下一次没能打开常驻通道。
    private func logChannelFailure() {
        let host = host
        Self.logger.error("常驻通道没能打开：\(host, privacy: .private)")
    }
}
