import Foundation

extension RemoteConnection {
    /// 依次检查 Git、路径权限、工作区与状态格式，返回 Git 确认的工作区根。
    func verifyRepository() async throws -> RemoteRepository {
        // B 的非交互环境必须能找到 Git，且版本满足最低要求。
        _ = try await probe(["/bin/sh", "-c", "command -v git"], kind: .gitUnavailable)
        let version = try await probe(["git", "--version"], kind: .gitUnavailable)
        guard let parsed = GitVersion(output: version.standardOutput), parsed >= .minimum else {
            throw RemoteConnectionError(.gitVersion, result: version)
        }

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

        let worktree = try await probe(
            ["git", "-C", requestedPath, "rev-parse", "--is-inside-work-tree"],
            kind: .notWorkingTree
        )
        guard worktree.standardOutput == Data("true\n".utf8) else {
            throw RemoteConnectionError(.notWorkingTree, result: worktree)
        }

        let status = try await probe(
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
}
