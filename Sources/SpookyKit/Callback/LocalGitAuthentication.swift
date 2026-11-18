import Foundation
import Subprocess

/// 本机网络操作与提交签名复用凭据中继；网络连接解锁的私钥由 OpenSSH 加入当前 SSH agent。
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
        let session = try LocalCallbackSession(host: location.displayPath, handler: handler)
        defer { session.close() }

        let relay = session.relay
        let operation = session.operation
        let gitAskpass = session.gitAskpass

        let overrides = session.sshOverrides.merging([
            "GIT_ASKPASS": gitAskpass, "GIT_SSH": nil, "GIT_SSH_COMMAND": nil, "SPOOKY_SIGNING": nil,
        ]) { $1 }

        // 账号实例与手动关联的 HTTPS 地址只问包装器的凭据入口，其余地址仍先问用户自己的凭据助手。
        let callbackOptions = GitCredentialScopes.options(callback: GitRunner.shellQuoted(session.wrapper.path)) + [
            "-c", "core.askPass=" + GitRunner.shellQuoted(gitAskpass),
            "-c",
            "core.sshCommand=/usr/bin/ssh -o BatchMode=no -o ForwardAgent=no -o StrictHostKeyChecking=yes -o AddKeysToAgent=yes",
            "-c", "gpg.ssh.program=" + session.sshKeygen,
        ]

        let redactor = RemoteOutputRedactor(
            values: { relay.sensitiveValues(for: operation) },
            output: onOutput
        )
        defer { redactor.finish() }

        do {
            let result = try await CommandExecutor.execute(
                executable: executable,
                processArguments: ["-C", location.path] + GitRunner.globalOptions + callbackOptions + arguments,
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
