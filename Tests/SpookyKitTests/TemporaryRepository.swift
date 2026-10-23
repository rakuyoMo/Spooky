import Foundation
import Subprocess

@testable import SpookyKit

/// 每个测试独占一个临时目录，并隔离系统与用户的 Git 配置。
struct TemporaryRepository: Sendable {
    /// 测试工作区根目录。
    let directory: URL

    /// 忽略用户配置的测试命令执行器。
    var runner: GitRunner { runner(at: directory.path) }

    /// 路径同时覆盖空格、中文、单双引号、反斜杠及通配符。
    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Spooky-\(UUID().uuidString)-仓 库'\"\\[*]?")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// 创建指定位置的隔离执行器，可用临时程序验证进程边界。
    func runner(at path: String, executable: String = "/usr/bin/git") -> GitRunner {
        GitRunner(
            location: .local(path: path),
            executablePath: executable,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_PARAMETERS": nil,
                "GIT_CONFIG_COUNT": nil,
                "GIT_ATTR_NOSYSTEM": "1",
            ])
        )
    }

    /// 创建具有固定初始分支与仓库本地提交身份的工作区。
    func initialize(objectFormat: String = "sha1") async throws {
        _ = try await runner.run([
            "-c", "init.templateDir=",
            "init", "-q", "-b", "main", "--object-format=\(objectFormat)",
        ])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await runner.run(["config", "--local", "commit.gpgSign", "false"])
    }

    /// 只删除本测试创建的临时目录。
    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
