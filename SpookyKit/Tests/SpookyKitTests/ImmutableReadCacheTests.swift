import Foundation
import Testing

@testable import SpookyKit

/// 按哈希缓存的只读结果必须有上限，并且只复用成功的输出。
struct ImmutableReadCacheTests {
    /// 字节与条目数任一超限都会淘汰最久未使用的结果，单条过大的输出不进入缓存。
    @Test("按字节与条目数淘汰最久未使用的结果")
    func eviction() async throws {
        let cache = ImmutableReadCache(byteCapacity: 100, countCapacity: 3)
        let location = RepositoryLocation.local(path: "/temporary/cache")
        let keys = (0 ..< 6).map { ImmutableReadCache.Key(location: location, arguments: ["show", String($0)], input: nil) }

        await cache.store(Data(count: 25), for: keys[0])
        await cache.store(Data(count: 25), for: keys[1])
        await cache.store(Data(count: 25), for: keys[2])
        #expect(await cache.count == 3)

        // 读取会刷新使用顺序，随后的新条目淘汰的是更早的 keys[1]。
        #expect(await cache.value(for: keys[0]) != nil)
        await cache.store(Data(count: 10), for: keys[3])
        #expect(await cache.value(for: keys[1]) == nil)
        #expect(await cache.value(for: keys[0]) != nil)

        // 超过总字节上限时继续从最旧的条目淘汰。
        await cache.store(Data(count: 25), for: keys[4])
        await cache.store(Data(count: 25), for: keys[5])
        #expect(await cache.count <= 3)
        #expect(await cache.value(for: keys[5]) != nil)

        let oversized = ImmutableReadCache.Key(location: location, arguments: ["show", "large"], input: nil)
        await cache.store(Data(count: 26), for: oversized)
        #expect(await cache.value(for: oversized) == nil)
    }

    /// 相同的不可变查询只启动一次 Git；失败不缓存，参数或输入不同的查询各自执行。
    @Test("不可变查询只启动一次 Git")
    func reuse() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        let log = temporary.directory.appending(path: "invocations")
        let executable = temporary.directory.appending(path: "counting-git")
        let script = """
            #!/bin/sh
            printf 'run\\n' >> \(GitRunner.shellQuoted(log.path))
            for argument in "$@"; do
                if test "$argument" = fail; then printf 'failed\\n' >&2; exit 1; fi
            done
            cat
            printf 'output\\n'
            """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let runner = temporary.runner(at: temporary.directory.path, executable: executable.path)

        let first = try await runner.immutableRun(["log", "abc123"], input: Data("root\n".utf8))
        let second = try await runner.immutableRun(["log", "abc123"], input: Data("root\n".utf8))
        #expect(first == Data("root\noutput\n".utf8))
        #expect(second == first)
        #expect(try invocations(log) == 1)

        _ = try await runner.immutableRun(["log", "abc123"], input: Data("other\n".utf8))
        _ = try await runner.immutableRun(["log", "def456"])
        #expect(try invocations(log) == 3)

        await #expect(throws: GitError.self) { try await runner.immutableRun(["log", "fail"]) }
        await #expect(throws: GitError.self) { try await runner.immutableRun(["log", "fail"]) }
        #expect(try invocations(log) == 5)
    }

    /// 计数文件中每行代表一次进程启动。
    private func invocations(_ log: URL) throws -> Int {
        String(decoding: try Data(contentsOf: log), as: UTF8.self).split(separator: "\n").count
    }
}
