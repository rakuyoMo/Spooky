import Foundation

// MARK: - RepositoryTags

/// 标签的新建、删除与推送；新建的标签名按 `refs/tags/<名称>` 校验，推送与远端删除流出进度。
public struct RepositoryTags: Sendable {
    /// 本机与服务器使用相同参数协议。
    public let runner: GitRunner

    /// 创建标签服务，不执行隐式操作。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 新建标签：没有说明时是轻量标签，有说明时是附注标签，签名时说明不能为空。
    ///
    /// 说明经标准输入写入并只整理空白，以 “#” 开头的行原样保留；签名在仓库所在的机器上进行，私钥口令经回调询问。
    ///
    /// - Parameters:
    ///   - name: 标签短名。
    ///   - revision: 标签指向的版本，解析为一个提交。
    ///   - message: 标签说明；去掉首尾空白后为空表示轻量标签。
    ///   - sign: 是否签名。
    ///   - signingKey: 签名密钥，写法与 `user.signingkey` 相同；为 nil 时用仓库配置的密钥。
    public func create(
        name: String,
        revision: String,
        message: String,
        sign: Bool,
        signingKey: String? = nil
    ) async throws {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sign || !text.isEmpty else {
            throw RepositoryReadError.invalidQuery
        }

        try await runner.writeTransaction {
            let references = RepositoryReferences(runner: runner)
            try await references.validate(tag: name)
            let object = try await references.resolve(revision)

            guard sign || !text.isEmpty else {
                _ = try await runner.run(["tag", "--no-sign", "--", name, object])
                return
            }

            // 选定的密钥决定签名格式；不选时沿用仓库的 gpg.format
            let format = signingKey.map { ["-c", "gpg.format=" + SigningFormat(key: $0).rawValue] } ?? []
            let mode = sign ? ["-s"] + (signingKey.map { ["-u", $0] } ?? []) : ["-a", "--no-sign"]

            _ = try await runner.run(
                format + ["tag"] + mode + ["--cleanup=whitespace", "-F", "-", "--", name, object],
                input: Data((text + "\n").utf8)
            )
        }
    }

    /// 删除若干本地标签，一条命令完成；名称来自现有引用，经 `--` 传入，不再按新建规则校验。
    public func delete(_ names: [String]) async throws {
        guard !names.isEmpty, !names.contains(where: \.isEmpty) else {
            throw RepositoryReadError.invalidQuery
        }

        _ = try await runner.run(["tag", "-d", "--"] + names)
    }

    /// 在远端删除若干标签，一次推送完成。
    public func deleteRemote(
        _ names: [String],
        on remote: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        guard !names.isEmpty, !names.contains(where: \.isEmpty) else {
            throw RepositoryReadError.invalidQuery
        }

        try await push(names.map { ":refs/tags/" + $0 }, to: remote, onOutput: onOutput)
    }

    /// 把一个本地标签推送到远端的同名标签。
    public func publish(
        _ name: String,
        to remote: String,
        skipHooks: Bool = false,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        guard !name.isEmpty else {
            throw RepositoryReadError.invalidQuery
        }

        try await push(
            ["refs/tags/" + name + ":refs/tags/" + name],
            options: skipHooks ? ["--no-verify"] : [],
            to: remote,
            onOutput: onOutput
        )
    }

    /// 把全部本地标签推送到远端，不推送分支。
    public func pushAll(
        to remote: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await push([], options: ["--tags"], to: remote, onOutput: onOutput)
    }

    /// 标签推送共用的命令：先校验远端名，再以显式 refspec 推送。
    ///
    /// - Parameters:
    ///   - refspecs: 要推送的 refspec。
    ///   - options: 放在远端名之前的推送选项，如 `--tags`、`--no-verify`。
    private func push(
        _ refspecs: [String],
        options: [String] = [],
        to remote: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)?
    ) async throws {
        try await runner.writeTransaction {
            try await RepositoryReferences(runner: runner).validate(remote: remote)

            _ = try await runner.execute(
                RepositoryReferences.pushCommand(remote: remote) + options + ["--", remote] + refspecs,
                onOutput: onOutput
            )
        }
    }
}
