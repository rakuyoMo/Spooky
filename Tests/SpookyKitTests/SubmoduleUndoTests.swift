import Foundation
import Testing

@testable import SpookyKit

// MARK: - SubmoduleUndoTests

/// 子模块的结构与本地设置不在撤销快照里，靠操作前记下的内容与反向操作撤销：撤销后仓库的状态、`.gitmodules` 的原文、
/// 本地配置与子模块里的分支都回到操作前；要删掉的内容找不回、或仓库已经变了时不撤销。
struct SubmoduleUndoTests {
    /// 原来没有 `.gitmodules` 时添加再撤销：子模块与 `.gitmodules` 都不在了；重做复用留下的 Git 目录，上游不在了也能完成。
    @Test("添加的撤销与重做")
    func addition() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)
        let before = try await SubmoduleSnapshot(repositories)

        let record = try await submodules.additionRecord(at: "依赖/my lib")
        try await submodules.add(url: repositories.upstreamPath, path: "依赖/my lib", reusesGitDirectory: false)

        try await submodules.undoAdd(record)
        #expect(try await SubmoduleSnapshot(repositories) == before)
        #expect(before.file == nil)

        // 上游改名后重做：没有连接上游，指针仍是原来的提交
        try FileManager.default.moveItem(atPath: repositories.upstreamPath, toPath: repositories.upstreamPath + " 旧")
        try await submodules.add(url: repositories.upstreamPath, path: "依赖/my lib", reusesGitDirectory: true)

        let restored = try #require(try await submodules.list().first)
        #expect(restored.path == "依赖/my lib")
        #expect(restored.pointer == repositories.upstreamHead)
        #expect(restored.state == .clean)
    }

    /// 删掉排在前面的子模块再撤销：指针、`.gitmodules` 的原文与各段顺序、本地配置的段、子模块里的分支都回到删除前；
    /// 没有检出的子模块与保留工作区的删除同样能撤销。
    @Test("删除的撤销")
    func removal() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        for path in ["a.b", "子 模块/c"] {
            try await submodules.add(url: repositories.upstreamPath, path: path, reusesGitDirectory: false)
        }

        _ = try await repositories.parent.run(["commit", "-q", "-m", "子模块"])

        // a.b 停在自己的分支上、另有一项本地设置；子 模块/c 去掉初始化，只留下空目录
        _ = try await repositories.parent.run(["-C", "a.b", "checkout", "-q", "-b", "特性"])
        _ = try await repositories.parent.run(["config", "--local", "submodule.a.b.ignore", "dirty"])
        _ = try await repositories.parent.run(["submodule", "deinit", "-q", "-f", "--", "子 模块/c"])

        let before = try await SubmoduleSnapshot(repositories)

        for path in ["a.b", "子 模块/c"] {
            for keepsWorkingTree in [false, true] {
                let submodule = try #require(try await submodules.list().first { $0.path == path })
                let record = try await submodules.removalRecord(of: submodule, keepsWorkingTree: keepsWorkingTree)

                try await submodules.delete(submodule, keepsWorkingTree: keepsWorkingTree, force: false)
                #expect(try await SubmoduleSnapshot(repositories) != before)

                try await submodules.undoDelete(record)
                #expect(try await SubmoduleSnapshot(repositories) == before)
            }
        }

        #expect(before.branch == "特性")
    }

    /// 要删掉的工作区里有找不回的内容时不记撤销：子模块里有改动，或 Git 目录就在工作区里；保留工作区时不受影响。
    @Test("删除时工作区的内容找不回")
    func unrecoverableRemoval() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        // 先克隆再加入的子模块，Git 目录留在自己的工作区里
        _ = try await repositories.parent.run(["clone", "-q", repositories.upstreamPath, "内嵌"])

        for path in ["lib", "内嵌"] {
            try await submodules.add(url: repositories.upstreamPath, path: path, reusesGitDirectory: false)
        }

        try Data("改动\n".utf8).write(to: repositories.parentURL.appending(path: "lib/a.txt"))

        let list = try await submodules.list()
        let modified = try #require(list.first { $0.path == "lib" })
        let embedded = try #require(list.first { $0.path == "内嵌" })

        await #expect(throws: SubmoduleError.localModifications) {
            try await submodules.removalRecord(of: modified, keepsWorkingTree: false)
        }

        await #expect(throws: RepositoryUndoError.untrackedFiles) {
            try await submodules.removalRecord(of: embedded, keepsWorkingTree: false)
        }

        _ = try await submodules.removalRecord(of: modified, keepsWorkingTree: true)
        _ = try await submodules.removalRecord(of: embedded, keepsWorkingTree: true)
    }

    /// 移动时同时改名、单独改名，撤销后路径、名称、子模块的 Git 目录与 `.gitmodules` 的原文都回到操作前。
    @Test("移动与改名的撤销")
    func moveAndRename() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        try await submodules.add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: false)
        _ = try await repositories.parent.run(["commit", "-q", "-m", "子模块"])

        let original = try #require(try await submodules.list().first)
        let before = try await SubmoduleSnapshot(repositories)

        try await submodules.move(original, to: "外层/新 位置", renamesSubmodule: true)
        #expect(try await submodules.list().first?.name == "外层/新 位置")

        try await submodules.undoMove(original, to: "外层/新 位置", renamesSubmodule: true)
        #expect(try await SubmoduleSnapshot(repositories) == before)
        #expect(try await submodules.list().first?.state == .clean)

        // 子模块的 Git 目录搬回原名称下
        let modules = repositories.parentURL.appending(path: ".git/modules")
        #expect(FileManager.default.fileExists(atPath: modules.appending(path: "lib/HEAD").path))
        #expect(!FileManager.default.fileExists(atPath: modules.appending(path: "外层/新 位置").path))

        try await submodules.rename(original, to: "新名")
        try await submodules.undoRename(original, to: "新名")
        #expect(try await SubmoduleSnapshot(repositories) == before)
        #expect(try await submodules.list().first?.state == .clean)
    }

    /// 本地配置里的地址与选项：撤销后写回原值，原来没有设置的撤销后不存在；值没变时不记。
    @Test("本地设置的撤销")
    func localSettings() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        try await submodules.add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: false)
        _ = try await repositories.parent.run(["config", "--local", "submodule.lib.update", "rebase"])

        let submodule = try #require(try await submodules.list().first)
        let before = try await SubmoduleSnapshot(repositories)

        // 改地址、设置原来没有的忽略模式、删掉原来有的更新策略
        let url = try #require(try await submodules.localURLChange(of: submodule, to: "https://example.com/lib.git"))
        try await submodules.setURL("https://example.com/lib.git", for: submodule, in: .local)

        let ignore = try #require(try await submodules.localOptionChange(.ignore, of: submodule, to: "all"))
        try await submodules.set(.ignore, to: "all", for: submodule, in: .local)

        let update = try #require(try await submodules.localOptionChange(.update, of: submodule, to: nil))
        try await submodules.set(.update, to: nil, for: submodule, in: .local)

        for change in [update, ignore, url] {
            try await submodules.undoSettingChange(change)
        }

        #expect(try await SubmoduleSnapshot(repositories) == before)
        #expect(try await submodules.localOptionChange(.ignore, of: submodule, to: nil) == nil)
        #expect(try await submodules.localOptionChange(.update, of: submodule, to: "rebase") == nil)
    }

    /// 仓库已经变了时撤销报仓库已改变，不做任何改动。
    @Test("撤销子模块操作时前提不符")
    func changedRepository() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let repositories = try await SubmoduleRepositories(temporary)
        let submodules = RepositorySubmodules(runner: repositories.parent)

        // 撤销添加之前子模块已在外部删掉
        let addition = try await submodules.additionRecord(at: "lib")
        try await submodules.add(url: repositories.upstreamPath, path: "lib", reusesGitDirectory: false)
        _ = try await repositories.parent.run(["rm", "-q", "-f", "lib"])

        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await submodules.undoAdd(addition) }

        // 撤销删除之前原路径上已有别的文件
        try await submodules.add(url: repositories.upstreamPath, path: "other", reusesGitDirectory: false)
        let other = try #require(try await submodules.list().first { $0.path == "other" })
        let removal = try await submodules.removalRecord(of: other, keepsWorkingTree: false)
        try await submodules.delete(other, keepsWorkingTree: false, force: false)
        try Data("占位\n".utf8).write(to: repositories.parentURL.appending(path: "other"))

        let occupied = try await SubmoduleSnapshot(repositories)
        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await submodules.undoDelete(removal) }
        #expect(try await SubmoduleSnapshot(repositories) == occupied)

        // 撤销修改本地设置之前这一项已在外部改过
        try FileManager.default.removeItem(at: repositories.parentURL.appending(path: "other"))
        try await submodules.undoDelete(removal)

        let restored = try #require(try await submodules.list().first { $0.path == "other" })
        let change = try #require(try await submodules.localOptionChange(.ignore, of: restored, to: "all"))
        try await submodules.set(.ignore, to: "all", for: restored, in: .local)
        _ = try await repositories.parent.run(["config", "--local", "submodule.other.ignore", "dirty"])

        await #expect(throws: RepositoryUndoError.repositoryChanged) { try await submodules.undoSettingChange(change) }
    }

    /// `ls-files -s -z` 的一条记录取出模式与对象；格式不对时报格式错误，冲突中的文件不能写回。
    @Test("暂存记录的解析")
    func stagedRecordParsing() throws {
        let object = String(repeating: "a", count: 40)

        #expect(try RepositorySubmodules.stagedRecord(Data()) == nil)
        #expect(try RepositorySubmodules.stagedRecord(Data("100644 \(object) 0\t.gitmodules\0".utf8)) == "100644 \(object)")

        #expect(throws: RepositoryReadError.malformedOutput("ls-files")) {
            try RepositorySubmodules.stagedRecord(Data("100644 \(object) 0 .gitmodules\0".utf8))
        }

        #expect(throws: RepositoryUndoError.unresolvedConflicts) {
            try RepositorySubmodules.stagedRecord(Data("100644 \(object) 2\t.gitmodules\0".utf8))
        }
    }
}

// MARK: - SubmoduleSnapshot

/// 撤销要复原的全部内容：撤销快照记下的仓库状态，以及快照不含的 `.gitmodules` 原文、本地配置里的子模块段
/// 与第一个检出的子模块里的分支。
private struct SubmoduleSnapshot: Equatable {
    /// 引用、索引、工作区与状态。
    let state: RepositoryState

    /// 工作区里 `.gitmodules` 的原文；没有这个文件时为 nil。
    let file: Data?

    /// 本地配置里子模块各段的原样输出。
    let settings: Data

    /// 第一个检出的子模块里当前的分支；没有检出的子模块时为 nil。
    let branch: String?

    /// 读出父仓库现在的样子。
    init(_ repositories: SubmoduleRepositories) async throws {
        let parent = repositories.parent

        state = try await RepositoryUndo(runner: parent).capture()
        file = try? Data(contentsOf: repositories.parentURL.appending(path: ".gitmodules"))
        settings = try await parent.execute(
            ["config", "-z", "--local", "--get-regexp", #"^submodule\."#],
            acceptedExitCodes: [0, 1]
        ).standardOutput

        guard let populated = try await RepositorySubmodules(runner: parent).list().first(where: \.isPopulated) else {
            branch = nil
            return
        }

        let output = try await parent.run(["-C", populated.path, "branch", "--show-current"])
        branch = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
    }
}
