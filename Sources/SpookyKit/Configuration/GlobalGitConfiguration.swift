import Foundation

// MARK: - GlobalGitConfiguration

/// 本机全局 Git 配置里设置窗口读写的几项：提交人身份、提交签名与 Issue 追踪。
public struct GlobalGitConfiguration: Sendable, Equatable {
    /// 配置键，都是 Git 规范化后的小写写法。
    public enum Key {
        /// 提交人姓名。
        public static let userName = "user.name"

        /// 提交人邮箱。
        public static let userEmail = "user.email"

        /// 签名密钥。
        public static let signingKey = "user.signingkey"

        /// 签名格式。
        public static let signingFormat = "gpg.format"

        /// 每次提交都签名。
        public static let signsCommits = "commit.gpgsign"

        /// OpenPGP 签名程序。
        public static let gpgProgram = "gpg.program"

        /// SSH 签名程序。
        public static let sshProgram = "gpg.ssh.program"

        /// 校验 SSH 签名用的 allowed signers 文件。
        public static let allowedSignersFile = "gpg.ssh.allowedsignersfile"

        /// Issue 链接的地址模板。
        public static let issueTrackerTemplate = "spooky.issuetrackertemplate"

        /// 提交信息里 Issue 编号的前缀。
        public static let issueNumberPrefix = "spooky.issuenumberprefix"
    }

    /// 读取的键；`--get-regexp` 匹配的是 Git 规范化后的小写键名。
    static let pattern = "^(user\\.(name|email|signingkey)|commit\\.gpgsign|gpg\\.(format|program)"
        + "|gpg\\.ssh\\.(program|allowedsignersfile)|spooky\\.(issuetrackertemplate|issuenumberprefix))$"

    /// `user.name`；未配置时为 nil。
    public var userName: String?

    /// `user.email`；未配置时为 nil。
    public var userEmail: String?

    /// `user.signingkey`；未配置时为 nil。
    public var signingKey: String?

    /// `gpg.format`；未配置时为 nil，Git 按 OpenPGP 处理。
    public var signingFormat: SigningFormat?

    /// `commit.gpgsign`。
    public var signsCommits: Bool

    /// `gpg.program`；未配置时 Git 在 PATH 里找 gpg。
    public var gpgProgram: String?

    /// `gpg.ssh.program`；未配置时 Git 使用 ssh-keygen。
    public var sshProgram: String?

    /// `gpg.ssh.allowedSignersFile`。
    public var allowedSignersFile: String?

    /// Issue 链接的地址模板，`{ISSUE_NUMBER}` 处换成编号。
    public var issueTrackerTemplate: String?

    /// 提交信息里 Issue 编号的前缀，如 `#`。
    public var issueNumberPrefix: String?

    /// 创建配置快照；不传的项都是未配置。
    public init(
        userName: String? = nil,
        userEmail: String? = nil,
        signingKey: String? = nil,
        signingFormat: SigningFormat? = nil,
        signsCommits: Bool = false,
        gpgProgram: String? = nil,
        sshProgram: String? = nil,
        allowedSignersFile: String? = nil,
        issueTrackerTemplate: String? = nil,
        issueNumberPrefix: String? = nil
    ) {
        self.userName = userName
        self.userEmail = userEmail
        self.signingKey = signingKey
        self.signingFormat = signingFormat
        self.signsCommits = signsCommits
        self.gpgProgram = gpgProgram
        self.sshProgram = sshProgram
        self.allowedSignersFile = allowedSignersFile
        self.issueTrackerTemplate = issueTrackerTemplate
        self.issueNumberPrefix = issueNumberPrefix
    }

    /// 解析 `config -z --get-regexp` 的输出；同一键出现多次时与 Git 一样以最后一个为准。
    static func parse(_ data: Data) throws -> Self {
        let values = try ConfigRecords.parse(data, pattern: pattern, context: "global config")

        return Self(
            userName: ConfigRecords.nonEmpty(values[Key.userName]),
            userEmail: ConfigRecords.nonEmpty(values[Key.userEmail]),
            signingKey: ConfigRecords.nonEmpty(values[Key.signingKey]),
            signingFormat: values[Key.signingFormat].flatMap { $0 }.flatMap(SigningFormat.init(rawValue:)),
            signsCommits: values[Key.signsCommits].map(ConfigRecords.boolean) ?? false,
            gpgProgram: ConfigRecords.nonEmpty(values[Key.gpgProgram]),
            sshProgram: ConfigRecords.nonEmpty(values[Key.sshProgram]),
            allowedSignersFile: ConfigRecords.nonEmpty(values[Key.allowedSignersFile]),
            issueTrackerTemplate: ConfigRecords.nonEmpty(values[Key.issueTrackerTemplate]),
            issueNumberPrefix: ConfigRecords.nonEmpty(values[Key.issueNumberPrefix])
        )
    }
}

// MARK: - GlobalGitConfig

/// 读写本机用户的全局 Git 配置，影响本机所有仓库；服务器仓库使用服务器上的配置，不受影响。
public struct GlobalGitConfig: Sendable {
    /// 执行 git 的位置；`--global` 与所在目录无关，写入经这个位置的写队列串行。
    let runner: GitRunner

    /// 在用户主目录执行 git。
    public init() {
        runner = GitRunner(location: .local(path: NSHomeDirectory()))
    }

    /// 使用指定的执行器，测试以此隔离用户的配置。
    init(runner: GitRunner) {
        self.runner = runner
    }

    /// 全局配置文件的路径，与 Git 写入 `--global` 时的选择一致。
    ///
    /// `GIT_CONFIG_GLOBAL` 优先；否则 `~/.gitconfig` 存在或 XDG 的 `git/config` 不存在时是 `~/.gitconfig`，
    /// 只有 XDG 的文件存在时是它。
    ///
    /// - Parameters:
    ///   - environment: 进程环境。
    ///   - fileExists: 判断文件是否存在。
    public static func filePath(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> String {
        if let path = environment["GIT_CONFIG_GLOBAL"], !path.isEmpty {
            return path
        }

        let home = environment["HOME"].flatMap { $0.isEmpty ? nil : $0 } ?? NSHomeDirectory()
        let legacy = URL(fileURLWithPath: home).appending(path: ".gitconfig").path

        let xdgBase = environment["XDG_CONFIG_HOME"].flatMap { $0.isEmpty ? nil : $0 }
            ?? URL(fileURLWithPath: home).appending(path: ".config").path
        let xdg = URL(fileURLWithPath: xdgBase).appending(path: "git/config").path

        return !fileExists(legacy) && fileExists(xdg) ? xdg : legacy
    }

    /// 读取各项；配置文件不存在或这些键都没有时得到全部未配置的快照。
    ///
    /// `--includes` 让读取与 Git 实际生效的值一致，`[include]` 引入的文件也算在内。
    public func read() async throws -> GlobalGitConfiguration {
        let result = try await runner.execute(
            ["config", "--global", "--includes", "-z", "--get-regexp", GlobalGitConfiguration.pattern],
            acceptedExitCodes: [0, 1]
        )

        return try GlobalGitConfiguration.parse(result.standardOutput)
    }

    /// 依次写入一组键；值为 nil 时删除这个键的全部值，键本来就没有不算失败。
    ///
    /// 几项在同一个写锁中写入，值经独立参数传递，以短横线开头也不会被当作选项。
    ///
    /// - Parameter entries: 键与新值。
    public func set(_ entries: [(key: String, value: String?)]) async throws {
        try await runner.writeTransaction {
            for (key, value) in entries {
                if let value {
                    _ = try await runner.run(["config", "--global", "--replace-all", "--", key, value])
                } else {
                    _ = try await runner.execute(
                        ["config", "--global", "--unset-all", "--", key],
                        acceptedExitCodes: [0, 5]
                    )
                }
            }
        }
    }
}
