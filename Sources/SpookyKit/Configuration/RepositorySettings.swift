import Foundation

// MARK: - RuleFile

/// 一份规则文件：仓库所在机器上的绝对路径，以及去掉空行与注释后的规则。
public struct RuleFile: Sendable, Equatable {
    /// 文件的绝对路径；文件不存在时同样给出将要创建的位置。
    public let path: String

    /// 文件是否存在。
    public let exists: Bool

    /// 文件里的规则，按文件中的顺序。
    public let patterns: [String]
}

// MARK: - RepositorySettings

/// 仓库设置页读取的内容：仓库本地配置里的 Issue 追踪、提交信息折行与签名，以及忽略、排除与 LFS 跟踪规则。
///
/// 配置值只取仓库本地配置（`--local`），没有写在本仓库的为 nil，表示沿用全局设置。
public struct RepositorySettings: Sendable, Equatable {
    /// 仓库本地配置里的键。
    public enum Key {
        /// Issue 追踪的地址模板。
        public static let issueTrackerTemplate = GlobalGitConfiguration.Key.issueTrackerTemplate

        /// Issue 编号前缀。
        public static let issueNumberPrefix = GlobalGitConfiguration.Key.issueNumberPrefix

        /// 提交信息正文每行的字数上限，覆盖 Editor 设置页的值。
        public static let bodyLineLimit = "spooky.commitbodylimit"

        /// 是否显示正文的参考线，覆盖 Editor 设置页的值。
        public static let showsBodyGuide = "spooky.commitshowsguide"

        /// 是否签名提交。
        public static let signsCommits = "commit.gpgsign"

        /// 签名密钥。
        public static let signingKey = "user.signingkey"

        /// SSH 签名校验用的 allowed signers 文件。
        public static let allowedSignersFile = "gpg.ssh.allowedsignersfile"

        /// 读取的键名正则；`--get-regexp` 匹配的是 Git 规范化后的小写键名。
        static let pattern = "^(spooky\\.(issuetrackertemplate|issuenumberprefix|commitbodylimit|commitshowsguide)"
            + "|commit\\.gpgsign|user\\.signingkey|gpg\\.ssh\\.allowedsignersfile)$"
    }

    /// 本仓库的 Issue 追踪地址模板。
    public var issueTrackerTemplate: String?

    /// 本仓库的 Issue 编号前缀。
    public var issueNumberPrefix: String?

    /// 本仓库的正文每行字数上限；不是正整数时视为没有设置。
    public var bodyLineLimit: Int?

    /// 本仓库是否显示正文参考线。
    public var showsBodyGuide: Bool?

    /// 本仓库是否签名提交。
    public var signsCommits: Bool?

    /// 本仓库的签名密钥。
    public var signingKey: String?

    /// 本仓库的 allowed signers 文件。
    public var allowedSignersFile: String?

    /// 仓库根目录的 `.gitignore`。
    public var ignore: RuleFile

    /// git 目录下的 `info/exclude`。
    public var exclude: RuleFile

    /// 仓库根目录 `.gitattributes` 里交给 Git LFS 的规则。
    public var lfs: RuleFile

    /// 解析 `config -z --local --get-regexp` 的输出。
    static func configuration(_ data: Data) throws -> [String: String?] {
        try ConfigRecords.parse(data, pattern: Key.pattern, context: "repository config")
    }

    /// 规则文件里的规则：去掉首尾空白，跳过空行与 `#` 开头的注释。
    static func patterns(in data: Data?) -> [String] {
        String(decoding: data ?? Data(), as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// `.gitattributes` 里设置了 `filter=lfs` 的规则，只取路径模式。
    static func lfsPatterns(in data: Data?) -> [String] {
        patterns(in: data).compactMap { line in
            let (pattern, attributes) = splitPattern(line)
            return attributes.split(whereSeparator: \.isWhitespace).contains("filter=lfs") ? pattern : nil
        }
    }

    /// 一行属性规则拆成路径模式与其余部分；以引号开头的模式到配对的引号为止，可以含空格，`\` 转义下一个字符。
    private static func splitPattern(_ line: String) -> (pattern: String, attributes: Substring) {
        guard line.hasPrefix("\"") else {
            let pattern = line.prefix { !$0.isWhitespace }
            return (String(pattern), line[pattern.endIndex...])
        }

        var pattern = ""
        var index = line.index(after: line.startIndex)

        while index < line.endIndex {
            let character = line[index]

            if character == "\\", line.index(after: index) < line.endIndex {
                index = line.index(after: index)
                pattern.append(line[index])
            } else if character == "\"" {
                return (pattern, line[line.index(after: index)...])
            } else {
                pattern.append(character)
            }

            index = line.index(after: index)
        }

        return (pattern, "")
    }
}

// MARK: - Reading and Writing

extension GitRunner {
    /// 读取仓库设置；配置与三份规则文件经同一条连接读取，文件不存在时规则为空。
    public func repositorySettings() async throws -> RepositorySettings {
        async let config = execute(
            ["config", "-z", "--local", "--get-regexp", RepositorySettings.Key.pattern],
            acceptedExitCodes: [0, 1]
        )
        async let located = run(["rev-parse", "--path-format=absolute", "--git-path", "info/exclude"])

        let exclude = String(decoding: try await located, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard exclude.hasPrefix("/"), !exclude.contains("\n") else {
            throw RepositoryReadError.malformedOutput("rev-parse")
        }

        let ignore = location.path + "/.gitignore"
        let attributes = location.path + "/.gitattributes"
        let files = try await RepositoryFiles(runner: self).read([ignore, exclude, attributes])
        let values = try RepositorySettings.configuration(await config.standardOutput)

        return RepositorySettings(
            issueTrackerTemplate: ConfigRecords.nonEmpty(values[RepositorySettings.Key.issueTrackerTemplate]),
            issueNumberPrefix: ConfigRecords.nonEmpty(values[RepositorySettings.Key.issueNumberPrefix]),
            bodyLineLimit: ConfigRecords.nonEmpty(values[RepositorySettings.Key.bodyLineLimit])
                .flatMap { Int($0) }
                .flatMap { $0 > 0 ? $0 : nil },
            showsBodyGuide: values[RepositorySettings.Key.showsBodyGuide].map(ConfigRecords.boolean),
            signsCommits: values[RepositorySettings.Key.signsCommits].map(ConfigRecords.boolean),
            signingKey: ConfigRecords.nonEmpty(values[RepositorySettings.Key.signingKey]),
            allowedSignersFile: ConfigRecords.nonEmpty(values[RepositorySettings.Key.allowedSignersFile]),
            ignore: RuleFile(
                path: ignore,
                exists: files[ignore] != nil,
                patterns: RepositorySettings.patterns(in: files[ignore])
            ),
            exclude: RuleFile(
                path: exclude,
                exists: files[exclude] != nil,
                patterns: RepositorySettings.patterns(in: files[exclude])
            ),
            lfs: RuleFile(
                path: attributes,
                exists: files[attributes] != nil,
                patterns: RepositorySettings.lfsPatterns(in: files[attributes])
            )
        )
    }

    /// 写入或删除仓库本地配置的一项；删除没有设置的键不算失败。
    ///
    /// - Parameters:
    ///   - key: 配置键。
    ///   - value: 新值；nil 表示删除，此后沿用全局设置。
    public func setLocalConfig(_ key: String, to value: String?) async throws {
        guard let value else {
            // 键不存在时 git config --unset 以 5 退出
            _ = try await execute(["config", "--local", "--unset", key], acceptedExitCodes: [0, 5])
            return
        }

        _ = try await execute(["config", "--local", key, value])
    }
}
