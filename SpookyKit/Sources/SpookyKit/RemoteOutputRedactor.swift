import Foundation
import Synchronization

/// 对中继交付的口令做跨块脱敏；Git 的其它输出保持原始字节。
final class RemoteOutputRedactor: Sendable {
    /// 当前操作已取得的敏感值，只存在内存中。
    private let values: @Sendable () -> [Data]

    /// 脱敏后的输出订阅者。
    private let output: @Sendable (GitOutputEvent) -> Void

    /// 每条管道独立保留可能属于口令前缀的尾部。
    private let buffers = Mutex((stdout: Data(), stderr: Data()))

    /// 用当前操作的凭据集合建立过滤器。
    init(values: @escaping @Sendable () -> [Data], output: @escaping @Sendable (GitOutputEvent) -> Void) {
        self.values = values
        self.output = output
    }

    /// 输出片段不得以块边界为由泄露被拆开的口令。
    func receive(_ event: GitOutputEvent) {
        buffers.withLock {
            switch event {
            case .standardOutput(let data):
                $0.stdout.append(data)
                let chunk = consume(&$0.stdout, final: false)
                if !chunk.isEmpty { output(.standardOutput(chunk)) }

            case .standardError(let data):
                $0.stderr.append(data)
                let chunk = consume(&$0.stderr, final: false)
                if !chunk.isEmpty { output(.standardError(chunk)) }
            }
        }
    }

    /// 命令结束后排空未构成完整口令的剩余字节。
    func finish() {
        buffers.withLock {
            let stdout = consume(&$0.stdout, final: true)
            let stderr = consume(&$0.stderr, final: true)
            if !stdout.isEmpty { output(.standardOutput(stdout)) }
            if !stderr.isEmpty { output(.standardError(stderr)) }
        }
    }

    /// 返回值和错误值采用相同的脱敏规则。
    func result(_ result: GitCommandResult) -> GitCommandResult {
        var stdout = result.standardOutput
        var stderr = result.standardError
        return GitCommandResult(
            arguments: result.arguments,
            standardOutput: consume(&stdout, final: true),
            standardError: consume(&stderr, final: true),
            terminationStatus: result.terminationStatus,
            isCancelled: result.isCancelled
        )
    }

    /// 优先替换完整匹配，再保留最长的可能口令前缀。
    private func consume(_ data: inout Data, final: Bool) -> Data {
        let secrets = values().filter { !$0.isEmpty }
        var result = Data()

        while !data.isEmpty {
            let match = secrets.compactMap { data.range(of: $0) }
                .min { $0.lowerBound < $1.lowerBound }

            if let match {
                result.append(data[..<match.lowerBound])
                result.append(Data("[REDACTED]".utf8))
                data.removeSubrange(data.startIndex ..< match.upperBound)
                continue
            }

            var retained = 0

            if !final {
                for secret in secrets {
                    let maximum = min(data.count, secret.count - 1)
                    guard maximum > retained else { continue }

                    for length in stride(from: maximum, through: retained + 1, by: -1) {
                        if data.suffix(length) == secret.prefix(length) {
                            retained = length
                            break
                        }
                    }
                }
            }

            result.append(data.prefix(data.count - retained))
            data = Data(data.suffix(retained))
            break
        }

        return result
    }
}
