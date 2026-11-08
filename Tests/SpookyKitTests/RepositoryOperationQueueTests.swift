import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryOperationQueueTests

/// 主机上的执行名额与取消通道名额。
struct RepositoryOperationQueueTests {
    /// 路径规格的开关只影响参数解释，读取仍能越过写队列，写入与未知命令仍受写锁保护。
    @Test("路径规格全局选项保留命令分类")
    func pathspecCommands() {
        let cases: [([String], Bool)] = [
            (["status", "--porcelain=v2", "-z"], true),
            (["diff", "--cached", "--", ":(literal)file"], true),
            (["hash-object", "--no-filters", "--", "file"], true),
            (["hash-object", "-w", "--stdin"], false),
            (["apply", "--cached", "-"], false),
            (["config", "--local", "user.name", "Test"], false),
            (["unknown-command"], false),
        ]

        for option in ["--literal-pathspecs", "--no-literal-pathspecs"] {
            let prefix = ["-c", "core.quotepath=false", option, "-C", "directory"]

            for (arguments, readOnly) in cases {
                #expect(RepositoryOperationQueue.command(in: prefix + arguments) == arguments.first, "\(option)")
                #expect(RepositoryOperationQueue.isReadOnly(prefix + arguments) == readOnly, "\(option) \(arguments)")
            }

            #expect(RepositoryOperationQueue.command(in: [option]) == nil, "\(option)")
            #expect(!RepositoryOperationQueue.isReadOnly([option]), "\(option)")
            #expect(!RepositoryOperationQueue.isReadOnly([option, "-C"]), "\(option)")
        }
    }

    /// 同一主机同时打开的取消通道不超过名额，多出的依次执行，最后都执行完；
    /// 被取消的命令在服务器上结束之前一直占着会话，取消得到确认时那个会话也可能还没释放，
    /// 执行与取消的名额再加上这一个超过 OpenSSH 默认的每条连接 10 个会话时，服务器拒绝开新会话。
    @Test("取消通道按主机限量，执行与取消的名额留出一个还没释放的会话")
    func cancellationsPerHost() async throws {
        let sessions = RepositoryOperationQueue.maximumHostCommands
            + RepositoryOperationQueue.maximumHostCancellations

        #expect(sessions + 1 <= 10)

        let queue = RepositoryOperationQueue()
        let gauge = ConcurrencyGauge()
        let count = RepositoryOperationQueue.maximumHostCancellations * 3

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0 ..< count {
                group.addTask {
                    try await queue.performCancellation(on: "spooky-test") {
                        await gauge.hold()
                    }
                }
            }

            // 每有一个动作开始执行就放行最早的一个，名额之外的动作只能在之前的动作结束后开始
            var entries = gauge.entries.makeAsyncIterator()

            for _ in 0 ..< count {
                await entries.next()
                await gauge.releaseOne()
            }

            try await group.waitForAll()
        }

        #expect(await gauge.peak <= RepositoryOperationQueue.maximumHostCancellations)
        #expect(await gauge.finished == count)
    }
}

// MARK: - ConcurrencyGauge

/// 记下同时执行的动作数的峰值与执行完的动作数；动作开始后停住，由测试逐个放行。
private actor ConcurrencyGauge {
    /// 每有一个动作开始执行就产出一次。
    nonisolated let entries: AsyncStream<Void>

    /// 同时执行的动作数的峰值。
    private(set) var peak = 0

    /// 执行完的动作数。
    private(set) var finished = 0

    /// 正在执行的动作数。
    private var running = 0

    /// 已开始、等待放行的动作，按开始的先后排列。
    private var held: [CheckedContinuation<Void, Never>] = []

    /// 产出 `entries` 的一端。
    private let entry: AsyncStream<Void>.Continuation

    /// 建一个还没有动作执行的计量器。
    init() {
        (entries, entry) = AsyncStream<Void>.makeStream()
    }

    /// 动作开始执行，停在这里直到测试放行，再记为执行完。
    func hold() async {
        running += 1
        peak = max(peak, running)

        await withCheckedContinuation { continuation in
            held.append(continuation)
            entry.yield()
        }

        running -= 1
        finished += 1
    }

    /// 放行最早开始的一个动作。
    func releaseOne() {
        guard !held.isEmpty else {
            return
        }

        held.removeFirst().resume()
    }
}
