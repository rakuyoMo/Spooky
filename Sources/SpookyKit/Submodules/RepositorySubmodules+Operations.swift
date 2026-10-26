import Foundation

// MARK: - SubmoduleConfigurationScope

/// 子模块设置写在哪里。
public enum SubmoduleConfigurationScope: Sendable, Hashable {
    /// `.gitmodules`，随仓库提交、与他人共享。
    case shared

    /// 仓库本地配置，只影响这一份工作区，优先于 `.gitmodules`。
    case local
}

// MARK: - SubmoduleOption

/// 子模块详情里可以修改的三个选项。
public enum SubmoduleOption: String, Sendable, CaseIterable {
    /// 父仓库获取时是否连带获取，见 ``SubmoduleFetchMode``。
    case fetchRecurseSubmodules

    /// 父仓库状态里忽略哪些改动，见 ``SubmoduleIgnoreMode``。
    case ignore

    /// 更新的方式，见 ``SubmoduleUpdateStrategy``。
    case update
}

// MARK: - Operations

extension RepositorySubmodules {
    /// 添加子模块：克隆到工作区里的路径，登记进 `.gitmodules` 并暂存子模块指针。
    ///
    /// - Parameters:
    ///   - url: 子模块仓库的地址。
    ///   - path: 工作区里的相对路径，必须不存在或是空目录。
    ///   - reusesGitDirectory: 父仓库的 Git 目录里已有同名子模块的 Git 目录时直接复用它。
    ///   - onOutput: 克隆进度。
    /// - Throws: 已有同名 Git 目录且没有选择复用时抛出 ``SubmoduleError/gitDirectoryExists(name:)``。
    public func add(
        url: String,
        path: String,
        reusesGitDirectory: Bool,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        let force = reusesGitDirectory ? ["--force"] : []

        do {
            _ = try await runner.execute(
                ["submodule", "add", "--progress"] + force + ["--", url, path],
                onOutput: onOutput
            )
        } catch let error as GitError where error.message.contains("is found locally") {
            throw SubmoduleError.gitDirectoryExists(name: path)
        }
    }

    /// 删掉父仓库 Git 目录里某个名称的子模块 Git 目录，之后添加同名子模块时会重新克隆。
    ///
    /// - Parameter name: 子模块名称。
    public func removeGitDirectory(named name: String) async throws {
        try await RepositoryFiles(runner: runner).removeTree(try await gitDirectory(named: name))
    }

    /// 初始化子模块：把 `.gitmodules` 里的地址等设置复制进仓库本地配置。
    ///
    /// - Parameter submodules: 要初始化的子模块。
    public func initialize(_ submodules: [Submodule]) async throws {
        _ = try await runner.run(["--literal-pathspecs", "submodule", "init", "--"] + submodules.map(\.path))
    }

    /// 更新子模块：没有初始化的先初始化，再检出指针所指的提交。
    ///
    /// - Parameters:
    ///   - submodules: 要更新的子模块；nil 表示全部子模块。
    ///   - recursive: 连同嵌套的子模块一起更新。
    ///   - onOutput: 克隆与检出进度。
    public func update(
        _ submodules: [Submodule]?,
        recursive: Bool,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        let options = ["submodule", "update", "--init", "--progress"] + (recursive ? ["--recursive"] : [])
        let paths = submodules.map { ["--"] + $0.map(\.path) } ?? []

        _ = try await runner.execute(["--literal-pathspecs"] + options + paths, onOutput: onOutput)
    }

    /// 同步子模块的地址：按 `.gitmodules` 改写本地配置与子模块仓库里远端的地址。
    ///
    /// - Parameter submodules: 要同步的子模块；nil 表示全部子模块。
    public func synchronize(_ submodules: [Submodule]?) async throws {
        let paths = submodules.map { ["--"] + $0.map(\.path) } ?? []

        _ = try await runner.run(["--literal-pathspecs", "submodule", "sync"] + paths)
    }

    /// 修改子模块的地址，`.gitmodules` 的改动不自动暂存。
    ///
    /// - Parameters:
    ///   - url: 新地址。
    ///   - submodule: 子模块。
    ///   - scope: 写进 `.gitmodules` 还是仓库本地配置。
    public func setURL(_ url: String, for submodule: Submodule, in scope: SubmoduleConfigurationScope) async throws {
        _ = try await runner.run(Self.configCommand(scope) + ["submodule.\(submodule.name).url", url])
    }

    /// 修改或删除子模块的一个选项；删除没有设置的选项不算失败。
    ///
    /// - Parameters:
    ///   - option: 选项。
    ///   - value: 配置值；nil 表示删除，此后按 Git 的默认值处理。
    ///   - submodule: 子模块。
    ///   - scope: 写进 `.gitmodules` 还是仓库本地配置。
    public func set(
        _ option: SubmoduleOption,
        to value: String?,
        for submodule: Submodule,
        in scope: SubmoduleConfigurationScope
    ) async throws {
        let key = "submodule.\(submodule.name).\(option.rawValue)"

        guard let value else {
            // 键不存在时 git config --unset 以 5 退出
            _ = try await runner.execute(Self.configCommand(scope) + ["--unset", key], acceptedExitCodes: [0, 5])
            return
        }

        _ = try await runner.run(Self.configCommand(scope) + [key, value])
    }

    /// 在子模块里获取全部远端，不连带获取更深一层的子模块。
    ///
    /// - Parameters:
    ///   - submodule: 已检出的子模块。
    ///   - prunes: 删掉远端已删除分支的远端跟踪分支。
    ///   - onOutput: 获取进度。
    public func fetch(
        _ submodule: Submodule,
        prunes: Bool,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        let prune = prunes ? ["--prune"] : []

        _ = try await runner.execute(
            ["-C", submodule.path, "fetch", "--all", "--progress", "--no-recurse-submodules"] + prune,
            onOutput: onOutput
        )
    }

    /// 在子模块里检出一个分支，或以分离 HEAD 检出一个标签。
    ///
    /// - Parameters:
    ///   - revision: 子模块里的分支或标签。
    ///   - submodule: 已检出的子模块。
    public func checkout(_ revision: SubmoduleRevision, in submodule: Submodule) async throws {
        let target = revision.isTag ? ["--detach", revision.reference] : [revision.name]

        _ = try await runner.run(["-C", submodule.path, "checkout"] + target + ["--"])
    }
}

// MARK: - Helpers

extension RepositorySubmodules {
    /// 读写子模块设置的 `git config` 前缀。
    static func configCommand(_ scope: SubmoduleConfigurationScope) -> [String] {
        switch scope {
        case .shared: ["config", "--file", ".gitmodules"]
        case .local: ["config", "--local"]
        }
    }

    /// 父仓库 Git 目录里存放这个名称的子模块 Git 目录的绝对路径。
    func gitDirectory(named name: String) async throws -> String {
        let output = try await runner.run(["rev-parse", "--path-format=absolute", "--git-common-dir"])
        let common = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard common.hasPrefix("/"), !common.contains("\n") else {
            throw RepositoryReadError.malformedOutput("rev-parse")
        }

        return common + "/modules/" + name
    }
}
