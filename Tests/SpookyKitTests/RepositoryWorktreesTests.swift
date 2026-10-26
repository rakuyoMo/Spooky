import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryWorktreesTests

/// 工作树：清单列出主工作树与链接的工作树，失效的同样列出；新建、移动、修复与删除都由 Git 在仓库所在的机器上完成。
struct RepositoryWorktreesTests {
    /// 新建检出分支与分离 HEAD 的工作树；分支已被占用时不强制就失败。
    @Test("新建与清单")
    func addAndList() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repository = try await WorktreeRepository(temporary)
        let worktrees = RepositoryWorktrees(runner: repository.runner)

        try await worktrees.add(at: repository.sibling("功能 树"), revision: "feature", detach: false, force: false)
        try await worktrees.add(at: repository.sibling("分离"), revision: "main", detach: true, force: false)

        let list = try await worktrees.list()
        #expect(list.count == 3)
        #expect(list[0].isMain && list[0].isCurrent && list[0].branch == "refs/heads/main")
        #expect(list.filter(\.isCurrent).count == 1)

        let feature = try #require(list.first { $0.name == "功能 树" })
        #expect(feature.branchName == "feature" && feature.isValid && !feature.isMain)
        #expect(feature.head == repository.head)

        let detached = try #require(list.first { $0.name == "分离" })
        #expect(detached.branch == nil)

        // 从链接的工作树里看，它自己是当前工作树，主工作树不是
        let linked = try await RepositoryWorktrees(runner: temporary.runner(at: feature.path)).list()
        #expect(linked.first { $0.isCurrent }?.path == feature.path)
        #expect(!(linked.first { $0.isMain }?.isCurrent ?? true))

        // 分支已在别的工作树检出
        let busy = repository.sibling("重复")
        let error = await #expect(throws: GitError.self) {
            try await worktrees.add(at: busy, revision: "feature", detach: false, force: false)
        }
        #expect(error?.exitCode == 128)

        try await worktrees.add(at: busy, revision: "feature", detach: false, force: true)
        #expect(try await worktrees.list().count == 4)
    }

    /// 工作区有未跟踪文件时普通删除失败，强制删除成功；移动后路径随之改变。
    @Test("删除与移动")
    func removeAndMove() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repository = try await WorktreeRepository(temporary)
        let worktrees = RepositoryWorktrees(runner: repository.runner)
        let path = repository.sibling("待删")

        try await worktrees.add(at: path, revision: "feature", detach: false, force: false)
        try Data("x\n".utf8).write(to: URL(fileURLWithPath: path + "/新.txt"))

        var worktree = try #require(try await worktrees.list().first { $0.path.hasSuffix("/待删") })
        await #expect(throws: GitError.self) { try await worktrees.remove(worktree, force: false) }

        try await worktrees.move(worktree, to: repository.sibling("移走"))
        worktree = try #require(try await worktrees.list().first { $0.path.hasSuffix("/移走") })
        #expect(FileManager.default.fileExists(atPath: repository.sibling("移走") + "/新.txt"))

        try await worktrees.remove(worktree, force: true)
        #expect(try await worktrees.list().count == 1)
        #expect(!FileManager.default.fileExists(atPath: repository.sibling("移走")))
    }

    /// 手动移走的工作树失效并写出原因；给出新位置后修复，目录已删的失效工作树可以直接删除登记。
    @Test("失效与修复")
    func repair() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repository = try await WorktreeRepository(temporary)
        let worktrees = RepositoryWorktrees(runner: repository.runner)

        try await worktrees.add(at: repository.sibling("原处"), revision: "feature", detach: false, force: false)
        try FileManager.default.moveItem(atPath: repository.sibling("原处"), toPath: repository.sibling("新处"))

        var worktree = try #require(try await worktrees.list().first { $0.path.hasSuffix("/原处") })
        #expect(!worktree.isValid)
        #expect(!(worktree.prunableReason?.isEmpty ?? true))

        try await worktrees.repair(at: repository.sibling("新处"))
        worktree = try #require(try await worktrees.list().first { $0.path.hasSuffix("/新处") })
        #expect(worktree.isValid)

        // 目录被删掉后只剩登记
        try FileManager.default.removeItem(atPath: repository.sibling("新处"))
        worktree = try #require(try await worktrees.list().first { !$0.isMain })
        #expect(!worktree.isValid)

        try await worktrees.remove(worktree, force: false)
        #expect(try await worktrees.list().count == 1)
    }

    /// 解析各种属性：分离 HEAD、锁定与失效的说明、裸仓库；格式错误时抛出。
    @Test("解析工作树清单")
    func parse() throws {
        let output = Data(
            (
                "worktree /srv/repo\0bare\0\0worktree /srv/a b\0HEAD abc\0branch refs/heads/x\0locked\0\0"
                    + "worktree /srv/c\0HEAD def\0detached\0locked 正在使用\0prunable gitdir file points to non-existent location\0\0"
            )
            .utf8
        )
        let list = try Worktree.parseList(output)

        #expect(list.count == 3)
        #expect(list[0].isMain && list[0].isBare && !list[0].isValid)
        #expect(list[1].name == "a b" && (list[1].lockReason?.isEmpty ?? false) && list[1].branchName == "x")
        #expect(list[2].branch == nil && list[2].lockReason == "正在使用")
        #expect(list[2].prunableReason == "gitdir file points to non-existent location")
        #expect(try Worktree.parseList(Data()).isEmpty)
        #expect(throws: RepositoryReadError.self) { try Worktree.parseList(Data("worktree /x\0".utf8)) }
        #expect(throws: RepositoryReadError.self) { try Worktree.parseList(Data("HEAD abc\0\0".utf8)) }
    }
}

// MARK: - WorktreeRepository

/// 有一个提交与 feature 分支的仓库，放在临时目录里的子目录中，工作树建在它旁边。
private struct WorktreeRepository {
    /// 临时目录。
    let root: URL

    /// 仓库的执行器。
    let runner: GitRunner

    /// 唯一的提交。
    let head: String

    /// 建出仓库，提交身份写进本地配置。
    init(_ temporary: TemporaryRepository) async throws {
        root = temporary.directory
        let path = root.appending(path: "主 仓库").path

        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        runner = temporary.runner(at: path)

        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        try Data("一\n".utf8).write(to: URL(fileURLWithPath: path + "/a.txt"))
        _ = try await runner.run(["add", "a.txt"])
        _ = try await runner.run(["commit", "-q", "-m", "第一个提交"])
        _ = try await runner.run(["branch", "feature"])

        head = String(decoding: try await runner.run(["rev-parse", "HEAD"]), as: UTF8.self)
            .trimmingCharacters(in: .newlines)
    }

    /// 临时目录里与仓库并列的路径，按 Git 的写法解析掉符号链接。
    func sibling(_ name: String) -> String {
        root.resolvingSymlinksInPath().appending(path: name).path
    }
}
