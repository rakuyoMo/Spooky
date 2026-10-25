import Foundation

// MARK: - RepositorySummary

/// 仓库管理详情区显示的仓库概况：当前分支、最后一次提交、提交人、描述与远端。
public struct RepositorySummary: Sendable, Equatable {
    /// 一个提交人：姓名与邮箱。
    public struct Identity: Sendable, Equatable {
        /// 姓名。
        public let name: String

        /// 邮箱。
        public let email: String
    }

    /// HEAD 指向的提交的标题与提交时间。
    public struct Commit: Sendable, Equatable {
        /// 提交标题。
        public let subject: String

        /// 提交时间。
        public let date: Date
    }

    /// 当前分支的短名；分离 HEAD 时为 nil。未出生的分支同样有名字。
    public let branch: String?

    /// HEAD 指向的提交；仓库还没有提交时为 nil。
    public let lastCommit: Commit?

    /// Git 提交时实际使用的提交人；身份无法确定时为 nil。
    public let committer: Identity?

    /// 仓库本地配置里是否写了 `user.name` 或 `user.email`。
    public let hasRepositoryIdentity: Bool

    /// `description` 文件的内容；文件不存在时为 nil。
    public let description: String?

    /// 仓库的远端，按远端名排序。
    public let remotes: [RemoteConfiguration]
}

// MARK: - Reading

extension GitRunner {
    /// 读取仓库概况；几项互不依赖的读取同时进行，服务器仓库都经同一条主连接。
    public func repositorySummary() async throws -> RepositorySummary {
        async let branch = execute(["branch", "--show-current"])

        // 未出生的分支上 HEAD 无法解析，--ignore-missing 让 log 输出为空而不是失败。
        async let commit = execute(["log", "-1", "-z", "--format=%s%x00%ct", "--ignore-missing", "HEAD", "--"])

        // 身份无法确定时 git var 以 128 退出，界面显示为未设置。
        async let committer = execute(["var", "GIT_COMMITTER_IDENT"], acceptedExitCodes: [0, 128])
        async let local = execute(
            ["config", "-z", "--local", "--get-regexp", "^user\\.(name|email)$"],
            acceptedExitCodes: [0, 1]
        )
        async let description = repositoryDescription()
        async let remotes = RepositoryRemotes(runner: self).configurations()

        let name = String(decoding: try await branch.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .newlines)
        let ident = try await committer

        return RepositorySummary(
            branch: name.isEmpty ? nil : name,
            lastCommit: try RepositorySummary.commit(from: await commit.standardOutput),
            committer: ident.exitCode == 0 ? RepositorySummary.identity(from: ident.standardOutput) : nil,
            hasRepositoryIdentity: try await !local.standardOutput.isEmpty,
            description: try await description,
            remotes: try await remotes
        )
    }

    /// 读取 `description` 文件；不存在时为 nil。服务器仓库经 SFTP 读取。
    public func repositoryDescription() async throws -> String? {
        let path = try await descriptionPath()
        let contents = try await RepositoryFiles(runner: self).read([path])
        return contents[path].map { String(decoding: $0, as: UTF8.self) }
    }

    /// 改写 `description` 文件的内容；文件不存在时新建。服务器仓库经 SFTP 写入。
    public func setRepositoryDescription(_ text: String) async throws {
        let path = try await descriptionPath()
        try await RepositoryFiles(runner: self).write(Data(text.utf8), to: path)
    }

    /// `description` 文件的绝对路径，由 Git 按仓库布局给出，工作树与分离的 gitdir 都适用。
    private func descriptionPath() async throws -> String {
        let output = try await run(["rev-parse", "--path-format=absolute", "--git-path", "description"])
        let path = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard path.hasPrefix("/") else {
            throw RepositoryReadError.malformedOutput("description path")
        }

        return path
    }
}

// MARK: - Parsing

extension RepositorySummary {
    /// 解析 `log -1 -z --format=%s%x00%ct`：标题与 Unix 时间各占一段；没有输出表示还没有提交。
    static func commit(from data: Data) throws -> Commit? {
        guard !data.isEmpty else {
            return nil
        }

        let fields = data.split(separator: 0, omittingEmptySubsequences: false)

        guard
            fields.count >= 2,
            let seconds = TimeInterval(String(decoding: fields[1], as: UTF8.self))
        else {
            throw RepositoryReadError.malformedOutput("last commit")
        }

        return Commit(
            subject: String(decoding: fields[0], as: UTF8.self),
            date: Date(timeIntervalSince1970: seconds)
        )
    }

    /// 解析 `git var GIT_COMMITTER_IDENT` 的 “姓名 <邮箱> 时间 时区”；姓名里可以有尖括号以外的任何字符。
    static func identity(from data: Data) -> Identity? {
        let text = String(decoding: data, as: UTF8.self)

        guard
            let close = text.lastIndex(of: ">"),
            let open = text[..<close].lastIndex(of: "<")
        else {
            return nil
        }

        let name = text[..<open].trimmingCharacters(in: .whitespaces)
        let email = String(text[text.index(after: open) ..< close])
        return Identity(name: name, email: email)
    }
}
