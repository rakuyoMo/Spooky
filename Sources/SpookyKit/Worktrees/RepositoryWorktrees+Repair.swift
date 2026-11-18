import Foundation

// MARK: - WorktreeRepairProblem

/// 选中的目录不能用来修复工作树的原因，按核对的先后排列。
public enum WorktreeRepairProblem: Error, Sendable, Equatable {
    /// 工作树已经有效，不需要修复。
    case notNeeded

    /// 选中的目录不存在。
    case directoryMissing

    /// 选中的目录里没有 `.git` 文件。
    case gitFileMissing

    /// `.git` 读不了、是目录，或里面没有 `gitdir:` 一行。
    case gitFileUnreadable

    /// `.git` 指向的不是这个仓库的工作树登记。
    case otherRepository
}

// MARK: - Repair

extension RepositoryWorktrees {
    /// 核对选中的目录能否用来修复工作树；按 `WorktreeRepairProblem` 的顺序，第一条不过就抛出它。
    ///
    /// 读取与比较都在仓库所在的机器上：服务器仓库经 `RepositoryFiles` 读 `.git` 文件。
    ///
    /// - Parameters:
    ///   - worktree: 要修复的工作树。
    ///   - directory: 选中的目录，仓库所在机器上的绝对路径。
    /// - Throws: `WorktreeRepairProblem`；Git 或文件访问本身失败时抛出原来的错误。
    public func validateRepair(of worktree: Worktree, at directory: String) async throws {
        async let listed = list()
        async let located = runner.run(["rev-parse", "--path-format=absolute", "--git-common-dir"])

        let worktrees = try await listed
        let commonDirectory = String(decoding: try await located, as: UTF8.self)
            .trimmingCharacters(in: .newlines)

        // 1. 工作树已经不是 prunable（或已不在登记里）时不需要修复
        guard let registered = worktrees.first(where: { $0.path == worktree.path }), !registered.isValid else {
            throw WorktreeRepairProblem.notNeeded
        }

        // 2. 目录本身要在
        guard try await exists(directory) else {
            throw WorktreeRepairProblem.directoryMissing
        }

        // 3. 读出 `.git` 里的 gitdir；相对路径相对选中的目录
        let gitDirectory = try await linkedGitDirectory(in: directory)
        let resolved = gitDirectory.hasPrefix("/") ? gitDirectory : directory + "/" + gitDirectory

        // 4. gitdir 要落在这个仓库的公共 Git 目录的 worktrees 之下
        guard normalized(resolved).hasPrefix(normalized(commonDirectory) + "/worktrees/") else {
            throw WorktreeRepairProblem.otherRepository
        }
    }

    /// 选中目录里 `.git` 文件写的 gitdir。
    private func linkedGitDirectory(in directory: String) async throws -> String {
        let path = directory + "/.git"
        let contents: Data?

        // `.git` 是目录或没有读权限时读取会失败，都算读不了
        do {
            contents = try await RepositoryFiles(runner: runner).read([path])[path]
        } catch {
            throw WorktreeRepairProblem.gitFileUnreadable
        }

        guard let contents else {
            throw WorktreeRepairProblem.gitFileMissing
        }

        let line = String(decoding: contents, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "gitdir: "

        guard line.hasPrefix(prefix), line.count > prefix.count, !line.contains("\n") else {
            throw WorktreeRepairProblem.gitFileUnreadable
        }

        return String(line.dropFirst(prefix.count))
    }

    /// 仓库所在机器上的路径是否存在。
    private func exists(_ path: String) async throws -> Bool {
        guard let remote = runner.remote else {
            return FileManager.default.fileExists(atPath: path)
        }

        return try await remote.inspect([path]) == [true]
    }

    /// 比较用的路径：去掉 `.` 与 `..` 一级；本机路径另解析符号链接，Git 写下的路径与面板选中的可能经过不同的链接。
    private func normalized(_ path: String) -> String {
        let url = URL(filePath: path)

        return runner.remote == nil ? url.resolvingSymlinksInPath().path : url.standardized.path
    }
}
