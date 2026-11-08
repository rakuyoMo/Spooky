import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Commit Selector

extension HistoryListTests {
    /// 版本选择器从 HEAD 起每次读 50 条，滚到最后一行续载，读到不满一页为止；↑ ↓ 逐行移动高亮，到两端停住；
    /// 搜索框的内容按正则匹配提交说明、忽略大小写，编译不了时列表为空、不报错；清空后回到第一页。
    @Test("整页详情的版本选择器分页、高亮与搜索")
    func commitSelector() async throws {
        let fixture = try await Self.makeSession(commits: (0 ..< 120).map { "commit \($0)" })
        defer { fixture.close() }

        let head = try #require(fixture.session.status?.branch.oid)
        let selector = CommitSelectorState()
        selector.open(runner: fixture.runner, head: head)
        await until { !selector.isLoading }

        // 第一页从 HEAD 开始，打开时高亮 HEAD
        #expect(selector.commits.count == CommitSelectorState.pageSize)
        #expect(selector.commits.first?.id == head)
        #expect(selector.highlightedID == head)
        #expect(selector.hasMore)

        // 第一行再往上不动，往下逐行移动，移到已读到的最后一行后停住
        selector.moveHighlight(by: -1)
        #expect(selector.highlightedID == head)

        selector.moveHighlight(by: 1)
        selector.moveHighlight(by: 1)
        #expect(selector.highlightedID == selector.commits[2].id)

        selector.moveHighlight(by: CommitSelectorState.pageSize)
        #expect(selector.highlightedID == selector.commits.last?.id)

        // 续载到 100、120 后读到不满一页，不再续载
        selector.loadNextPage()
        await until { !selector.isLoading }
        #expect(selector.commits.count == 100)

        selector.loadNextPage()
        await until { !selector.isLoading }
        #expect(selector.commits.count == 120)
        #expect(!selector.hasMore)
        #expect(try #require(selector.commits.last).parents.isEmpty)

        selector.loadNextPage()
        #expect(!selector.isLoading)

        await searchCommitSelector(selector, all: selector.commits)
    }

    /// 版本选择器的搜索：按正则匹配提交说明、忽略大小写，高亮的提交不在结果里时高亮第一行；
    /// 编译不了的正则列表为空、不报错；清空后回到第一页，高亮的提交仍在第一页里就保留。
    ///
    /// - Parameters:
    ///   - selector: 已读完全部 120 个提交、高亮停在第一页最后一行的选择器。
    ///   - all: 选择器读到的全部提交。
    private func searchCommitSelector(_ selector: CommitSelectorState, all: [HistoryCommit]) async {
        // 点号匹配任一字符，大小写不同也命中：只剩 commit 119 与 commit 109
        await search(selector, for: "COMMIT 1.9")
        #expect(selector.commits.map(\.subject) == ["commit 119", "commit 109"])
        #expect(!selector.hasMore)
        #expect(selector.highlightedID == selector.commits.first?.id)

        // 编译不了的正则：列表为空，没有失败，也没有可移动的高亮
        await search(selector, for: "x[")
        #expect(selector.commits.isEmpty)
        #expect(selector.failure == nil)
        #expect(!selector.hasMore)
        #expect(selector.highlightedID == nil)

        selector.moveHighlight(by: 1)
        #expect(selector.highlightedID == nil)

        // 只按提交说明过滤，高亮第一行
        let matching = all.filter { $0.message.localizedCaseInsensitiveContains("commit 7") }

        await search(selector, for: "COMMIT 7")
        #expect(selector.commits.map(\.id) == matching.map(\.id))
        #expect(selector.commits.count == 11)
        #expect(selector.highlightedID == matching.first?.id)

        // 清空后回到第一页，高亮的提交仍在第一页里就保留
        await search(selector, for: "")
        #expect(selector.commits.map(\.id) == all.prefix(CommitSelectorState.pageSize).map(\.id))
        #expect(selector.hasMore)
        #expect(selector.highlightedID == matching.first?.id)

        selector.close()
        #expect(selector.commits.isEmpty)
        #expect(selector.highlightedID == nil)
    }

    /// 在版本选择器里搜索，等停顿后的重读交出结果。
    ///
    /// 停顿期间列表保持原样，重读开始时清空列表并进入读取，读完时一并写入结果、退出读取；
    /// 列表变了且不在读取中，就是这次重读读完了。
    private func search(_ selector: CommitSelectorState, for text: String) async {
        let previous = selector.commits
        selector.search(text)
        await until { selector.commits != previous && !selector.isLoading }
    }
}
