import Foundation

// MARK: - RepositoryCreation

/// 新建仓库：在本机或服务器上执行 `git init`。
public enum RepositoryCreation {
    /// 在目标路径新建空仓库；目录不存在时一并创建，已是目录时在其中初始化。
    ///
    /// 服务器上不带 `-C`，路径作为参数交给 B 上的 Git，模板用 B 上 Git 自己的；初始分支名由 `init.defaultBranch` 决定。
    ///
    /// - Parameter location: 本机或服务器上的目标路径，必须是绝对路径。
    /// - Returns: 新仓库的位置，可直接用来打开。
    /// - Throws: 路径不是绝对路径或已存在且不是目录时抛出 ``HostOperationError``，Git 失败时抛出 ``GitError``。
    @discardableResult
    public static func initialize(_ location: RepositoryLocation) async throws -> RepositoryLocation {
        try await initialize(location) { GitRunner(location: $0) }
    }

    /// 与公开的 ``initialize(_:)`` 相同，本机经指定方式创建执行器，测试据此隔离用户的 Git 配置。
    @discardableResult
    static func initialize(
        _ location: RepositoryLocation,
        localRunner: (RepositoryLocation) -> GitRunner
    ) async throws -> RepositoryLocation {
        let path = try HostOperationError.normalized(location.path)

        guard let host = location.host else {
            return try await initializeLocally(path, runner: localRunner(.local(path: path)))
        }

        _ = try await RemoteConnection.host(host)
            .hostOperation(.git(["init", "--", path]), at: path, writing: true)
            .value

        return .remote(host: host, path: path)
    }

    /// 本机先确保目录存在，再在其中执行 `git init`；失败时删掉本次新建的目录。
    private static func initializeLocally(_ path: String, runner: GitRunner) async throws -> RepositoryLocation {
        let created = try LocalDirectory.prepare(path)

        do {
            _ = try await runner.execute(["init"])
            return runner.location
        } catch {
            if created { try? FileManager.default.removeItem(atPath: path) }
            throw error
        }
    }
}

// MARK: - LocalDirectory

/// 本机的新建与克隆在目标目录里执行 Git，目录要先存在。
enum LocalDirectory {
    /// 目录不存在时连同上级目录一起创建；已是目录时直接使用。
    ///
    /// - Returns: 是否由本次新建，失败时据此清理。
    /// - Throws: 路径已存在但不是目录时抛出 ``HostOperationError/notDirectory(_:)``。
    static func prepare(_ path: String) throws -> Bool {
        var isDirectory: ObjCBool = false

        guard !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            guard isDirectory.boolValue else { throw HostOperationError.notDirectory(nil) }
            return false
        }

        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true
        )
        return true
    }
}
