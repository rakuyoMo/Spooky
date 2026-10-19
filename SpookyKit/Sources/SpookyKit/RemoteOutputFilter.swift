import Foundation
import Synchronization

/// 从 stderr 尾部移除包装器完成帧，保留 Git 原文并区分 SSH 的退出码。
final class RemoteOutputFilter: Sendable {
    /// 当前操作的不可预测标识。
    private let operation: String

    /// 输出片段订阅者。
    private let onOutput: @Sendable (GitOutputEvent) -> Void

    /// 延迟发送的尾部与已发送字节数，共用锁保持顺序。
    private let pending = Mutex((tail: Data(), emitted: 0))

    /// 为一条操作创建独立的尾帧过滤器。
    init(operation: String, onOutput: @escaping @Sendable (GitOutputEvent) -> Void) {
        self.operation = operation
        self.onOutput = onOutput
    }

    /// 只延迟可能属于完成帧的前缀，短进度也能在命令运行时立即显示。
    func receive(_ event: GitOutputEvent) {
        switch event {
        case .standardOutput:
            onOutput(event)

        case .standardError(let data):
            pending.withLock { state in
                state.tail.append(data)

                let marker = Data("\u{1e}SPOOKY:\(operation):".utf8)
                let retained: Int

                // 完整标记出现后等待状态字段；其余时候只保留跨块的最长标记前缀。
                if let range = state.tail.range(of: marker, options: .backwards),
                    state.tail.distance(from: range.lowerBound, to: state.tail.endIndex) <= 128
                {
                    retained = state.tail.distance(from: range.lowerBound, to: state.tail.endIndex)
                } else {
                    retained =
                        stride(from: min(marker.count, state.tail.count), through: 1, by: -1)
                        .first { state.tail.suffix($0) == marker.prefix($0) } ?? 0
                }

                if state.tail.count > retained {
                    let chunk = Data(state.tail.prefix(state.tail.count - retained))
                    state.tail.removeFirst(chunk.count)
                    state.emitted += chunk.count
                    onOutput(.standardError(chunk))
                }
            }
        }
    }

    /// 只有操作标识匹配且位于末尾的帧才作为进程状态。
    func completed(_ raw: GitCommandResult) throws -> GitCommandResult {
        let marker = Data("\u{1e}SPOOKY:\(operation):".utf8)
        guard raw.standardError.last == 0x1f,
              let range = raw.standardError.range(of: marker, options: .backwards)
        else {
            pending.withLock {
                if !$0.tail.isEmpty { onOutput(.standardError($0.tail)) }
                $0.tail = Data()
            }

            if raw.exitCode == 255 { throw RemoteConnectionError.ssh(raw) }
            throw RemoteConnectionError(.protocolFailure, result: raw)
        }

        let fields = String(
            decoding: raw.standardError[range.upperBound...].dropLast(),
            as: UTF8.self
        ).split(separator: ":")
        guard fields.count == 3,
              let code = Int32(fields[0]), (0...255).contains(code),
              let signal = Int32(fields[1]), (0...127).contains(signal),
              fields[2] == "0" || fields[2] == "1"
        else { throw RemoteConnectionError(.protocolFailure, result: raw) }

        let stderr = Data(raw.standardError[..<range.lowerBound])
        pending.withLock {
            if stderr.count > $0.emitted {
                onOutput(.standardError(Data(stderr.dropFirst($0.emitted))))
            }

            $0.tail = Data()
        }

        let result = GitCommandResult(
            arguments: raw.arguments,
            standardOutput: raw.standardOutput,
            standardError: stderr,
            terminationStatus: signal == 0 ? .exited(code) : .signaled(signal),
            isCancelled: fields[2] == "1"
        )

        if result.isCancelled { throw GitError(result: result, category: .cancelled, diagnostic: nil) }
        return result
    }
}
