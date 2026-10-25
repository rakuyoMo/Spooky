import Foundation
import Synchronization

// MARK: - RepositoryScan

/// 在选定目录下寻找 Git 仓库；服务器目录只在 B 上用 `find` 扫描，结果流式回到 A。
///
/// 扫描不跟随符号链接，不越出选定目录；隐藏目录与不能读取的目录跳过，找到的仓库内部不再报告其它仓库。
public enum RepositoryScan {
    /// 在所在机器上执行的扫描脚本：先确认根目录可用，再列出每个 `.git` 的路径，以 NUL 结尾。
    ///
    /// 支持 `-s` 的 `find` 按名称顺序遍历，同一目录里的 `.git` 先于其它子目录出现，父仓库因此先于嵌套的仓库报告。
    /// 退出码沿用目录检查的约定：2 不存在、3 不能读取；`find` 遇到不能读取的子目录时以 1 结束，照常算完成。
    static let script = """
        if ! test -d "$1"; then printf '%s\\n' 'Directory does not exist' >&2; exit 2; fi
        /usr/bin/perl -e 'opendir(my $directory, $ARGV[0]) or do { print STDERR "$!\\n"; exit 3 }' -- "$1" || exit
        if /usr/bin/find -s / -maxdepth 0 > /dev/null 2>&1; then
            exec /usr/bin/find -H -s "$1" -mindepth 1 \\( -name .git -print0 -prune \\) -o \\( -name '.*' -prune \\)
        fi
        exec /usr/bin/find -H "$1" -mindepth 1 \\( -name .git -print0 -prune \\) -o \\( -name '.*' -prune \\)
        """

    /// 流式返回找到的仓库；位置带着主机，界面按 ``RepositoryLocation/host`` 分组。
    ///
    /// 取消迭代所在的任务即停止扫描：本机终止进程组，服务器经包装器终止 B 上的进程组。
    ///
    /// - Parameter directory: 用户选定的本机或服务器目录，必须是绝对路径。
    /// - Returns: 结束时正常完成；根目录不存在或不能读取时以 ``HostOperationError`` 结束。
    public static func repositories(in directory: RepositoryLocation) -> AsyncThrowingStream<RepositoryLocation, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let root = try HostOperationError.normalized(directory.path)
                    let collector = Collector(host: directory.host)

                    _ = try await HostExecution.run(
                        ["/bin/sh", "-c", script, "spooky-scan", root],
                        at: directory.host.map { .remote(host: $0, path: root) } ?? .local(path: root),
                        acceptedExitCodes: [0, 1]
                    ) { output in
                        guard case .standardOutput(let data) = output else { return }

                        for location in collector.receive(data) {
                            continuation.yield(location)
                        }
                    }

                    continuation.finish()
                } catch {
                    // 取消由订阅方发起，按正常结束处理
                    if Task.isCancelled {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: HostOperationError.classify(error))
                    }
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: RepositoryScan.Collector

extension RepositoryScan {
    /// 把 `find` 的输出块还原成仓库位置：跨块的半条路径留到下一块，已找到的仓库内部的结果丢弃。
    final class Collector: Sendable {
        /// 结果所在的主机；本机为 nil。
        let host: String?

        /// 尚未遇到 NUL 的字节与已报告的仓库根路径；输出回调可能来自不同线程，用锁保持顺序。
        private let state = Mutex((pending: Data(), found: [String]()))

        /// 创建一次扫描专用的收集器。
        init(host: String?) {
            self.host = host
        }

        /// 读入一块输出，返回其中新找到的仓库。
        func receive(_ data: Data) -> [RepositoryLocation] {
            let repositories = state.withLock { state in
                state.pending.append(data)
                var repositories: [String] = []

                while let end = state.pending.firstIndex(of: 0) {
                    let record = String(decoding: state.pending[state.pending.startIndex ..< end], as: UTF8.self)
                    state.pending.removeSubrange(state.pending.startIndex ... end)

                    // 每条记录是 “<仓库>/.git”，去掉最后一段得到仓库根
                    guard record.hasSuffix("/.git") else { continue }

                    let repository = String(record.dropLast(5))

                    // 已报告的仓库内部的结果丢弃
                    guard !state.found.contains(where: { repository.hasPrefix($0 + "/") }) else { continue }

                    state.found.append(repository)
                    repositories.append(repository)
                }

                return repositories
            }

            return repositories.map { path in
                host.map { .remote(host: $0, path: path) } ?? .local(path: path)
            }
        }
    }
}
