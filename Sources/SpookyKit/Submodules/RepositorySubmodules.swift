import Foundation

// MARK: - RepositorySubmodules

/// 父仓库的子模块：读取清单与状态，执行添加、更新、移动、删除等操作。
///
/// 全部命令在父仓库所在的机器上执行；子模块里的命令以 `-C <子模块路径>` 发出，与父仓库共用执行器、连接与写队列。
public struct RepositorySubmodules: Sendable {
    /// `.gitmodules` 与本地配置里子模块段的键名正则。
    static let settingsPattern = #"^submodule\."#

    /// 子模块指针在索引里的文件模式。
    static let gitlinkMode = "160000"

    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建子模块服务，不立即执行命令。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 读取全部子模块，按路径排序；配置不完整的子模块同样列出，并标出原因。
    ///
    /// `.gitmodules`、本地配置与 `submodule status` 并发读取；有指针缺少配置时 `submodule status` 整体失败，
    /// 此时从索引找出全部子模块指针，只对配置完整的路径再读一次状态。
    public func list() async throws -> [Submodule] {
        async let sharedResult = runner.execute(
            ["config", "-z", "--file", ".gitmodules", "--get-regexp", Self.settingsPattern],
            acceptedExitCodes: [0, 1]
        )
        async let localResult = runner.execute(
            ["config", "-z", "--local", "--get-regexp", Self.settingsPattern],
            acceptedExitCodes: [0, 1]
        )
        async let statusResult = runner.execute(["submodule", "status"], acceptedExitCodes: [0, 1, 128])

        let shared = try Self.parseSettings(try await sharedResult.standardOutput)
        let local = Dictionary(
            try Self.parseSettings(try await localResult.standardOutput).map { ($0.name, $0.settings) },
            uniquingKeysWith: { first, _ in first }
        )
        let configured = shared.compactMap { entry in
            entry.settings.path.map { (path: $0, name: entry.name, settings: entry.settings) }
        }
        let configuredPaths = configured.map(\.path)
        let status = try await statusResult

        // 状态读取成功时，输出里的路径就是全部子模块指针；指针所指的提交另从索引读取
        var records: [String: StatusRecord] = [:]
        var gitlinks: [String: String?]

        if status.exitCode == 0, let parsed = try? Self.parseStatus(status.standardOutput, paths: configuredPaths) {
            records = parsed
            gitlinks = try await pointers(Array(parsed.keys))
        } else {
            gitlinks = try Self.parseGitlinks(try await runner.run(["ls-files", "-s", "-z"]))
            records = try await statusRecords(configuredPaths.filter { gitlinks[$0] != nil })
        }

        let base = try await resolutionBase(for: shared.map(\.settings), local: local)

        // 有段的子模块，以及有指针却没有段的子模块；后者没有可读的状态
        let submodules = configured.map { entry in
            submodule(entry, local: local[entry.name], gitlink: gitlinks[entry.path], record: records[entry.path], base: base)
        }
        let unconfigured = gitlinks
            .filter { gitlink in !configuredPaths.contains(gitlink.key) }
            .map { path, pointer in
                Submodule(
                    name: path,
                    path: path,
                    shared: nil,
                    local: nil,
                    pointer: pointer,
                    checkedOut: nil,
                    state: .uninitialized,
                    problem: .missingConfiguration,
                    needsSynchronizing: false
                )
            }

        return (submodules + unconfigured).sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// 读取已检出子模块的工作区概况；检出的提交与指针不同时另数出两者之间的提交。
    ///
    /// - Parameter submodule: 已检出的子模块。
    public func summary(of submodule: Submodule) async throws -> SubmoduleSummary {
        let status = try await runner.run(
            ["-C", submodule.path, "status", "--porcelain=v2", "-z", "--untracked-files=all"]
        )
        let changes = try WorkingCopyStatus(porcelainV2: status).entries.count

        guard submodule.state == .updated, let pointer = submodule.pointer else {
            return SubmoduleSummary(changes: changes, ahead: 0, behind: 0)
        }

        // 指针所指的提交可能还没有获取到子模块里，此时不显示领先与落后
        let counts = try await runner.execute(
            ["-C", submodule.path, "rev-list", "--left-right", "--count", pointer + "...HEAD"],
            acceptedExitCodes: [0, 128]
        )
        let values = String(decoding: counts.standardOutput, as: UTF8.self)
            .split(whereSeparator: \.isWhitespace)
            .compactMap { Int($0) }

        guard counts.exitCode == 0, values.count == 2 else {
            return SubmoduleSummary(changes: changes, ahead: 0, behind: 0)
        }

        return SubmoduleSummary(changes: changes, ahead: values[1], behind: values[0])
    }

    /// 子模块仓库里远端的地址：优先 origin，没有时取第一个远端；没有远端时为 nil。
    ///
    /// - Parameter submodule: 已检出的子模块。
    public func remoteURL(of submodule: Submodule) async throws -> String? {
        let result = try await runner.execute(
            ["-C", submodule.path, "config", "-z", "--local", "--get-regexp", #"^remote\..*\.url$"#],
            acceptedExitCodes: [0, 1]
        )
        let values = try ConfigRecords.parse(result.standardOutput, pattern: #"^remote\..*\.url$"#, context: "config")

        return ConfigRecords.nonEmpty(values["remote.origin.url"])
            ?? values.keys.sorted().lazy.compactMap { ConfigRecords.nonEmpty(values[$0]) }.first
    }

    /// 子模块里可以检出的本地分支与标签，分支在前，各自按名称排序。
    ///
    /// - Parameter submodule: 已检出的子模块。
    public func revisions(of submodule: Submodule) async throws -> [SubmoduleRevision] {
        let output = try await runner.run(
            ["-C", submodule.path, "for-each-ref", "--format=%(refname)%00%(HEAD)", "refs/heads", "refs/tags"]
        )

        return try Self.parseRevisions(output)
    }

    /// 本仓库作为子模块时父仓库工作区的绝对路径；不是子模块时为 nil。
    public func superproject() async throws -> String? {
        let output = try await runner.run(["rev-parse", "--show-superproject-working-tree"])
        let path = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        return path.isEmpty ? nil : path
    }
}

// MARK: - Private

extension RepositorySubmodules {
    /// `submodule status` 一行给出的状态与提交。
    struct StatusRecord: Equatable {
        /// 检出状态。
        let state: SubmoduleState

        /// 状态行里的提交：已检出时是检出的提交，未检出时是指针。
        let commit: String
    }

    /// 从索引读取子模块指针；路径为空时不执行命令。
    private func pointers(_ paths: [String]) async throws -> [String: String?] {
        guard !paths.isEmpty else {
            return [:]
        }

        return try Self.parseGitlinks(
            try await runner.run(["--literal-pathspecs", "ls-files", "-s", "-z", "--"] + paths)
        )
    }

    /// 只对配置完整的路径读取状态；仍然失败时状态未知。
    private func statusRecords(_ paths: [String]) async throws -> [String: StatusRecord] {
        guard !paths.isEmpty else {
            return [:]
        }

        let result = try await runner.execute(
            ["--literal-pathspecs", "submodule", "status", "--"] + paths,
            acceptedExitCodes: [0, 1, 128]
        )

        guard result.exitCode == 0 else {
            return [:]
        }

        return try Self.parseStatus(result.standardOutput, paths: paths)
    }

    /// 相对地址按父仓库默认远端的地址换算；没有已初始化的相对地址时不执行命令，返回 nil。
    ///
    /// 默认远端依次取当前分支的远端、唯一的远端与 origin；它没有地址时用父仓库工作区的路径。
    private func resolutionBase(
        for shared: [SubmoduleSettings],
        local: [String: SubmoduleSettings]
    ) async throws -> String? {
        let needsBase = shared.contains { settings in
            guard let url = settings.url else { return false }
            return url.hasPrefix("./") || url.hasPrefix("../")
        }

        guard needsBase, !local.isEmpty else {
            return nil
        }

        let pattern = #"^(remote\..*\.url|branch\..*\.remote)$"#

        // Git 在没有远端地址时用工作区的真实路径，符号链接已解析
        async let branchOutput = runner.run(["branch", "--show-current"])
        async let toplevelOutput = runner.run(["rev-parse", "--show-toplevel"])
        async let configResult = runner.execute(["config", "-z", "--get-regexp", pattern], acceptedExitCodes: [0, 1])

        let branch = String(decoding: try await branchOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
        let toplevel = String(decoding: try await toplevelOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
        let values = try ConfigRecords.parse(try await configResult.standardOutput, pattern: pattern, context: "config")
        let remotes = values.keys
            .filter { $0.hasPrefix("remote.") && $0.hasSuffix(".url") }
            .map { String($0.dropFirst("remote.".count).dropLast(".url".count)) }
        let remote =
            ConfigRecords.nonEmpty(values["branch.\(branch).remote"])
                ?? (remotes.count == 1 ? remotes[0] : "origin")

        return ConfigRecords.nonEmpty(values["remote.\(remote).url"]) ?? toplevel
    }

    /// 由 `.gitmodules` 的一段与其余各处读到的信息组成一个子模块，并判断是否缺少指针、地址是否需要同步。
    private func submodule(
        _ entry: (path: String, name: String, settings: SubmoduleSettings),
        local: SubmoduleSettings?,
        gitlink: String??,
        record: StatusRecord?,
        base: String?
    ) -> Submodule {
        let problem: SubmoduleProblem? = gitlink == nil ? .missingPointer : nil

        // 已检出时状态行给出的是检出的提交；未检出与冲突时没有检出的提交
        let state = record?.state ?? (problem == nil ? .unknown : .uninitialized)
        let checkedOut = state == .clean || state == .updated ? record?.commit : nil

        // 本地地址与按同样规则换算后的共享地址不同时需要同步；换算不了的相对地址不提示
        var needsSynchronizing = false
        if let localURL = local?.url, let sharedURL = entry.settings.url {
            let resolved: String? =
                if let base {
                    Self.resolvedURL(sharedURL, base: base)
                } else {
                    sharedURL
                }

            needsSynchronizing = resolved.map { $0 != localURL } ?? false
        }

        return Submodule(
            name: entry.name,
            path: entry.path,
            shared: entry.settings,
            local: local,
            pointer: gitlink ?? nil,
            checkedOut: checkedOut,
            state: state,
            problem: problem,
            needsSynchronizing: needsSynchronizing
        )
    }
}
