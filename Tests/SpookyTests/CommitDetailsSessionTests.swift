import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - CommitDetailsSessionTests

/// 提交详情的界面状态：版本比较的读取与关闭、文件树逐层展开、签名请求的合并，以及历史右键菜单的条目。
@MainActor
struct CommitDetailsSessionTests {
    /// 版本比较读取目标独有的提交与改动，关闭后迟到的结果不能写回；文件树只在展开目录时读取下一层；
    /// 同一轮里的签名请求合并成一次查询，清空后不再保留结果。
    @Test("版本比较、文件树与签名的读取状态")
    func detailStates() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))

        let nested = try await commit(runner, directory: directory, file: "目录 一/文件 '二'.txt", content: "x\n")
        let base = try await commit(runner, directory: directory, file: "比较 [*].txt", content: "one\n")
        let target = try await commit(runner, directory: directory, file: "比较 [*].txt", content: "one\ntwo\n")

        await checkComparison(runner, base: base, target: target)
        try await checkTree(runner, commit: nested)

        let store = CommitSignatureStore()
        store.request(base, runner: runner)
        store.request(target, runner: runner)

        // 签名查询的任务不对外暴露，只能等结果到达
        await until { store.signatures.count == 2 }
        #expect(store.signatures.values.allSatisfy { $0.status == .unsigned })

        store.reset()
        #expect(store.signatures.isEmpty)
    }

    /// 单个提交有保存补丁、导出与比较；两个提交直接比较且 ⌥ 反向；其余数量打开比较对话框。
    @Test("历史右键菜单的保存补丁、导出与比较")
    func menu() throws {
        let session = RepositorySession()
        let commits = (0 ..< 3).map { index in
            HistoryCommit(
                id: String(repeating: String(index), count: 40),
                tree: String(repeating: "f", count: 40),
                parents: [],
                author: "A",
                authorEmail: "a@example.invalid",
                authorDate: Date(),
                committer: "A",
                committerEmail: "a@example.invalid",
                commitDate: Date(),
                message: "m"
            )
        }

        // 这一组排在菜单最后，前面是一条分隔线
        let single = HistoryCommitMenu.items(for: [commits[0]], session: session) { _ in }
        #expect(single.first?.isSeparatorItem ?? false)
        #expect(single.dropLast(4).last?.isSeparatorItem ?? false)
        #expect(single.suffix(4).map(\.title) == [
            AppLocalization.text("patch.menu", "00000000"),
            AppLocalization.text("patch.quickMenu", "00000000"),
            AppLocalization.text("export.menuFrom", "00000000"),
            AppLocalization.text("compare.menuFrom", "00000000"),
        ])

        let quick = single[single.count - 3]
        #expect(quick.isAlternate && quick.keyEquivalentModifierMask == .option)

        // 列表从新到旧，默认从较早的比较到较新的
        let pair = HistoryCommitMenu.items(for: Array(commits.prefix(2)), session: session) { _ in }
        let titles = pair.filter { !$0.isSeparatorItem }.map(\.title)

        #expect(titles.suffix(2) == [
            AppLocalization.text("compare.menuPair", "11111111", "00000000"),
            AppLocalization.text("compare.menuPair", "00000000", "11111111"),
        ])

        #expect(pair.last?.isAlternate ?? false)

        let many = HistoryCommitMenu.items(for: commits, session: session) { _ in }
        #expect(many.last?.title == AppLocalization.text("compare.menu"))
        #expect(HistoryCommitMenu.items(for: [], session: session) { _ in }.isEmpty)
    }
}

// MARK: - Steps

extension CommitDetailsSessionTests {
    /// 比较只列出目标独有的提交与改动，展开后补丁从基准读起；关闭后清空全部状态，再读取也不会写回。
    private func checkComparison(_ runner: GitRunner, base: String, target: String) async {
        let path = "比较 [*].txt"
        let state = RevisionComparisonState()

        state.open(
            base: RevisionComparisonState.Side(id: base, title: "base"),
            target: RevisionComparisonState.Side(id: target, title: "target"),
            runner: runner
        )

        await until { !state.isLoadingCommits && !state.isLoadingChanges }
        #expect(state.commits.map(\.id) == [target])
        #expect(state.changes.map(\.path) == [path])

        // 补丁的读取任务不对外暴露，等它读到补丁或失败
        state.expandAll(true)
        await until { state.diffs[path] != nil || state.diffFailures[path] != nil }

        #expect(state.diffSource(path: path)?.base == base)
        #expect(state.diffFailures.isEmpty)

        state.close()
        state.loadCommits()

        #expect(!state.isActive)
        #expect(state.commits.isEmpty && state.changes.isEmpty && state.diffs.isEmpty)
    }

    /// 打开提交时只读顶层，展开目录后下一层按层级缩进，收起后只剩顶层。
    private func checkTree(_ runner: GitRunner, commit id: String) async throws {
        let page = try await RepositoryHistory(runner: runner).page(roots: [id], limit: 1)
        let commit = try #require(page.commits.first)

        let tree = CommitTreeState()
        await tree.open(commit, runner: runner)
        #expect(tree.rows.map(\.entry.path) == ["目录 一"])

        let folder = try #require(tree.rows.first?.entry)
        await tree.toggle(folder, runner: runner)

        #expect(tree.rows.map(\.depth) == [0, 1])
        #expect(tree.rows.last?.entry.path == "目录 一/文件 '二'.txt")

        await tree.toggle(folder, runner: runner)
        #expect(tree.rows.count == 1)
    }
}

// MARK: - Helpers

extension CommitDetailsSessionTests {
    /// 写入一个文件并提交，返回提交哈希。
    private func commit(
        _ runner: GitRunner,
        directory: URL,
        file: String,
        content: String
    ) async throws -> String {
        let url = directory.appending(path: file)

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(content.utf8).write(to: url)

        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", file])

        return try await RepositoryReferences(runner: runner).resolve("HEAD")
    }
}
