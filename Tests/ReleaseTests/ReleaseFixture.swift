import Foundation
import Subprocess
import System

// MARK: - CommandResult

/// 一次命令的退出码、标准输出与标准错误。
struct CommandResult {
    /// 退出码；被信号结束时为 -1。
    let status: Int32

    /// 标准输出。
    let output: String

    /// 标准错误。
    let error: String
}

// MARK: - ReleaseFixture

/// 发布脚本的测试仓库：临时目录里的工作区，以及作为 origin 的裸仓库。
///
/// 工作区里放着仓库的发布脚本与一份 Info.plist，脚本按自身位置把工作区当作仓库根目录；
/// Git 忽略系统与用户的配置，提交身份只写进工作区的本地配置。
struct ReleaseFixture {
    /// 包所在的仓库根目录。
    static let package = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// 测试夹具目录。
    static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "Fixtures")

    /// 本次测试独占的临时目录。
    let root: URL

    /// 工作区。
    var workTree: URL { root.appending(path: "work") }

    /// 作为 origin 的裸仓库。
    var origin: URL { root.appending(path: "origin.git") }

    /// 建好工作区与 origin：Info.plist 写入给定的版本号与构建号，连同发布脚本提交到 main 并推送。
    init(version: String = "1.1.0", build: String = "7") async throws {
        root = FileManager.default.temporaryDirectory.appending(path: "spooky-release-\(UUID().uuidString)")

        let scripts = workTree.appending(path: "scripts")
        try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)

        // 1. 裸仓库与工作区，初始分支都是 main
        try await expectSuccess("/usr/bin/git", ["init", "-q", "--bare", "-b", "main", origin.path], in: root)
        try await git("init", "-q", "-b", "main")
        try await git("config", "user.name", "Spooky Test")
        try await git("config", "user.email", "spooky@example.invalid")
        try await git("config", "commit.gpgSign", "false")
        try await git("remote", "add", "origin", origin.path)

        // 2. 发布脚本与 Info.plist
        for script in ["check-release.sh", "release.sh"] {
            try FileManager.default.copyItem(
                at: Self.package.appending(path: "scripts/\(script)"),
                to: scripts.appending(path: script)
            )
        }

        try writeInfoPlist(version: version, build: build)

        // 3. 提交并推送，origin/main 与本地 main 一致
        try await git("add", "--all")
        try await git("commit", "-q", "-m", "初始提交")
        try await git("push", "-q", "origin", "main")
    }

    /// 在给定目录运行一个程序：Git 不读系统与用户的配置，额外的环境变量覆盖继承的值。
    static func run(
        _ executable: String,
        _ arguments: [String],
        in directory: URL,
        environment: [String: String] = [:]
    ) async throws -> CommandResult {
        var overrides: [Environment.Key: String?] = [
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_SYSTEM": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_PARAMETERS": nil,
            "GIT_CONFIG_COUNT": nil,
        ]

        for (key, value) in environment {
            overrides[Environment.Key(stringLiteral: key)] = value
        }

        let result = try await Subprocess.run(
            .path(FilePath(executable)),
            arguments: Arguments(arguments),
            environment: .inherit.updating(overrides),
            workingDirectory: FilePath(directory.path),
            output: .string(limit: 1 << 20),
            error: .string(limit: 1 << 20)
        )

        let status: Int32 =
            switch result.terminationStatus {
            case .exited(let code): code
            case .signaled: -1
            }

        return CommandResult(
            status: status,
            output: result.standardOutput,
            error: result.standardError
        )
    }

    /// 删除本测试创建的临时目录。
    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    /// 把夹具里的更新说明拷到 `docs/release-notes/<版本号>/`。
    func copyReleaseNotes(version: String) throws {
        let directory = notesDirectory(version: version)
        try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Self.fixtures.appending(path: "release-notes"), to: directory)
    }

    /// 某个版本的更新说明目录。
    func notesDirectory(version: String) -> URL {
        workTree.appending(path: "docs/release-notes/\(version)")
    }

    /// 改写工作区里的 Info.plist。
    func writeInfoPlist(version: String, build: String) throws {
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.rakuyo.spooky",
            "CFBundleShortVersionString": version,
            "CFBundleVersion": build,
        ]

        let directory = workTree.appending(path: "Sources/Spooky")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: directory.appending(path: "Info.plist"))
    }

    /// 读出工作区里 Info.plist 的一个键。
    func infoPlistValue(_ key: String) throws -> String? {
        let data = try Data(contentsOf: workTree.appending(path: "Sources/Spooky/Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        return plist?[key] as? String
    }

    /// 在工作区运行一个发布脚本。
    func script(_ name: String, _ arguments: String..., environment: [String: String] = [:]) async throws -> CommandResult {
        try await Self.run(
            workTree.appending(path: "scripts/\(name)").path,
            arguments,
            in: workTree,
            environment: environment
        )
    }

    /// 在工作区运行 Git，失败时抛出带标准错误的错误。
    @discardableResult
    func git(_ arguments: String...) async throws -> String {
        try await expectSuccess("/usr/bin/git", arguments, in: workTree)
    }

    /// 运行一条必须成功的命令，返回标准输出。
    @discardableResult
    func expectSuccess(_ executable: String, _ arguments: [String], in directory: URL) async throws -> String {
        let result = try await Self.run(executable, arguments, in: directory)

        guard result.status == 0 else {
            throw FixtureError(message: "\(arguments.joined(separator: " ")) 失败：\(result.error)")
        }

        return result.output
    }
}

// MARK: - FixtureError

/// 准备测试仓库时的命令失败。
struct FixtureError: Error, CustomStringConvertible {
    /// 失败的命令与它的标准错误。
    let message: String

    /// 测试失败时显示的说明。
    var description: String { message }
}
