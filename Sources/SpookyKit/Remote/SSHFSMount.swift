import Darwin
import Foundation
import Subprocess
import Synchronization

// MARK: - SSHFSMount

/// 用用户自己装的 sshfs 把 B 上的仓库目录挂到本机文件夹。
///
/// sshfs 只经 `~/.ssh/config` 的主机别名自己开 SSH 连接，不复用 Spooky 的主连接：主连接关闭时挂载会随之断开。
/// sshfs 连上后转入后台，前台进程的退出码就是挂载结果。
enum SSHFSMount {
    /// 依次查看的安装位置：Apple 芯片与 Intel 上 Homebrew 的目录；FUSE 实现的安装包同样装在后者。
    static let defaultCandidates = ["/opt/homebrew/bin/sshfs", "/usr/local/bin/sshfs"]

    /// 写出标准错误后，等前台进程自己结束的时间。
    static let failureGrace = Duration.seconds(2)

    /// 找 sshfs：先看常见的安装位置，再按 Environment 设置的 `PATH`（自定义变量覆盖登录 shell 的变量）找，
    /// 都没有时按 Spooky 继承的 `PATH`；取第一个可执行文件。
    ///
    /// - Parameters:
    ///   - candidates: 先查看的安装位置。
    ///   - settings: 本机的程序与环境设置。
    ///   - inheritedPath: Spooky 继承的 `PATH`。
    static func executable(
        candidates: [String] = defaultCandidates,
        settings: LocalExecutionSettings = .current,
        inheritedPath: String? = ProcessInfo.processInfo.environment["PATH"]
    ) -> String? {
        let path = settings.customVariables["PATH"] ?? settings.loginShellVariables["PATH"] ?? inheritedPath ?? ""
        let searched = path.split(separator: ":").map { String($0) + "/sshfs" }

        return (candidates + searched).first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// sshfs 的参数：远端写作 `<别名>:<仓库路径>`，挂到选定的文件夹；不允许询问时多一个 `BatchMode=yes`。
    ///
    /// 参数逐个交给进程，不经 shell。sshfs 自己总给 ssh 加 `-a` 与 `ClearAllForwardings=yes`，不转发 agent；
    /// 它只把认得的 `-o` 选项交给 ssh，其余当成挂载选项而失败，所以只另传严格核对主机密钥。
    ///
    /// - Parameters:
    ///   - host: 主机别名。
    ///   - path: B 上的仓库目录。
    ///   - folder: 挂载到的本机文件夹。
    ///   - allowsInteraction: 是否允许经回调询问私钥口令。
    static func arguments(host: String, path: String, folder: URL, allowsInteraction: Bool) -> [String] {
        let batch = allowsInteraction ? [] : ["-o", "BatchMode=yes"]

        return [host + ":" + path, folder.path, "-o", "StrictHostKeyChecking=yes"] + batch
    }

    /// 挂载仓库目录；不随调用方取消，避免留下半挂的卷。
    ///
    /// - Parameters:
    ///   - host: 主机别名。
    ///   - path: B 上的仓库目录。
    ///   - folder: 挂载到的本机文件夹。
    ///   - handler: 询问私钥口令的回调；nil 时不询问。
    static func mount(
        host: String,
        path: String,
        at folder: URL,
        handler: RemoteCallbackHandler?
    ) async -> Result<Void, RemoteMountFailure> {
        guard let executable = executable() else {
            return .failure(.launch(String(cString: strerror(ENOENT))))
        }

        return await Task {
            var overrides = LocalExecutionSettings.current.sshOverrides
            var session: LocalCallbackSession? = nil

            // 用户发起时经回调中继询问口令；中继活到前台进程结束，口令在转入后台之前问完
            if let handler {
                do {
                    session = try LocalCallbackSession(host: host + ":" + path, handler: handler)
                } catch {
                    return .failure(.launch(error.localizedDescription))
                }
            }

            defer { session?.close() }

            overrides.merge(session?.sshOverrides ?? [:]) { $1 }

            let environment = overrides.reduce(into: ProcessInfo.processInfo.environment) {
                $0[$1.key.rawValue] = $1.value
            }

            return await run(
                executable: executable,
                arguments: arguments(host: host, path: path, folder: folder, allowsInteraction: handler != nil),
                environment: environment
            )
        }.value
    }

    /// 运行 sshfs，等前台进程结束；退出码为 0 是挂上，否则带上原样的标准错误。
    ///
    /// 有的 FUSE 实现（如 FUSE-T）在挂载失败时写出标准错误后，前台进程一直等它启动的文件服务进程退出而不结束；
    /// 写出标准错误后过了 ``failureGrace`` 仍没结束时，先结束它的子进程，再结束它自己。
    ///
    /// - Parameters:
    ///   - executable: sshfs 的路径。
    ///   - arguments: 参数。
    ///   - environment: 完整的环境变量。
    ///   - grace: 写出标准错误后等它自己结束的时间。
    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        grace: Duration = failureGrace
    ) async -> Result<Void, RemoteMountFailure> {
        let invocation = Invocation(executable: executable, arguments: arguments, environment: environment)

        return await withCheckedContinuation { continuation in
            invocation.start(grace: grace) { continuation.resume(returning: $0) }
        }
    }
}

// MARK: SSHFSMount.Invocation

extension SSHFSMount {
    /// 一次 sshfs 前台进程：收集标准错误，结束时交出结果。
    ///
    /// 不经 `CommandExecutor`：它在取消时结束整个进程组，还要等管道读到 EOF；挂上后转入后台的 sshfs 不能被它们牵连。
    private final class Invocation: Sendable {
        /// 前台进程；只在 ``start(grace:completion:)`` 与它注册的回调里访问。
        private let process = Process()

        /// 标准错误的管道。
        private let pipe = Pipe()

        /// 已读到的标准错误。
        private let standardError = Mutex(Data())

        /// 准备好进程：标准输入与输出接 `/dev/null`，标准错误接管道。
        init(executable: String, arguments: [String], environment: [String: String]) {
            process.executableURL = URL(filePath: executable)
            process.arguments = arguments
            process.environment = environment
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = pipe
        }

        /// 启动进程；结束或没能启动时调用一次 `completion`。
        func start(grace: Duration, completion: @escaping @Sendable (Result<Void, RemoteMountFailure>) -> Void) {
            process.terminationHandler = { [self] process in
                pipe.fileHandleForReading.readabilityHandler = nil

                let text = collect(Self.drain(pipe.fileHandleForReading))

                completion(
                    process.terminationStatus == 0 && process.terminationReason == .exit
                        ? .success(())
                        : .failure(.sshfs(status: process.terminationStatus, standardError: text))
                )

                // 结束后不再需要回调，断开进程与它之间的相互引用
                process.terminationHandler = nil
            }

            // 第一次读到标准错误时开始计时
            pipe.fileHandleForReading.readabilityHandler = { [self] handle in
                let data = handle.availableData

                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }

                let isFirst = standardError.withLock { stored in
                    defer { stored.append(data) }
                    return stored.isEmpty
                }

                if isFirst {
                    DispatchQueue.global().asyncAfter(deadline: .now() + grace.timeInterval) { [self] in
                        stopIfRunning()
                    }
                }
            }

            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                completion(.failure(.launch(error.localizedDescription)))
            }
        }

        /// 加上最后读到的内容，返回去掉首尾空白的全部标准错误。
        private func collect(_ rest: Data) -> String {
            let data = standardError.withLock { stored in
                stored.append(rest)
                return stored
            }

            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// 前台进程还没结束时，先结束它的子进程，再结束它自己。
        private func stopIfRunning() {
            guard process.isRunning else {
                return
            }

            let parent = process.processIdentifier
            var children = [pid_t](repeating: 0, count: 64)
            let count = proc_listchildpids(parent, &children, Int32(children.count * MemoryLayout<pid_t>.size))

            for child in children.prefix(max(0, Int(count))) where child > 0 {
                kill(child, SIGTERM)
            }

            process.terminate()
        }

        /// 不阻塞地读完管道里已有的内容：写入端可能还被转入后台的进程开着。
        private static func drain(_ handle: FileHandle) -> Data {
            let descriptor = handle.fileDescriptor
            _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)

            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)

            while true {
                let count = read(descriptor, &buffer, buffer.count)

                guard count > 0 else {
                    return data
                }

                data.append(contentsOf: buffer.prefix(count))
            }
        }
    }
}

// MARK: - Helpers

extension Duration {
    /// 换成秒数，交给 Dispatch 的时间。
    fileprivate var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
