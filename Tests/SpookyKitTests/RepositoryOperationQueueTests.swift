import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryOperationQueueTests

/// 主机上的执行名额与取消通道名额。
struct RepositoryOperationQueueTests {
    /// 被取消的命令在服务器上结束之前一直占着会话，取消得到确认时那个会话也可能还没释放；
    /// 执行与取消的名额再加上这一个超过 OpenSSH 默认的每条连接 10 个会话时，服务器拒绝开新会话。
    @Test("执行与取消的名额留出一个还没释放的会话")
    func sessionBudget() {
        let sessions = RepositoryOperationQueue.maximumHostCommands
            + RepositoryOperationQueue.maximumHostCancellations

        #expect(sessions + 1 <= 10)
    }

    /// 路径规格的开关只影响参数解释，读取仍能越过写队列，写入与未知命令仍受写锁保护。
    @Test("路径规格全局选项保留命令分类", arguments: ["--literal-pathspecs", "--no-literal-pathspecs"])
    func pathspecCommands(option: String) {
        let prefix = ["-c", "core.quotepath=false", option, "-C", "directory"]
        let cases: [([String], Bool)] = [
            (["status", "--porcelain=v2", "-z"], true),
            (["diff", "--cached", "--", ":(literal)file"], true),
            (["hash-object", "--no-filters", "--", "file"], true),
            (["hash-object", "-w", "--stdin"], false),
            (["apply", "--cached", "-"], false),
            (["config", "--local", "user.name", "Test"], false),
            (["unknown-command"], false),
        ]

        for (arguments, readOnly) in cases {
            #expect(RepositoryOperationQueue.command(in: prefix + arguments) == arguments.first)
            #expect(RepositoryOperationQueue.isReadOnly(prefix + arguments) == readOnly)
        }

        #expect(RepositoryOperationQueue.command(in: [option]) == nil)
        #expect(!RepositoryOperationQueue.isReadOnly([option]))
        #expect(!RepositoryOperationQueue.isReadOnly([option, "-C"]))
    }

    /// 同一主机同时打开的取消通道不超过名额，多出的依次执行，最后都执行完。
    @Test("取消通道按主机限量")
    func cancellationsPerHost() async throws {
        let queue = RepositoryOperationQueue()
        let gauge = ConcurrencyGauge()
        let count = RepositoryOperationQueue.maximumHostCancellations * 3

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0 ..< count {
                group.addTask {
                    try await queue.performCancellation(on: "spooky-test") {
                        await gauge.enter()
                        try await Task.sleep(for: .milliseconds(50))
                        await gauge.leave()
                    }
                }
            }

            try await group.waitForAll()
        }

        #expect(await gauge.peak <= RepositoryOperationQueue.maximumHostCancellations)
        #expect(await gauge.finished == count)
    }
}

// MARK: - ConcurrencyGauge

/// 记下同时执行的动作数的峰值与执行完的动作数。
private actor ConcurrencyGauge {
    /// 同时执行的动作数的峰值。
    private(set) var peak = 0

    /// 执行完的动作数。
    private(set) var finished = 0

    /// 正在执行的动作数。
    private var running = 0

    /// 动作开始执行。
    func enter() {
        running += 1
        peak = max(peak, running)
    }

    /// 动作执行完。
    func leave() {
        running -= 1
        finished += 1
    }
}
