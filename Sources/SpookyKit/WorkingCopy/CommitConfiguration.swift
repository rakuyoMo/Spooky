import Foundation

// MARK: - SigningFormat

/// 提交签名的格式，对应 Git 的 `gpg.format`。
public enum SigningFormat: String, Sendable, CaseIterable {
    /// gpg 签名，Git 的默认格式。
    case openpgp

    /// gpgsm 的 X.509 证书签名。
    case x509

    /// ssh-keygen 签名。
    case ssh

    /// 按密钥写法推断格式：SSH 公钥路径或字面公钥使用 SSH，其余视为 OpenPGP 密钥标识。
    ///
    /// - Parameter key: `user.signingkey` 的值。
    public init(key: String) {
        let literal = ["key::", "ssh-", "sk-ssh-", "ecdsa-sha2-", "sk-ecdsa-sha2-"]
            .contains { key.hasPrefix($0) }

        self = literal || key.contains("/") || key.hasPrefix("~") || key.hasSuffix(".pub") ? .ssh : .openpgp
    }
}

// MARK: - CommitConfiguration

/// 提交区需要的生效配置：身份、签名、注释字符与提交钩子，都取自仓库所在机器。
public struct CommitConfiguration: Sendable, Equatable {
    /// 读取的配置键；`--get-regexp` 匹配的是 Git 规范化后的小写键名。
    static let pattern =
        "^(user\\.(name|email|signingkey)|commit\\.gpgsign|gpg\\.format|core\\.(commentchar|commentstring))$"

    /// `--no-verify` 跳过的两个钩子。
    static let hooks = ["pre-commit", "commit-msg"]

    /// 生效的 `user.name`；未配置时为 nil。
    public let userName: String?

    /// 生效的 `user.email`；未配置时为 nil。
    public let userEmail: String?

    /// 生效的 `user.signingkey`；为 nil 时 OpenPGP 按提交人身份选择密钥。
    public let signingKey: String?

    /// 生效的签名格式。
    public let signingFormat: SigningFormat

    /// `commit.gpgsign` 打开时每次提交都签名。
    public let signsCommits: Bool

    /// 注释行的前缀；`auto` 时 Git 会选用信息里没有出现过的字符，因此用户输入不含注释行，记为 nil。
    public let commentPrefix: String?

    /// 仓库启用了 pre-commit 或 commit-msg 钩子时才提供跳过钩子的选项。
    public let hasCommitHooks: Bool

    /// 创建配置快照。
    public init(
        userName: String? = nil,
        userEmail: String? = nil,
        signingKey: String? = nil,
        signingFormat: SigningFormat = .openpgp,
        signsCommits: Bool = false,
        commentPrefix: String? = "#",
        hasCommitHooks: Bool = false
    ) {
        self.userName = userName
        self.userEmail = userEmail
        self.signingKey = signingKey
        self.signingFormat = signingFormat
        self.signsCommits = signsCommits
        self.commentPrefix = commentPrefix
        self.hasCommitHooks = hasCommitHooks
    }

    /// 解析 `config -z --get-regexp` 的输出；同一键出现多次时与 Git 一样以最后一个为准。
    static func parse(_ data: Data, hasCommitHooks: Bool) throws -> Self {
        let values = try ConfigRecords.parse(data, pattern: pattern, context: "commit config")

        // commentString 与 commentChar 互为别名，后读到的生效；Git 的读取顺序就是输出顺序。
        let comment = Self.lastComment(in: data) ?? "#"
        let format = values["gpg.format"].flatMap { $0 }.flatMap(SigningFormat.init(rawValue:))

        return Self(
            userName: ConfigRecords.nonEmpty(values["user.name"]),
            userEmail: ConfigRecords.nonEmpty(values["user.email"]),
            signingKey: ConfigRecords.nonEmpty(values["user.signingkey"]),
            signingFormat: format ?? .openpgp,
            signsCommits: values["commit.gpgsign"].map(ConfigRecords.boolean) ?? false,
            commentPrefix: comment.lowercased() == "auto" || comment.isEmpty ? nil : comment,
            hasCommitHooks: hasCommitHooks
        )
    }
}

// MARK: - Reading

extension WorkingCopyOperations {
    /// 读取提交配置与钩子；钩子路径经 `rev-parse --git-path` 解析，已包含 `core.hooksPath`。
    public func commitConfiguration() async throws -> CommitConfiguration {
        async let config = runner.execute(
            ["config", "-z", "--get-regexp", CommitConfiguration.pattern],
            acceptedExitCodes: [0, 1]
        )
        async let located = runner.run(
            ["rev-parse", "--path-format=absolute"]
                + CommitConfiguration.hooks.flatMap { ["--git-path", "hooks/" + $0] }
        )

        let paths = String(decoding: try await located, as: UTF8.self)
            .split(separator: "\n")
            .map(String.init)

        guard paths.count == CommitConfiguration.hooks.count else {
            throw RepositoryReadError.malformedOutput("hook paths")
        }

        // 服务器的钩子在 B 上检查存在性；本机还要求可执行，Git 会忽略不可执行的钩子。
        let present: [Bool] =
            if let remote = runner.remote {
                try await remote.inspect(paths)
            } else {
                paths.map { FileManager.default.isExecutableFile(atPath: $0) }
            }

        return try CommitConfiguration.parse(
            await config.standardOutput,
            hasCommitHooks: present.contains(true)
        )
    }

    /// 选用身份档案：改写当前仓库本地配置的提交人身份，档案带签名密钥时同时写入密钥与对应的签名格式。
    ///
    /// - Parameters:
    ///   - name: 写入 `user.name` 的姓名。
    ///   - email: 写入 `user.email` 的邮箱。
    ///   - signingKey: 写入 `user.signingkey` 的密钥；为 nil 时不改动签名配置。
    public func applyIdentity(name: String, email: String, signingKey: String?) async throws {
        let signing = signingKey.map {
            [("user.signingkey", $0), ("gpg.format", SigningFormat(key: $0).rawValue)]
        }
        let entries = [("user.name", name), ("user.email", email)] + (signing ?? [])

        // 几项配置在同一仓库写锁中依次写入，值经独立参数传递，以短横线开头也不会被当作选项。
        try await runner.writeTransaction {
            for (key, value) in entries {
                _ = try await runner.run(["config", "--local", "--replace-all", "--", key, value])
            }
        }
    }
}

// MARK: - Private

extension CommitConfiguration {
    /// 注释前缀的两个别名中最后出现的那个值。
    private static func lastComment(in data: Data) -> String? {
        data.split(separator: 0)
            .map { String(decoding: $0, as: UTF8.self) }
            .last { $0.hasPrefix("core.commentchar\n") || $0.hasPrefix("core.commentstring\n") }
            .map { String($0.drop { $0 != "\n" }.dropFirst()) }
    }
}
