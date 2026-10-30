import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryMountStateTests

/// 服务器目录的挂载查找结果按目录记下：查找期间是 “正在查找”，菜单项禁用且不提示；结束后要么是核对过的本机位置，要么是没有挂载。
///
/// 用指向 “服务器” 目录的符号链接模拟挂载卷，执行器直接在本机执行 Git。
@MainActor
struct RepositoryMountStateTests {
    /// 挂载着的仓库得到本机位置，另一个目录没有挂载；不要求重新查找时已有结果保持不变，关闭仓库后结果清空。
    @Test("按目录记下查找结果")
    func lookups() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-mount-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        // Git 写出的路径不带符号链接，临时目录同样解析成真实路径
        let resolved = try #require(realpath(directory.path, nil))
        defer { free(resolved) }

        let base = URL(filePath: String(cString: resolved))
        let repository = base.appending(path: "server/仓 库").path
        let missing = base.appending(path: "elsewhere/未挂载").path
        let mount = base.appending(path: "mount")

        try FileManager.default.createDirectory(atPath: repository, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: mount, withDestinationURL: base.appending(path: "server"))

        let runner = GitRunner(
            location: .local(path: repository),
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )
        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])

        let state = RepositoryMountState()
        state.makeLocator = { _ in RemoteMountLocator(volumes: { [mount] }) }

        state.locate([repository, missing], host: "spooky-test", runner: runner, refreshes: false)
        #expect(state.lookups[repository] == .searching)

        try await FileViewsTests.wait {
            state.lookups.values.allSatisfy { $0 != .searching }
        }

        guard case .found(let found) = state.lookups[repository] else {
            Issue.record("挂载着的仓库没有找到")
            return
        }

        #expect(found.localURL.path == mount.appending(path: "仓 库").path)
        #expect(state.lookups[missing] == .notMounted)

        // 只查还没有结果的目录，已有的结果不回到 “正在查找”
        state.locate([repository], host: "spooky-test", runner: runner, refreshes: false)
        #expect(state.lookups[repository] == .found(found))

        state.reset()
        #expect(state.lookups.isEmpty)
    }
}
