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

            return RemoteHealthCheck(result, marker: "marker")
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

    /// 在本机按 B 上的方式执行体检脚本：路径是第一个位置参数，分隔标记经标准输入交给脚本。
    ///
    /// - Parameters:
    ///   - last: 最后一个要执行的步骤。
    ///   - path: 要检查的仓库路径。
    /// - Returns: 切开的各步骤结果。
    private func run(through last: RemoteHealthCheck.Step, path: String) async throws -> RemoteHealthCheck {
        let marker = UUID().uuidString

        let result = try await CommandExecutor.execute(
            executable: "/bin/sh",
            processArguments: ["-c", RemoteHealthCheck.script(through: last), "spooky-check", path],
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ]),
            input: Data((marker + "\n").utf8)
        )

        return RemoteHealthCheck(result, marker: marker)
    }
}
