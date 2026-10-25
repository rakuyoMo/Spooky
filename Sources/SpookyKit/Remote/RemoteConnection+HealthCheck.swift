import Foundation

extension RemoteConnection {
    /// 依次检查 Git、路径权限、工作区与状态格式，返回 Git 确认的工作区根。
    func verifyRepository() async throws -> RemoteRepository {
        // 先记下 B 的非交互环境，后面任何一步失败时界面都能据此给出修复方向
        environment = try await readEnvironment()

        // B 的非交互环境必须能找到 Git，且版本满足最低要求。
        _ = try await probe(["/bin/sh", "-c", "command -v git"], kind: .gitUnavailable)
        try await verifyGitVersion()

        // 存在、读取和搜索权限分别检查，路径只作为位置参数进入固定脚本。
        _ = try await probe([
            "/bin/sh", "-c",
            "if ! test -d \"$1\"; then printf '%s\\n' 'Directory does not exist' >&2; exit 2; fi",
            "spooky-path", requestedPath,
        ], kind: .pathUnavailable)
        _ = try await probe([
            "/bin/sh", "-c",
            """
            if ! test -r "$1" || ! test -x "$1"; then
                printf '%s\\n' 'Directory is not readable or searchable' >&2
                exit 3
            fi
            """,
            "spooky-path", requestedPath,
        ], kind: .pathPermission)

        // 权限位允许时，B 的隐私保护仍可能在读取目录内容时拒绝 SSH 会话
        #warning(
            "TODO: 未在 B 的隐私保护目录上实测；核实方式：在 B 的远程登录设置里关闭 “允许远程用户完全磁盘访问”，添加 ~/Documents 下的仓库，确认拒绝发生在这一步且 stderr 为 “Operation not permitted”；影响体检能否给出磁盘访问权限的修复方向"
        )
        _ = try await probeAccess([
            "/usr/bin/perl", "-e",
            "opendir(my $directory, $ARGV[0]) or do { print STDERR \"$!\\n\"; exit 3 }",
            "--", requestedPath,
        ], kind: .pathPermission)

        let worktree = try await probeAccess(
            ["git", "-C", requestedPath, "rev-parse", "--is-inside-work-tree"],
            kind: .notWorkingTree
        )
        guard worktree.standardOutput == Data("true\n".utf8) else {
            throw RemoteConnectionError(.notWorkingTree, result: worktree)
        }

        let status = try await probeAccess(
            ["git", "-C", requestedPath] + GitRunner.globalOptions
                + ["status", "--porcelain=v2", "-z", "--branch", "--untracked-files=all"],
            kind: .statusFormat
        )

        do { _ = try WorkingCopyStatus(porcelainV2: status.standardOutput) }
        catch { throw RemoteConnectionError(.statusFormat, result: status) }

        // 仓库身份取 Git 返回的工作区根，从子目录打开时据此共享同一会话。
        let root = try await probe(
            ["git", "-C", requestedPath, "rev-parse", "--show-toplevel"],
            kind: .notWorkingTree
        )
        guard
            let rootPath = String(data: root.standardOutput, encoding: .utf8),
            rootPath.hasPrefix("/"), rootPath.hasSuffix("\n")
        else { throw RemoteConnectionError(.notWorkingTree, result: root) }

        return RemoteRepository(host: host, path: String(rootPath.dropLast()))
    }

    /// 主机连接的体检：读出 B 的主目录与环境，确认非交互环境能找到满足最低版本的 Git。
    func verifyHost() async throws {
        environment = try await readEnvironment()

        // 主目录是浏览与默认目标路径的起点，读不到环境说明 B 缺少包装器同样依赖的 Perl
        guard environment != nil else {
            throw RemoteConnectionError(.deployment, diagnostic: "environment probe failed")
        }

        _ = try await probe(["/bin/sh", "-c", "command -v git"], kind: .gitUnavailable)
        try await verifyGitVersion()
    }

    /// 读取 `git --version` 并记进环境；低于最低版本时抛出版本错误。
    private func verifyGitVersion() async throws {
        let version = try await probe(["git", "--version"], kind: .gitUnavailable)
        environment?.gitVersion = String(decoding: version.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let parsed = GitVersion(output: version.standardOutput), parsed >= .minimum else {
            throw RemoteConnectionError(.gitVersion, result: version)
        }
    }

    /// 读取 B 端非交互 shell 的环境；脚本失败时返回 nil，输出含环境变量的值，不放进错误对象。
    private func readEnvironment() async throws -> RemoteHostEnvironment? {
        let result = try await commandChannel(
            ["/bin/sh", "-c", RemoteHostEnvironment.script],
            arguments: ["environment"]
        )

        if result.exitCode == 255 { throw RemoteConnectionError.ssh(result) }
        guard result.exitCode == 0 else { return nil }

        // Spooky 自己在远端命令里设置的变量不算 B 的环境问题
        let assigned = Set(configuration.remoteEnvironment.keys).union(["GIT_TERMINAL_PROMPT"])
        return RemoteHostEnvironment(output: result.standardOutput, excluding: assigned)
    }

    /// 与 ``probe(_:input:kind:)`` 相同，但 stderr 含 “Operation not permitted” 时归为磁盘访问权限问题。
    private func probeAccess(
        _ command: [String],
        kind: RemoteConnectionError.Kind
    ) async throws -> GitCommandResult {
        do {
            return try await probe(command, kind: kind)
        } catch let error as RemoteConnectionError where error.kind == kind {
            let message = error.result.map { String(decoding: $0.standardError, as: UTF8.self) } ?? ""

            guard message.contains("Operation not permitted") else { throw error }
            throw RemoteConnectionError(.diskAccess, result: error.result)
        }
    }
}
