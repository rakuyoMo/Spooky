import Foundation

// MARK: - RepositoryWorktrees

/// 仓库的工作树：列出、创建、移动、修复与删除，全部在仓库所在的机器上执行，路径都是那台机器上的绝对路径。
public struct RepositoryWorktrees: Sendable {
    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建工作树服务，不立即执行命令。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 仓库的全部工作树，第一个是主工作树；目录已不存在的工作树同样列出，并标出失效原因与这个仓库自己。
    ///
    /// 在子模块里 Git 把主工作树写成子模块的 Git 目录：这个仓库就是主工作树时，主工作树的路径换成工作区根目录。
    public func list() async throws -> [Worktree] {
        async let listed = runner.run(["worktree", "list", "--porcelain", "-z"])
        async let located = runner.run(
            ["rev-parse", "--path-format=absolute", "--git-dir", "--git-common-dir", "--show-toplevel"]
        )

        let worktrees = try Worktree.parseList(try await listed)
        let lines = String(decoding: try await located, as: UTF8.self).split(separator: "\n").map(String.init)

        guard lines.count == 3, lines.allSatisfy({ $0.hasPrefix("/") }) else {
            throw RepositoryReadError.malformedOutput("rev-parse")
        }

        // Git 目录就是公共目录时，这个仓库是主工作树
        let isMainRepository = lines[0] == lines[1]
        let toplevel = lines[2]

        return worktrees.map { worktree in
            let current = isMainRepository ? worktree.isMain : worktree.path == toplevel

            return Worktree(
                path: current ? toplevel : worktree.path,
                head: worktree.head,
                branch: worktree.branch,
                isMain: worktree.isMain,
                isCurrent: current,
                isBare: worktree.isBare,
                lockReason: worktree.lockReason,
                prunableReason: worktree.prunableReason
            )
        }
    }

    /// 新建工作树并检出指定的版本。
    ///
    /// - Parameters:
    ///   - path: 新工作树的绝对路径，必须不存在或是空目录。
    ///   - revision: 检出的分支或版本。
    ///   - detach: 以分离 HEAD 检出，不占用分支。
    ///   - force: 分支已在别的工作树检出时仍然创建。
    ///   - onOutput: 检出进度。
    public func add(
        at path: String,
        revision: String,
        detach: Bool,
        force: Bool,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        let options = (detach ? ["--detach"] : []) + (force ? ["--force"] : [])

        _ = try await runner.execute(["worktree", "add"] + options + ["--", path, revision], onOutput: onOutput)
    }

    /// 把工作树移到新位置，工作区里的改动随之保留。
    ///
    /// - Parameters:
    ///   - worktree: 不是主工作树的工作树。
    ///   - destination: 新的绝对路径，必须不存在。
    public func move(_ worktree: Worktree, to destination: String) async throws {
        _ = try await runner.run(["worktree", "move", "--", worktree.path, destination])
    }

    /// 删除工作树；目录已不存在时只清掉它的登记。
    ///
    /// - Parameters:
    ///   - worktree: 不是主工作树的工作树。
    ///   - force: 工作区里有改动或未跟踪的文件时仍然删除。
    public func remove(_ worktree: Worktree, force: Bool) async throws {
        _ = try await runner.run(["worktree", "remove"] + (force ? ["--force"] : []) + ["--", worktree.path])
    }

    /// 修复手动移走的工作树与仓库之间的连接。
    ///
    /// - Parameter location: 工作树目录现在的绝对路径。
    public func repair(at location: String) async throws {
        _ = try await runner.run(["worktree", "repair", "--", location])
    }
}
