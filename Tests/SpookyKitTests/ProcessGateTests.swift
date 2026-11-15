import Foundation
import Testing
import TestSupport

@testable import SpookyKit

/// 测试脚本用的闸门：武装、认领与报到。
struct ProcessGateTests {
    /// 会话取消读取时，宽限期过后的 KILL 可能落在认领之后、走到闸门之前；
    /// 认领本身就是报到，等报到的测试不会因此卡住，武装也只能被认领一次。
    @Test("认领武装即报到，被结束的认领进程不让等待卡住")
    func claimArrives() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-gate-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let gate = try ProcessGate(in: directory)
        defer { gate.release() }

        // 认领后立刻被 KILL，没有走到闸门：等报到照样结束
        try gate.arm()
        _ = try? await shell("\(gate.claim) && kill -KILL $$")
        await gate.arrival()

        // 武装已被认领，后来的进程认领不到
        #expect(try await shell("\(gate.claim) || echo unclaimed") == "unclaimed\n")

        // 再武装一次：认领的进程停在闸门上，放行后才继续
        try gate.arm()
        async let held = shell("\(gate.claim) && \(gate.hold) && echo released")
        await gate.arrival()

        gate.release()
        #expect(try await held == "released\n")
    }

    /// 用 `/bin/sh` 执行一行命令，返回标准输出。
    ///
    /// - Parameter command: 要执行的 shell 命令。
    private func shell(_ command: String) async throws -> String {
        let result = try await CommandExecutor.execute(
            executable: "/bin/sh",
            processArguments: ["-c", command]
        )

        return String(decoding: result.standardOutput, as: UTF8.self)
    }
}
