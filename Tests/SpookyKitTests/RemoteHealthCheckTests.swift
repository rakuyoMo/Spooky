import Foundation
import Subprocess
import Testing

@testable import SpookyKit

/// 体检脚本在一次往返里执行全部步骤，A 按随机的分隔标记切回每步自己的输出与退出码。
struct RemoteHealthCheckTests {
    /// 步骤的输出含 NUL、换行与分隔帧用到的控制字符时照样切开；第一个失败的检查之后不再执行。
    @Test("体检脚本按步骤切开输出，遇到失败即停")
    func framedSteps() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        // 文件名带换行与分隔帧的控制字符，状态输出用 -z 分隔，含 NUL
        let names = ["line\nbreak", "\u{1E}frame\u{1F}", "tab\there"]

        for name in names {
            try Data().write(to: repository.directory.appending(path: name))
        }

        let checks = try await run(through: .root, path: repository.directory.path)
        #expect(try checks.result(.environment, argument: "environment").exitCode == 0)

        let version = try checks.require(.gitVersion, kind: .gitUnavailable)
        #expect(version.standardOutput.starts(with: Data("git version ".utf8)))

        let status = try checks.require(.status, kind: .statusFormat)
        let paths = try WorkingCopyStatus(porcelainV2: status.standardOutput).entries.map(\.path)
        #expect(Set(paths) == Set(names))

        let root = try checks.require(.root, kind: .notWorkingTree)
        let rootPath = String(decoding: root.standardOutput, as: UTF8.self)
        #expect(rootPath.hasSuffix("/" + repository.directory.lastPathComponent + "\n"))

        // 路径不存在：这一步带着自己的退出码与错误输出失败，后面的检查没有执行
        let missing = try await run(through: .root, path: repository.directory.path + "/missing")
        let error = #expect(throws: RemoteConnectionError.self) {
            try missing.require(.directory, kind: .pathUnavailable)
        }
        #expect(error?.kind == .pathUnavailable)
        #expect(error?.result?.exitCode == 2)
        #expect(error?.result?.standardError == Data("Directory does not exist\n".utf8))

        let skipped = #expect(throws: RemoteConnectionError.self) {
            try missing.require(.permission, kind: .pathPermission)
        }
        #expect(skipped?.kind == .protocolFailure)
    }

    /// 通道在某一步写完分隔帧之前结束时，这一步按通道的结束状态处理，前面写完的步骤不受影响。
    @Test("没写完的步骤按通道的结束状态处理")
    func unfinishedStep() throws {
        // 第一步两路都写完了分隔帧；第二步只在标准输出写了帧，标准错误的帧没写完通道就结束了
        let frame = Data([0x1E]) + Data("marker:0".utf8) + Data([0x1F])

        func checks(exitingWith code: Int32) -> RemoteHealthCheck {
            let result = GitCommandResult(
                arguments: ["health-check"],
                standardOutput: Data("home".utf8) + frame + Data("/usr/bin/git\n".utf8) + frame,
                standardError: frame + Data("broken".utf8),
                terminationStatus: .exited(code),
                isCancelled: false
            )

            return RemoteHealthCheck(result, marker: "marker", steps: RemoteHealthCheck.Step.allCases)
        }

        let environment = try checks(exitingWith: 1).result(.environment, argument: "environment")
        #expect(environment.standardOutput == Data("home".utf8))
        #expect(environment.exitCode == 0)

        // 脚本异常结束：剩下的输出连同通道的退出码算作这一步的结果
        let rest = try checks(exitingWith: 1).result(.gitPath, argument: "gitUnavailable")
        #expect(rest.exitCode == 1)
        #expect(rest.standardOutput == Data("/usr/bin/git\n".utf8) + frame)
        #expect(rest.standardError == Data("broken".utf8))

        // SSH 的 255 按连接诊断识别
        let disconnected = #expect(throws: RemoteConnectionError.self) {
            try checks(exitingWith: 255).require(.gitPath, kind: .gitUnavailable)
        }
        #expect(disconnected?.kind == .unavailable)

        // 通道正常结束却缺了这一步，说明输出不完整
        let truncated = #expect(throws: RemoteConnectionError.self) {
            try checks(exitingWith: 0).require(.gitPath, kind: .gitUnavailable)
        }
        #expect(truncated?.kind == .protocolFailure)
    }

    /// 找到 Git 那一步输出之后各步执行的 Git：PATH 里找到的是 /usr/bin/git 时换成开发者目录里的 Git，其余照原样；
    /// 输出的绝对路径只给只读命令用，写入命令照旧执行 `git`。
    @Test("体检找到的 Git 只给只读命令用")
    func gitExecutable() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-git-" + UUID().uuidString)
        let fake = directory.appending(path: "git")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // 假的 Git 只回答版本
        try Data("#!/bin/sh\necho 'git version 2.99.0'\n".utf8).write(to: fake)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)

        // 不是 /usr/bin/git 时照原样输出，读版本执行的就是它
        let found = try await run(
            through: .gitVersion,
            path: directory.path,
            searchPath: directory.path + ":/usr/bin:/bin"
        )
        let output = try found.require(.gitPath, kind: .gitUnavailable).standardOutput
        let version = try found.require(.gitVersion, kind: .gitUnavailable).standardOutput
        let executable = RemoteHealthCheck.gitExecutable(in: output)

        #expect(output == Data((fake.path + "\n").utf8))
        #expect(executable == fake.path)
        #expect(version == Data("git version 2.99.0\n".utf8))

        // 只读命令执行找到的 Git，写入命令与没有找到绝对路径时执行 git
        let status = ["-c", "core.quotePath=false", "status", "-z"]

        #expect(RemoteConnection.gitCommand(for: status, executable: executable) == fake.path)
        #expect(RemoteConnection.gitCommand(for: ["commit", "-F", "-"], executable: executable) == "git")
        #expect(RemoteConnection.gitCommand(for: status, executable: nil) == "git")

        // /usr/bin/git 换成 xcode-select 指向的开发者目录里的 Git；开发者目录里没有 Git 时照原样
        let tools = try await CommandExecutor.execute(
            executable: "/usr/bin/xcode-select",
            processArguments: ["-p"],
            acceptedExitCodes: Set(0 ... 255)
        )
        let developerGit = String(decoding: tools.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .newlines) + "/usr/bin/git"
        let expected = FileManager.default.isExecutableFile(atPath: developerGit) ? developerGit : "/usr/bin/git"

        let shim = try await run(through: .gitPath, path: directory.path, searchPath: "/usr/bin:/bin")
        #expect(try shim.require(.gitPath, kind: .gitUnavailable).standardOutput == Data((expected + "\n").utf8))

        // 找不到 Git 时这一步失败，没有输出
        let missing = try await run(through: .gitVersion, path: directory.path, searchPath: "/bin")
        let error = #expect(throws: RemoteConnectionError.self) {
            try missing.require(.gitPath, kind: .gitUnavailable)
        }

        #expect(error?.kind == .gitUnavailable)
        #expect(error?.result?.standardOutput.isEmpty ?? false)

        // 输出不是一行绝对路径时不用它
        #expect(RemoteHealthCheck.gitExecutable(in: Data("git\n".utf8)) == nil)
        #expect(RemoteHealthCheck.gitExecutable(in: Data("/usr/bin/git".utf8)) == nil)
        #expect(RemoteHealthCheck.gitExecutable(in: Data("/a/git\n/b/git\n".utf8)) == nil)
    }

    /// 新建会话的报文：一行 JSON，带着随机的令牌。
    func sessionRequest() -> Data {
        let token = (0 ..< 32).map { _ in String(format: "%02x", UInt8.random(in: 0 ... 255)) }.joined()
        return Data(#"{"token":"\#(token)"}"#.utf8) + Data([10])
    }

    /// 在本机按 B 上的方式执行体检脚本到 `last` 为止，不含新建会话：路径是第一个位置参数，分隔标记经标准输入交给脚本。
    ///
    /// - Parameters:
    ///   - last: 最后一个要执行的步骤。
    ///   - path: 要检查的仓库路径。
    ///   - searchPath: 脚本的 PATH；为 nil 时沿用测试进程的。
    /// - Returns: 切开的各步骤结果。
    private func run(
        through last: RemoteHealthCheck.Step,
        path: String,
        searchPath: String? = nil
    ) async throws -> RemoteHealthCheck {
        let marker = UUID().uuidString
        let steps = Array(RemoteHealthCheck.Step.allCases.prefix { $0 != last }) + [last]

        var environment: [Environment.Key: String?] = [
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_SYSTEM": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
        ]

        if let searchPath {
            environment["PATH"] = searchPath
        }

        let result = try await CommandExecutor.execute(
            executable: "/bin/sh",
            processArguments: ["-c", RemoteHealthCheck.script(steps, entersChannel: false), "spooky-check", path],
            environment: .inherit.updating(environment),
            input: Data((marker + "\n").utf8) + sessionRequest()
        )

        return RemoteHealthCheck(result, marker: marker, steps: steps)
    }
}
