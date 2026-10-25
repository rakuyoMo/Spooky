import Foundation

// MARK: - LocalRepository

/// 已验证的本机工作区，使用 Git 返回的根路径作为窗口复用标识。
public struct LocalRepository: Sendable, Hashable {
    /// 工作区根目录的绝对路径。
    public let path: String

    /// 仓库目录名。
    public var name: String { URL(fileURLWithPath: path).lastPathComponent }

    /// 核心命令执行层使用的仓库位置。
    public var location: RepositoryLocation { .local(path: path) }
}

// MARK: - GitVersion

/// Git 版本的数值部分，兼容 Apple Git 的附加版本说明。
public struct GitVersion: Sendable, Equatable, Comparable {
    /// Spooky 1.0.0 所需的最低 Git 版本。
    public static let minimum = Self(major: 2, minor: 41, patch: 0)

    /// 主版本号。
    public let major: Int

    /// 次版本号。
    public let minor: Int

    /// 修订号。
    public let patch: Int

    /// 从 `git --version` 的结构化版本前缀解析数值，忽略厂商后缀。
    public init?(output: Data) {
        let text = String(decoding: output, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = /^git version ([0-9]+)\.([0-9]+)\.([0-9]+)(?:[ .-]|$)/

        guard
            let match = text.firstMatch(of: pattern),
            let major = Int(match.1),
            let minor = Int(match.2),
            let patch = Int(match.3)
        else {
            return nil
        }

        self.init(major: major, minor: minor, patch: patch)
    }

    /// 用已验证的数值创建版本。
    private init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// 按数值比较版本，避免把 2.9 当作高于 2.41。
    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

}

// MARK: - RepositoryOpenError

/// 打开工作区时的前置校验错误，命令失败本身使用 GitError。
public enum RepositoryOpenError: Error, Sendable {
    /// 本机工作区必须由绝对路径标识。
    case requiresLocalAbsolutePath

    /// 所选的本机 Git 程序不存在或不可执行。
    case gitUnavailable(path: String)

    /// Git 的版本输出无法解析。
    case invalidGitVersion(GitCommandResult)

    /// 当前 Git 低于产品最低版本，保留版本命令的原始输出。
    case unsupportedGitVersion(GitCommandResult)

    /// Git 没有返回合法的工作区根目录。
    case invalidWorktreeResponse(GitCommandResult)
}

extension GitRunner {
    /// 先校验所选 Git 程序的版本，再识别工作区；子目录和符号链接统一到同一根目录。
    public func openLocalRepository() async throws -> LocalRepository {
        let version = try await versionResult()

        guard let parsed = GitVersion(output: version.standardOutput) else {
            throw RepositoryOpenError.invalidGitVersion(version)
        }

        guard parsed >= .minimum else {
            throw RepositoryOpenError.unsupportedGitVersion(version)
        }

        guard case .local(let path) = location, path.hasPrefix("/") else {
            throw RepositoryOpenError.requiresLocalAbsolutePath
        }

        // Git 负责识别 .git 文件、分离的 gitdir 和工作树；不靠目录名猜测仓库身份。
        let result = try await execute([
            "rev-parse",
            "--is-inside-work-tree",
            "--show-toplevel",
        ])

        guard
            let response = String(data: result.standardOutput, encoding: .utf8),
            response.hasPrefix("true\n/"),
            response.hasSuffix("\n")
        else {
            throw RepositoryOpenError.invalidWorktreeResponse(result)
        }

        // 只移除协议头和最后一个换行，路径自身的空格、引号和换行必须保留。
        let root = String(response.dropFirst(5).dropLast())
        return LocalRepository(path: root)
    }

    /// 在本机位置新建空仓库，再按打开仓库的规则识别它；目录不存在时连同上级目录一起建出来。
    ///
    /// 初始分支名由 Git 的 `init.defaultBranch` 决定；位置已是仓库时 Git 只重新初始化，不改动已有内容。
    public func initializeRepository() async throws -> LocalRepository {
        guard case .local(let path) = location, path.hasPrefix("/") else {
            throw RepositoryOpenError.requiresLocalAbsolutePath
        }

        // 位置是已有的文件时这里抛出文件系统错误，不会执行 git init。
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)

        _ = try await run(["init", "--quiet"])
        return try await openLocalRepository()
    }
}
