import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryStashesTests

/// 储藏列表的解析与保存、应用、Pop、部分储藏、快照、删除、单文件应用的真实 Git 结果。
///
/// 夹具由 Git 2.54 在忽略系统与用户配置、固定提交身份与时间的临时仓库中生成：
/// 依次是 `stash create` + `stash store` 的快照、带未跟踪文件和含冒号说明的储藏、Git 自动生成标题的储藏，
/// 后两个保存在中文分支 `功能/分支` 上。
struct RepositoryStashesTests {
    /// 序号取自引用日志选择器；说明、来源分支、基准提交与未跟踪文件的父提交都从同一份输出读出。
    @Test("stash list 夹具：序号、说明、分支、父提交与日期")
    func parseList() throws {
        let stashes = try StashEntry.parse(try fixture("stash-list.bin"))
        #expect(stashes.map(\.index) == [0, 1, 2])
        #expect(stashes.allSatisfy { $0.id.count == 40 })

        // 快照经 stash store 登记，提交标题仍是 stash create 写下的 “On <分支>: <说明>”
        #expect(stashes[0].branch == "main")
        #expect(stashes[0].message == "snapshot note")
        #expect(stashes[0].untrackedCommit == nil)
        #expect(stashes[0].date == Date(timeIntervalSince1970: 1_767_323_220))

        // 说明里的冒号属于说明本身，分支名不含冒号
        #expect(stashes[1].branch == "功能/分支")
        #expect(stashes[1].message == "说明: 带冒号")
        #expect(stashes[1].parents.count == 3)
        #expect(stashes[1].untrackedCommit == stashes[1].parents[2])

        // Git 自动生成的标题没有用户说明，基准提交是第一个父提交
        #expect(stashes[2].branch == "功能/分支")
        #expect(stashes[2].message == nil)
        #expect(stashes[2].base == stashes[2].parents[0])
        #expect(stashes[2].reference == "stash@{2}")
    }

    /// 哈希长度随仓库算法变化，SHA-256 仓库同样可以解析。
    @Test("stash list 夹具：SHA-256 仓库")
    func parseSHA256() throws {
        let stashes = try StashEntry.parse(try fixture("stash-list-sha256.bin"))
        #expect(stashes.count == 3)
        #expect(stashes.allSatisfy { $0.id.count == 64 && $0.parents.allSatisfy { $0.count == 64 } })
    }

    /// 截断、字段错位、日期形式的选择器或不像储藏的提交都拒绝整份列表，序号与哈希不会错位。
    @Test("stash list 格式错误")
    func malformedList() throws {
        let hash = String(repeating: "a", count: 40)
        let parents = hash + " " + String(repeating: "b", count: 40)
        let valid = "stash@{0}\0\(hash)\0\(parents)\0100\0On main: x\0"
        #expect(try StashEntry.parse(Data(valid.utf8)).count == 1)
        #expect(try StashEntry.parse(Data()).isEmpty)

        let broken = [
            String(valid.dropLast()),
            "stash@{0}\0\(hash)\0\(parents)\0100\0",
            "stash@{2026-01-01}\0\(hash)\0\(parents)\0100\0x\0",
            "refs/stash@{0}\0\(hash)\0\(parents)\0100\0x\0",
            "stash@{0}\0\(hash)\0\(hash)\0100\0x\0",
            "stash@{0}\0HEAD\0\(parents)\0100\0x\0",
            "stash@{0}\0\(hash)\0\(parents)\0soon\0x\0",
        ]

        for output in broken {
            #expect(throws: RepositoryReadError.malformedOutput("stash list")) {
                try StashEntry.parse(Data(output.utf8))
            }
        }
    }

    /// 保存后工作区变干净；应用时恢复暂存区，Pop 成功后储藏从列表中消失。
    @Test("保存、应用与 Pop 恢复暂存区状态")
    func saveApplyPop() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let stashes = RepositoryStashes(runner: repository.runner)

        try write("staged\n", to: "tracked *.txt", in: repository)
        _ = try await repository.runner.run(["--literal-pathspecs", "add", "--", "tracked *.txt"])
        try write("unstaged\n", to: "tracked x.txt", in: repository)
        try write("new\n", to: "未跟踪.txt", in: repository)

        try await stashes.save(message: "说明 -m", includeUntracked: true)
        #expect(try await repository.runner.status().entries.isEmpty)

        let saved = try #require(try await stashes.list().first)
        #expect(saved.message == "说明 -m" && saved.branch == "main")
        #expect(saved.untrackedCommit != nil)

        // 应用保留储藏；恢复暂存区后已暂存的文件仍是已暂存状态
        try await stashes.apply(saved, restoreIndex: true, drop: false)
        let restored = try await repository.runner.status().entries
        #expect(restored.first { $0.path == "tracked *.txt" }?.staged == .modified)
        #expect(restored.first { $0.path == "tracked x.txt" }?.unstaged == .modified)
        #expect(restored.contains { $0.path == "未跟踪.txt" && $0.kind == .untracked })
        #expect(try await stashes.list().count == 1)

        // 不恢复暂存区的 Pop：改动全部回到工作区且未暂存，成功后储藏被删除
        _ = try await repository.runner.run(["reset", "-q", "--hard"])
        _ = try await repository.runner.run(["clean", "-q", "-f"])
        try await stashes.apply(try #require(try await stashes.list().first), restoreIndex: false, drop: true)
        let popped = try await repository.runner.status().entries
        #expect(popped.first { $0.path == "tracked *.txt" }?.staged == nil)
        #expect(popped.first { $0.path == "tracked *.txt" }?.unstaged == .modified)
        #expect(try await stashes.list().isEmpty)
    }

    /// 没有改动时 Git 以 0 退出；储藏服务必须把它当作失败，并保留 Git 的原文。
    @Test("没有可储藏的改动")
    func nothingToSave() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let stashes = RepositoryStashes(runner: repository.runner)

        // 只有未跟踪文件但不包含未跟踪文件时同样没有可储藏的改动
        try write("new\n", to: "untracked.txt", in: repository)

        do {
            try await stashes.save(message: "", includeUntracked: false)
            Issue.record("没有改动时保存应失败")
        } catch StashError.noLocalChanges(let result) {
            #expect(result.exitCode == 0)
            #expect(String(decoding: result.standardOutput, as: UTF8.self).contains("No local changes to save"))
        }

        do {
            try await stashes.snapshot(message: "", includeUntracked: false)
            Issue.record("没有改动时快照应失败")
        } catch StashError.noLocalChanges { }

        #expect(try await stashes.list().isEmpty)
    }

    /// 部分储藏只收入所选文件（含所选的未跟踪文件），通配符按字面匹配，其余改动原样保留。
    @Test("部分储藏")
    func partialStash() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let stashes = RepositoryStashes(runner: repository.runner)

        try write("changed\n", to: "tracked *.txt", in: repository)
        try write("changed\n", to: "tracked x.txt", in: repository)
        try write("new\n", to: "新 [*].txt", in: repository)
        try write("new\n", to: "新 a.txt", in: repository)

        let entries = try await repository.runner.status().entries
        let selected = entries.filter { ["tracked *.txt", "新 [*].txt"].contains($0.path) }
        try await stashes.save(message: "partial", includeUntracked: true, entries: selected)

        let remaining = Set(try await repository.runner.status().entries.map(\.path))
        #expect(remaining == ["tracked x.txt", "新 a.txt"])

        let stash = try #require(try await stashes.list().first)
        let files = try await stashes.changes(in: stash)
        #expect(Set(files.map(\.file.path)) == ["tracked *.txt", "新 [*].txt"])
        #expect(files.first { $0.file.path == "新 [*].txt" }?.isUntracked ?? false)
    }

    /// 快照登记储藏但不改动工作区：全部改动不碰文件，带未跟踪文件或部分快照时内容与状态复原。
    @Test("Snapshot 与部分 Snapshot")
    func snapshots() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let stashes = RepositoryStashes(runner: repository.runner)

        try write("staged\n", to: "tracked *.txt", in: repository)
        _ = try await repository.runner.run(["--literal-pathspecs", "add", "--", "tracked *.txt"])
        try write("unstaged\n", to: "tracked x.txt", in: repository)
        try write("new\n", to: "untracked.txt", in: repository)
        let before = try await repository.runner.status()

        try await stashes.snapshot(message: "全部", includeUntracked: false)
        #expect(try await repository.runner.status() == before)

        let entries = before.entries.filter { ["tracked x.txt", "untracked.txt"].contains($0.path) }
        try await stashes.snapshot(message: "部分", includeUntracked: true, entries: entries)
        #expect(try await repository.runner.status() == before)
        #expect(try read("tracked x.txt", in: repository) == "unstaged\n")

        let list = try await stashes.list()
        #expect(list.map(\.message) == ["部分", "全部"])
        #expect(Set(try await stashes.changes(in: list[1]).map(\.file.path)) == ["tracked *.txt", "tracked x.txt"])

        // Git 的部分储藏总是记下整个暂存区，所选文件之外已暂存的改动也在储藏里
        let partial = Set(try await stashes.changes(in: list[0]).map(\.file.path))
        #expect(partial.isSuperset(of: ["tracked x.txt", "untracked.txt"]))
    }

    /// 冲突时 Git 保留储藏；服务以冲突错误报告，冲突文件留在工作区。
    @Test("应用冲突时保留储藏")
    func applyConflict() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let stashes = RepositoryStashes(runner: repository.runner)

        try write("stashed\n", to: "tracked x.txt", in: repository)
        try await stashes.save(message: "conflict", includeUntracked: false)
        try write("committed\n", to: "tracked x.txt", in: repository)
        _ = try await repository.runner.run(["commit", "-q", "-am", "change"])

        do {
            try await stashes.apply(try #require(try await stashes.list().first), restoreIndex: false, drop: true)
            Issue.record("冲突的 Pop 应报告冲突")
        } catch StashError.conflicts(let result) {
            #expect(result.exitCode == 1)
        }

        #expect(try await stashes.list().count == 1)
        #expect(try await repository.runner.status().entries.contains { $0.kind == .conflicted })
    }

    /// 服务器上可能有终端同时储藏：序号已指向别的储藏时拒绝操作，不误删、不误用。
    @Test("序号变化后拒绝按旧序号操作")
    func changedIndex() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let stashes = RepositoryStashes(runner: repository.runner)

        try write("first\n", to: "tracked x.txt", in: repository)
        try await stashes.save(message: "first", includeUntracked: false)
        let listed = try #require(try await stashes.list().first)

        // 模拟终端里的另一次储藏，旧记录的序号 0 现在指向新储藏
        try write("second\n", to: "tracked x.txt", in: repository)
        _ = try await repository.runner.run(["stash", "push", "-q", "-m", "terminal"])

        await #expect(throws: StashError.self) { try await stashes.drop([listed]) }
        await #expect(throws: StashError.self) { try await stashes.apply(listed, restoreIndex: false, drop: false) }
        #expect(try await stashes.list().map(\.message) == ["terminal", "first"])
        #expect(try await repository.runner.status().entries.isEmpty)
    }

    /// 多选删除从大到小进行，未选的储藏保留。
    @Test("删除多个储藏")
    func dropSeveral() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let stashes = RepositoryStashes(runner: repository.runner)

        for message in ["one", "two", "three"] {
            try write(message + "\n", to: "tracked x.txt", in: repository)
            try await stashes.save(message: message, includeUntracked: false)
        }

        let list = try await stashes.list()
        try await stashes.drop([list[0], list[2]])
        #expect(try await stashes.list().map(\.message) == ["two"])
    }

    /// 只应用储藏中的一个文件：其它文件不动，未跟踪文件同样可以应用；套用不上时整体失败。
    @Test("只应用储藏中的单个文件")
    func applySingleFile() async throws {
        let repository = try await makeRepository()
        defer { repository.remove() }
        let stashes = RepositoryStashes(runner: repository.runner)

        try write("stashed\n", to: "tracked *.txt", in: repository)
        try write("stashed\n", to: "tracked x.txt", in: repository)
        try write("new\n", to: "新 文件.txt", in: repository)
        try await stashes.save(message: "files", includeUntracked: true)

        let stash = try #require(try await stashes.list().first)
        let files = try await stashes.changes(in: stash)
        try await stashes.apply(try #require(files.first { $0.file.path == "tracked *.txt" }), from: stash)
        try await stashes.apply(try #require(files.first { $0.file.path == "新 文件.txt" }), from: stash)

        let entries = try await repository.runner.status().entries
        #expect(Set(entries.map(\.path)) == ["tracked *.txt", "新 文件.txt"])
        #expect(entries.first { $0.path == "tracked *.txt" }?.staged == nil)
        #expect(try read("新 文件.txt", in: repository) == "new\n")

        // 本地改动与储藏冲突时 git apply 失败，工作区保持原样
        try write("local\n", to: "tracked x.txt", in: repository)

        do {
            try await stashes.apply(try #require(files.first { $0.file.path == "tracked x.txt" }), from: stash)
            Issue.record("冲突的单文件应用应失败")
        } catch let error as GitError {
            #expect(error.exitCode == 1)
            #expect(error.message.contains("patch does not apply"))
        }

        #expect(try read("tracked x.txt", in: repository) == "local\n")
    }
}

// MARK: - Helpers

extension RepositoryStashesTests {
    /// 带两个已提交文件的临时仓库，路径含空格与通配符。
    func makeRepository() async throws -> TemporaryRepository {
        let repository = try TemporaryRepository()
        try await repository.initialize()

        try write("base\n", to: "tracked *.txt", in: repository)
        try write("base\n", to: "tracked x.txt", in: repository)
        _ = try await repository.runner.run(["add", "--all"])
        _ = try await repository.runner.run(["commit", "-q", "-m", "root"])
        return repository
    }

    /// 写入仓库内的文件。
    func write(_ content: String, to path: String, in repository: TemporaryRepository) throws {
        try Data(content.utf8).write(to: repository.directory.appending(path: path))
    }

    /// 读取仓库内的文件。
    func read(_ path: String, in repository: TemporaryRepository) throws -> String {
        String(decoding: try Data(contentsOf: repository.directory.appending(path: path)), as: UTF8.self)
    }

    /// 读取固定输出夹具。
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
