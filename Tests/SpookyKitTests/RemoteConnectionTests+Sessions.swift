import Foundation
import Testing
import TestSupport

@testable import SpookyKit

/// 关掉常驻通道时另开会话的名额：每条连接同时另开的会话不超过上限，等名额时被取消的命令不发取消。
extension RemoteConnectionTests {
    /// 关掉常驻通道时，超出会话名额的读取等前面的读取结束才在 B 上开始，B 上同时执行的读取正好占满名额；
    /// 等名额时被取消的读取立即以取消结束、不为它发出取消，主机的取消名额被占着时它也不等。
    @Test("关掉常驻通道时另开会话按连接限量")
    func sessionsWithoutChannel() async throws {
        let fixture = try await RemoteFixture.create()
        var configuration = RemoteFixture.configuration
        configuration.usesResidentChannel = false
        let connection = fixture.connection(configuration: configuration)
        let (released, release) = AsyncStream<Void>.makeStream()

        do {
            // 留一处没有提交的改动，Diff 才会调用外部程序
            _ = try await RemoteFixture.raw([
                "/bin/sh", "-c",
                "cd \"$1\" && echo one > file.txt && git add file.txt && git commit -q -m one && echo two > file.txt",
                "fixture", fixture.repository,
            ])
            _ = try await RemoteFixture.raw(["/bin/mkdir", fixture.root + "/running"])
            _ = try await connection.open()

            // 外部 Diff 程序在 B 上登记自己并写出此刻登记着的条数，报到后停在闸门上，放行后注销
            let gate = try ProcessGate(in: URL(fileURLWithPath: fixture.root))
            let registry = GitRunner.shellQuoted(fixture.root + "/running")
            let program = "mkdir \(registry)/$$ && ls \(registry) | wc -l && \(gate.command); rmdir \(registry)/$$; :"
            let limit = RepositoryOperationQueue.maximumConnectionSessions

            let reads = (0 ..< limit + 4).map { _ in
                connection.operation(["-c", "diff.external=" + program, "diff"])
            }

            for _ in 0 ..< limit {
                await gate.arrival()
            }

            // 占住主机的取消名额：被取消的读取如果发出取消，就会一直等这个名额
            let (held, hold) = AsyncStream<Void>.makeStream()

            let holder = Task {
                try await RepositoryOperationQueue.shared.performCancellation(on: connection.host) {
                    hold.finish()

                    for await _ in released { }
                }
            }

            for await _ in held { }

            // 会话名额已经占满，再发起的读取开始执行后停在等名额上，这时取消它
            let waiting = connection.operation(["-c", "diff.external=" + program, "diff"])

            for await event in waiting.events {
                if case .started = event { break }
            }

            waiting.cancel()
            await #expect(throws: CancellationError.self) { try await waiting.value }

            release.finish()
            try await holder.value

            // 放行全部读取：先报到的结束之后，其余的才在 B 上开始
            for _ in reads {
                gate.release()
            }

            var counts: [Int] = []

            for read in reads {
                let output = String(decoding: try await read.value.standardOutput, as: UTF8.self)
                counts.append(try #require(Int(output.trimmingCharacters(in: .whitespacesAndNewlines))))
            }

            #expect(counts.max() == limit)

            await connection.close()
            try await fixture.remove()
        } catch {
            release.finish()
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }
}
