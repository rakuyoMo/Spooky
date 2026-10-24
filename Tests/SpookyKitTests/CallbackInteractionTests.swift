import Foundation
import Synchronization
import Testing

@testable import SpookyKit

/// 自动获取这类不是用户直接发起的操作，回调请求要标明不能询问用户，界面据此只用已存的凭据。
struct CallbackInteractionTests {
    /// 同一个凭据请求，在不允许询问的任务里发起时 `isInteractive` 为 false，平常为 true。
    @Test("回调请求标明能否询问用户", .timeLimit(.minutes(1)))
    func interactionFlag() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        // 临时 git 程序向 askpass 索取一次密码，把拿到的值写到 stdout
        let executable = fixture.directory.appendingPathComponent("git-askpass-test")
        let script = """
            #!/bin/sh
            value=$("$GIT_ASKPASS" 'Password for test:') || exit $?
            printf '%s' "$value"
            """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let requests = Mutex<[Bool]>([])
        var runner = fixture.runner(at: fixture.directory.path, executable: executable.path)

        runner.credentialHandler = { request in
            requests.withLock { $0.append(request.isInteractive) }
            return request.isInteractive ? "typed" : nil
        }

        // 交给 askpass 的值会从输出里脱敏，能拿到值说明命令照常完成
        let prompted = try await runner.execute(["fetch", "--porcelain"])
        #expect(prompted.exitCode == 0)

        // 不能询问用户时界面不给值，askpass 按取消处理，命令失败而不是等待输入
        let quiet = runner

        await #expect(throws: GitError.self) {
            try await RemoteCallbackRequest.$allowsInteraction.withValue(false) {
                _ = try await quiet.execute(["fetch", "--porcelain"])
            }
        }

        #expect(requests.withLock { $0 } == [true, false])
    }
}
