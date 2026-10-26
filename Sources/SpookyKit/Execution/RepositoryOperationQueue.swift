import Foundation

// MARK: - OperationPermitPool

/// 可取消的并发门闩；排队中的取消不启动子进程。
actor OperationPermitPool {
    /// 尚可分配的执行槽。
    private var available: Int

    /// 按到达顺序等待的请求。
    private var waiters: [(UUID, CheckedContinuation<Void, Error>)] = []

    /// 创建固定容量的队列。
    init(capacity: Int) {
        available = capacity
    }

    /// 等待执行槽，取消只移除本请求。
    func acquire() async throws {
        try Task.checkCancellation()

        if available > 0 {
            available -= 1
            return
        }

        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                waiters.append((id, $0))
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    /// 把执行槽交给最早的等待者。
    func release() {
        guard !waiters.isEmpty else {
            available += 1
            return
        }

        waiters.removeFirst().1.resume()
    }

    /// 只取消仍在队列里的请求；已获得执行槽的请求由执行层回收。
    private func cancel(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.0 == id }) else {
            return
        }

        waiters.remove(at: index).1.resume(throwing: CancellationError())
    }
}

// MARK: - RepositoryOperationQueue

/// 同一主机的通道上限与同一工作区的写锁跨执行器共享。
actor RepositoryOperationQueue {
    /// 组合写操作持有的仓库锁，让内部命令继续共享同一临界区。
    @TaskLocal
    static var transaction: RepositoryLocation?

    /// 应用进程中的统一调度器。
    static let shared = RepositoryOperationQueue()

    /// 保留控制、取消与 SFTP 通道所需余量。
    static let maximumHostCommands = 8

    /// 主机级并发门闩。
    private var hosts: [String: OperationPermitPool] = [:]

    /// 仓库级写操作门闩。
    private var writers: [RepositoryLocation: OperationPermitPool] = [:]

    /// 只读查询可越过写队列；merge-tree 会创建对象，仍按写操作调度。
    nonisolated static func isReadOnly(_ arguments: [String]) -> Bool {
        guard let index = commandIndex(in: arguments) else { return false }

        let command = arguments[index]
        var options = arguments.dropFirst(index + 1)

        if command == "config" {
            // 读全局配置时先写作用域与 --includes，其后的查询与读仓库配置相同。
            if options.starts(with: ["--global", "--includes"]) {
                options = options.dropFirst(2)
            }

            // 读取 .gitmodules 里登记的子模块同样只是查询
            let submodules = options.count == 5
                && options.prefix(4).elementsEqual(["-z", "--file", ".gitmodules", "--get-regexp"])

            // 合并后的配置与只看仓库本地配置的两种按正则读取
            return submodules
                || (options.prefix(2).elementsEqual(["-z", "--get-regexp"]) && options.count == 3)
                || (options.prefix(3).elementsEqual(["-z", "--local", "--get-regexp"]) && options.count == 4)
        }

        // 只读出当前分支名；其余 branch 用法会新建、改名或删除分支。
        if command == "branch" {
            return options.elementsEqual(["--show-current"])
        }

        // 只有列出工作树是读取，其余 worktree 子命令都会改动仓库
        if command == "worktree" {
            return options.first == "list"
        }

        // 只有读取子模块状态是查询，其余 submodule 子命令会克隆、检出或改配置
        if command == "submodule" {
            return options.first == "status"
        }

        // 只计算对象哈希不写入对象库；带 -w 的写入仍走写队列。
        if command == "hash-object" {
            return !options.contains("-w")
        }

        // 只有列出与查看储藏是读取；不带子命令的 stash 等同 push，与其余子命令一样会写入。
        if command == "stash" {
            return options.first.map { ["list", "show"].contains($0) } ?? false
        }

        return [
            "status", "rev-parse", "rev-list", "merge-base", "check-ref-format",
            "show", "log", "ls-files", "for-each-ref", "diff", "var", "cat-file", "--version",
            "ls-tree", "blame", "shortlog", "archive", "format-patch", "verify-tag", "diff-tree",
        ]
        .contains(command)
    }

    /// 跳过受支持的全局参数，供调度和认证判断真正的子命令。
    nonisolated static func command(in arguments: [String]) -> String? {
        commandIndex(in: arguments).map { arguments[$0] }
    }

    /// 真正的子命令所在的位置；全局参数只有 `--literal-pathspecs`、`-c <键=值>` 与在子模块里执行的 `-C <路径>`。
    private nonisolated static func commandIndex(in arguments: [String]) -> Int? {
        var index = 0

        // 全局配置与工作目录只改变查询方式，读写属性由真正的子命令决定。
        while index < arguments.count {
            if arguments[index] == "--literal-pathspecs" {
                index += 1
            } else if ["-c", "-C"].contains(arguments[index]), index + 1 < arguments.count {
                index += 2
            } else {
                break
            }
        }

        return index < arguments.count ? index : nil
    }

    /// 取得共享门闩，所有写入路径都必须持有对应仓库的槽。
    func permits(for location: RepositoryLocation) -> (host: OperationPermitPool, write: OperationPermitPool) {
        let host: String =
            switch location {
            case .remote(let alias, _): alias
            case .local: ""
            }

        let hostPool = hosts[host] ?? OperationPermitPool(capacity: Self.maximumHostCommands)
        let writePool = writers[location] ?? OperationPermitPool(capacity: 1)
        hosts[host] = hostPool
        writers[location] = writePool
        return (hostPool, writePool)
    }

    /// 执行期间持有仓库写槽与主机槽，任何退出路径都释放槽位。
    func perform<T: Sendable>(
        at location: RepositoryLocation,
        writing: Bool,
        action: @Sendable () async throws -> T
    ) async throws -> T {
        let pools = permits(for: location)
        let ownsWrite = writing && Self.transaction != location

        if ownsWrite { try await pools.write.acquire() }

        do {
            try await pools.host.acquire()
        } catch {
            if ownsWrite { await pools.write.release() }
            throw error
        }

        do {
            try Task.checkCancellation()
            let result = try await action()
            await pools.host.release()
            if ownsWrite { await pools.write.release() }
            return result
        } catch {
            await pools.host.release()
            if ownsWrite { await pools.write.release() }
            throw error
        }
    }

}

// MARK: - GitOperationEvent

/// 一次命令的可观察生命周期，输出片段保留原始字节。
public enum GitOperationEvent: Sendable {
    /// 等待仓库或主机的执行槽。
    case queued

    /// 命令开始执行。
    case started

    /// stdout 或 stderr 的增量内容。
    case output(GitOutputEvent)

    /// 操作完成。
    case completed(GitCommandResult)

    /// 操作失败，错误仍保留类型与原始输出。
    case failed(any Error)

    /// 取消是否已确认远端退出。
    case cancelled(confirmed: Bool)
}

// MARK: - GitOperation

/// 持有命令任务及其事件流；取消传播到本机通道和远端进程组。
public final class GitOperation: Sendable {
    /// 有界事件流按产生顺序交付；完整输出从结果取得。
    public let events: AsyncStream<GitOperationEvent>

    /// 命令执行任务。
    private let task: Task<GitCommandResult, Error>

    /// 等待结果的任务被取消时，同步取消本操作。
    public var value: GitCommandResult {
        get async throws {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                self.task.cancel()
            }
        }
    }

    /// 建立命令任务，不把标准输入或连接令牌放入事件。
    init(
        execute: @escaping @Sendable (
            @escaping @Sendable (GitOperationEvent) -> Void
        ) async throws -> GitCommandResult
    ) {
        let (events, continuation) = AsyncStream<GitOperationEvent>.makeStream(bufferingPolicy: .bufferingNewest(256))
        self.events = events
        task = Task {
            defer { continuation.finish() }
            continuation.yield(.queued)

            do {
                let result = try await execute { continuation.yield($0) }
                continuation.yield(.completed(result))
                return result
            } catch {
                if error is CancellationError || ((error as? GitError)?.isCancelled ?? false) {
                    continuation.yield(.cancelled(confirmed: true))
                } else if (error as? RemoteConnectionError)?.kind == .cancellationUnconfirmed {
                    continuation.yield(.cancelled(confirmed: false))
                } else {
                    continuation.yield(.failed(error))
                }

                throw error
            }
        }
    }

    /// 用户取消与过期读取共用这一入口。
    public func cancel() {
        task.cancel()
    }
}
