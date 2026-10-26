import Foundation

// MARK: - LFSStatus

/// 仓库所在机器上 Git LFS 的情况。
public struct LFSStatus: Sendable, Equatable {
    /// `git lfs version` 输出的第一行，如 `git-lfs/3.4.0 (GitHub; darwin arm64; go 1.21)`；找不到 Git LFS 时为 nil。
    public let version: String?

    /// 生效的 Git 配置里登记了 LFS 过滤器，检出与提交会经 Git LFS 转换文件。
    public let isEnabled: Bool

    /// Git LFS 可以执行，且版本不低于 ``RepositoryLFS/minimumVersion``。
    public var isSupported: Bool {
        version.map(RepositoryLFS.isSupported) ?? false
    }

    /// 创建状态；读取与测试使用。
    public init(version: String?, isEnabled: Bool) {
        self.version = version
        self.isEnabled = isEnabled
    }
}

// MARK: - LFSError

/// LFS 操作不能当作成功的情形。
public enum LFSError: Error, Sendable, Equatable {
    /// 仓库所在机器上找不到 Git LFS、它不能执行，或版本低于 ``RepositoryLFS/minimumVersion``；带上 `git lfs version` 的原始输出。
    case unavailable(GitCommandResult)

    /// 停止跟踪之后 `.gitattributes` 里仍留着这些规则：Git LFS 认不出转义了通配符的规则。
    case patternsRemain([String])
}

// MARK: - RepositoryLFS

/// 仓库的 Git LFS：可用性与版本、启用、跟踪规则，以及 LFS 对象的获取、拉取与推送，都在仓库所在的机器上执行。
///
/// 每个写操作先确认 Git LFS 可用且版本足够：不满足时报出能力缺失，不让普通的 Git 成功被当成 LFS 成功。
public struct RepositoryLFS: Sendable {
    /// 支持的最低版本：逐字跟踪文件名的 `track --filename` 从 2.9.0 开始提供。
    public static let minimumVersion = [2, 9, 0]

    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建 LFS 服务，不立即执行命令。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// `git lfs version` 的第一行是否是不低于 ``minimumVersion`` 的 Git LFS，如 `git-lfs/3.4.0 (GitHub; …)`。
    static func isSupported(_ version: String) -> Bool {
        guard version.hasPrefix("git-lfs/") else {
            return false
        }

        // 每段只取开头的数字，`3.5.0-rc1` 这类预发布版本按 3.5.0 比较
        let components = version.dropFirst("git-lfs/".count)
            .prefix { !$0.isWhitespace }
            .split(separator: ".")
            .map { Int($0.prefix { $0.isNumber }) }

        guard components.count >= 3, components.allSatisfy({ $0 != nil }) else {
            return false
        }

        return !components.compactMap { $0 }.lexicographicallyPrecedes(minimumVersion)
    }

    /// 输出的第一行，去掉首尾空白；没有内容时为 nil。
    static func firstLine(of data: Data) -> String? {
        let line = String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first?
            .trimmingCharacters(in: .whitespaces)

        return line.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// 读取 Git LFS 的版本与仓库是否启用了 LFS 过滤器；找不到 Git LFS 不算失败。
    public func status() async throws -> LFSStatus {
        async let versionResult = version()
        async let filterResult = runner.execute(
            ["config", "-z", "--get-regexp", #"^filter\.lfs\."#],
            acceptedExitCodes: [0, 1]
        )

        let version = try await versionResult
        let filters = try await filterResult

        return LFSStatus(
            version: version.exitCode == 0 ? Self.firstLine(of: version.standardOutput) : nil,
            isEnabled: filters.exitCode == 0 && !filters.standardOutput.isEmpty
        )
    }

    /// 在仓库本地启用 Git LFS：登记过滤器并装上 LFS 的钩子，不改全局配置。
    public func install() async throws {
        try await run(["lfs", "install", "--local"])
    }

    /// 按当前版本的 Git LFS 更新仓库里 LFS 的钩子。
    public func update() async throws {
        try await run(["lfs", "update"])
    }

    /// 把路径模式写进仓库根目录的 `.gitattributes`，此后匹配的文件交给 Git LFS 存放；`.gitattributes` 的改动不自动暂存。
    ///
    /// - Parameter patterns: 路径模式，如 `*.psd`；含空格的模式由 Git LFS 写成转义的形式。
    public func track(_ patterns: [String]) async throws {
        try await run(["lfs", "track", "--"] + patterns)
    }

    /// 只跟踪这几个文件：路径里的通配符按字面值写进 `.gitattributes`。
    ///
    /// - Parameter paths: 相对仓库根目录的文件路径。
    public func track(files paths: [String]) async throws {
        try await run(["lfs", "track", "--filename", "--"] + paths)
    }

    /// 从仓库根目录的 `.gitattributes` 去掉路径模式，已经存进 LFS 的文件保持原样。
    ///
    /// Git LFS 找不到要去掉的规则时也以 0 退出，所以之后读回 `.gitattributes` 核对。
    ///
    /// - Parameter patterns: `.gitattributes` 里写着的路径模式。
    /// - Throws: 有规则仍然留着时抛出 ``LFSError/patternsRemain(_:)``。
    public func untrack(_ patterns: [String]) async throws {
        try await run(["lfs", "untrack", "--"] + patterns)

        let path = runner.location.path + "/.gitattributes"
        let files = try await RepositoryFiles(runner: runner).read([path])
        let tracked = RepositorySettings.lfsPatterns(in: files[path])
        let remaining = patterns.filter(tracked.contains)

        guard remaining.isEmpty else {
            throw LFSError.patternsRemain(remaining)
        }
    }

    /// 从远端下载当前检出需要的 LFS 对象，不改动工作区。
    ///
    /// - Parameters:
    ///   - remote: 远端名。
    ///   - onOutput: 下载进度。
    public func fetch(from remote: String, onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil) async throws {
        try await run(["lfs", "fetch", "--", remote], onOutput: onOutput)
    }

    /// 从远端下载当前检出需要的 LFS 对象，并把工作区里的指针文件换成实际内容。
    ///
    /// - Parameters:
    ///   - remote: 远端名。
    ///   - onOutput: 下载与检出进度。
    public func pull(from remote: String, onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil) async throws {
        try await run(["lfs", "pull", "--", remote], onOutput: onOutput)
    }

    /// 把全部本地分支与标签用到的、远端还没有的 LFS 对象推送到远端。
    ///
    /// - Parameters:
    ///   - remote: 远端名。
    ///   - onOutput: 上传进度。
    public func push(to remote: String, onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil) async throws {
        try await run(["lfs", "push", "--all", "--", remote], onOutput: onOutput)
    }
}

// MARK: - Private

extension RepositoryLFS {
    /// 先确认 Git LFS 可以执行且版本足够，再执行 LFS 命令。
    private func run(_ arguments: [String], onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil) async throws {
        let version = try await version()

        guard version.exitCode == 0, Self.firstLine(of: version.standardOutput).map(Self.isSupported) ?? false else {
            throw LFSError.unavailable(version)
        }

        _ = try await runner.execute(arguments, onOutput: onOutput)
    }

    /// 读出 Git LFS 的版本；找不到 Git LFS 时 Git 报出 “'lfs' is not a git command” 并以 1 退出。
    private func version() async throws -> GitCommandResult {
        try await runner.execute(["lfs", "version"], acceptedExitCodes: [0, 1])
    }
}
