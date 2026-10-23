import Darwin
import Foundation
import Testing

@testable import SpookyKit

/// 大仓库验收：本机 2 秒、服务器 5 秒内读出首屏状态，历史分页到界面上限时内存仍在 512 MB 以内。
///
/// 生成代表性仓库需要数十秒，默认跳过；以 `SPOOKY_PERFORMANCE_TESTS=1` 显式开启，
/// 服务器场景另需 `SPOOKY_REMOTE_TESTS=1`。发布构建的测量方法见 docs/testing/M5.md。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_PERFORMANCE_TESTS"] == "1"))
struct PerformanceTests {
    /// 工作区中的文件数。
    static let files = 100_000

    /// 历史中的提交数，与界面的分页加载上限相同。
    static let commits = 50_000

    /// 已修改的跟踪文件数。
    static let modified = 2000

    /// 未跟踪文件数。
    static let untracked = 1000

    /// fast-import 输入：第一个提交写入全部文件，其余提交依次修改同一个记录文件。
    private static func stream() -> Data {
        var text = "commit refs/heads/main\nmark :1\ncommitter Spooky Test <spooky@example.invalid> 1790000000 +0000\n"
        text += "data 4\nroot\n"

        for index in 0 ..< files {
            let content = "file \(index)\n"
            text += "M 100644 inline dir\(index % 100)/file\(index).txt\ndata \(content.utf8.count)\n\(content)\n"
        }

        var stream = Data(text.utf8)

        for index in 2 ... commits {
            let message = "Commit \(index)\n"
            let content = "\(index)\n"
            stream.append(Data("""
                commit refs/heads/main
                mark :\(index)
                committer Spooky Test <spooky@example.invalid> \(1_790_000_000 + index) +0000
                data \(message.utf8.count)
                \(message)from :\(index - 1)
                M 100644 inline history.txt
                data \(content.utf8.count)
                \(content)

                """.utf8))
        }

        return stream
    }

    /// 在本机工作区制造已修改与未跟踪文件。
    private static func change(root: URL) throws {
        for index in 0 ..< modified {
            let url = root.appending(path: "dir\(index % 100)/file\(index).txt")
            try Data("file \(index)\nchanged\n".utf8).write(to: url)
        }

        for index in 0 ..< untracked {
            try Data("new\n".utf8).write(to: root.appending(path: "untracked\(index).txt"))
        }
    }

    /// 按界面的最大分页逐页读到最后一页，返回全部提交与耗时。
    private static func loadHistory(
        _ history: RepositoryHistory,
        head: String
    ) async throws -> (commits: [HistoryCommit], duration: Duration) {
        let start = ContinuousClock.now
        var commits: [HistoryCommit] = []
        var hasMore = true

        while hasMore {
            let page = try await history.page(roots: [head], offset: commits.count, limit: 1000)
            commits += page.commits
            hasMore = page.hasMore
        }

        return (commits, start.duration(to: .now))
    }

    /// 进程的物理内存占用，与活动监视器的 “内存” 一致。
    private static func footprint() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }

    /// 本机大仓库的首屏状态与历史分页。
    @Test("本机大仓库首屏状态与历史分页", .timeLimit(.minutes(10)))
    func localRepository() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize()
        _ = try await fixture.runner.run(["fast-import", "--quiet"], input: Self.stream())
        _ = try await fixture.runner.run(["reset", "--hard", "--quiet", "main"])
        try Self.change(root: fixture.directory)
        let baseline = Self.footprint()

        // 首屏与打开仓库相同：校验版本与工作区，再读取并解析状态。
        let start = ContinuousClock.now
        _ = try await fixture.runner.openLocalRepository()
        let status = try await fixture.runner.status()
        let firstScreen = start.duration(to: .now)
        #expect(firstScreen < .seconds(2))
        #expect(status.entries.count == Self.modified + Self.untracked)

        // 像界面一样持有全部已加载的提交与状态，再测量内存增量。
        let history = try await Self.loadHistory(
            RepositoryHistory(runner: fixture.runner),
            head: try #require(status.branch.oid)
        )
        let growth = withExtendedLifetime((status, history.commits)) { Self.footprint() - baseline }
        #expect(history.commits.count == Self.commits)
        #expect(growth < 512 * 1024 * 1024)

        // 性能测试把实测数值写进测试日志，供人工核对；只在显式开启性能测试时输出。
        // swiftlint:disable:next no_direct_standard_out_logs
        print(
            "local first screen: \(firstScreen), history: \(history.duration), "
                + "memory growth: \(growth / 1024 / 1024) MiB"
        )
    }

    /// 服务器大仓库：建立专属主连接、完成体检并读出首屏状态。
    @Test(
        "服务器大仓库首屏状态",
        .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"),
        .timeLimit(.minutes(10))
    )
    func remoteRepository() async throws {
        let fixture = try await RemoteFixture.create()

        do {
            _ = try await RemoteFixture.raw(
                ["git", "-C", fixture.repository, "fast-import", "--quiet"],
                input: Self.stream()
            )
            _ = try await RemoteFixture.raw(["git", "-C", fixture.repository, "reset", "--hard", "--quiet", "main"])
            let script = """
                cd "$1" || exit 1
                i=0
                while test "$i" -lt \(Self.modified); do printf 'changed\\n' >> "dir$((i % 100))/file$i.txt"; i=$((i + 1)); done
                i=0
                while test "$i" -lt \(Self.untracked); do printf 'new\\n' > "untracked$i.txt"; i=$((i + 1)); done
                """
            _ = try await RemoteFixture.raw(["/bin/sh", "-c", script, "fixture", fixture.repository])

            // 首屏包括主连接、体检、包装器部署与第一次状态读取。
            let connection = fixture.connection()
            let start = ContinuousClock.now
            _ = try await connection.open()
            let output = try await connection.execute([
                "status", "--porcelain=v2", "-z", "--branch", "--untracked-files=all",
            ])
            let status = try WorkingCopyStatus(porcelainV2: output.standardOutput)
            let firstScreen = start.duration(to: .now)
            #expect(firstScreen < .seconds(5))
            #expect(status.entries.count == Self.modified + Self.untracked)

            // 性能测试把实测数值写进测试日志，供人工核对；只在显式开启性能测试时输出。
            // swiftlint:disable:next no_direct_standard_out_logs
            print("remote first screen: \(firstScreen)")

            await connection.close()
            try await fixture.remove()
        } catch {
            try await fixture.remove()
            throw error
        }
    }

}
