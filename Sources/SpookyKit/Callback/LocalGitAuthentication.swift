import Foundation
import Subprocess

/// 本机网络操作复用凭据中继，私钥解锁后由 OpenSSH 加入当前 SSH agent。
enum LocalGitAuthentication {
    /// 私有临时会话仅存随机令牌；口令通过 socket 返回，不写文件、参数或日志。
    static func execute(
        executable: String,
        location: RepositoryLocation,
        arguments: [String],
        environment: Environment,
        input: Data? = nil,
        acceptedExitCodes: Set<Int32> = [0],
        handler: @escaping RemoteCallbackHandler,
        onOutput: @escaping @Sendable (GitOutputEvent) -> Void
    ) async throws -> GitCommandResult {
        let directory = URL(fileURLWithPath: "/tmp/spooky-local-" + UUID().uuidString.lowercased())
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let relay = try CallbackRelay(
            path: directory.appendingPathComponent("relay.sock").path,
            host: location.displayPath,
            handler: handler
        )
        try relay.start()
        defer { relay.stop() }
        let operation = UUID().uuidString.lowercased()
        relay.register(operation)
        defer { relay.unregister(operation) }

        // 与远端使用相同的一次性协议，脚本内容来自项目自身资源。
        guard let source = Bundle.module.url(forResource: "spooky-remote", withExtension: "pl") else {
            throw RemoteConnectionError(.deployment)
        }
        let wrapper = directory.appendingPathComponent("callback")
        try FileManager.default.copyItem(at: source, to: wrapper)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: wrapper.path)
        let askpass = wrapper.path + "-askpass"
        let gitAskpass = wrapper.path + "-git-askpass"
        try FileManager.default.createSymbolicLink(atPath: askpass, withDestinationPath: wrapper.path)
        try FileManager.default.createSymbolicLink(atPath: gitAskpass, withDestinationPath: wrapper.path)
        let info = try JSONSerialization.data(withJSONObject: ["token": relay.token])
        try info.write(to: directory.appendingPathComponent("session.json"))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: directory.appendingPathComponent("session.json").path
        )
        let overrides: [Environment.Key: String?] = [
            "SPOOKY_SESSION": directory.path, "SPOOKY_OPERATION": operation,
            "GIT_ASKPASS": gitAskpass, "SSH_ASKPASS": askpass, "SSH_ASKPASS_REQUIRE": "force",
            "DISPLAY": "spooky:0", "GIT_SSH": nil, "GIT_SSH_COMMAND": nil,
        ]
        let redactor = RemoteOutputRedactor(
            values: { relay.sensitiveValues(for: operation) },
            output: onOutput
        )
        defer { redactor.finish() }

        do {
            let result = try await CommandExecutor.execute(
                executable: executable,
                processArguments: ["-C", location.path] + GitRunner.globalOptions + [
                    "-c", "core.askPass=" + GitRunner.shellQuoted(gitAskpass),
                    "-c",
                    "core.sshCommand=/usr/bin/ssh -o BatchMode=no -o ForwardAgent=no -o StrictHostKeyChecking=yes -o AddKeysToAgent=yes",
                ] + arguments,
                arguments: arguments,
                environment: environment.updating(overrides),
                input: input,
                acceptedExitCodes: acceptedExitCodes,
                onOutput: { redactor.receive($0) }
            )
            return redactor.result(result)
        } catch let error as GitError {
            throw GitError(
                result: redactor.result(error.result),
                category: error.category,
                diagnostic: error.diagnostic
            )
        }
    }
}
