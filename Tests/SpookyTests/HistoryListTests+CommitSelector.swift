import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Commit Selector

extension HistoryListTests {
    /// 版本选择器从 HEAD 起每次读 50 条，滚到最后一行续载，读到不满一页为止；搜索按提交说明忽略大小写过滤，清空后回到第一页。
    @Test("整页详情的版本选择器分页与搜索")
    func commitSelector() async throws {
        let fixture = try await Self.makeSession(commits: (0 ..< 120).map { "commit \($0)" })
        defer { fixture.close() }

        let head = try #require(fixture.session.status?.branch.oid)
        let selector = CommitSelectorState()
        selector.open(runner: fixture.runner, head: head)
        try await FileViewsTests.wait { !selector.isLoading && !selector.commits.isEmpty }

        // 第一页从 HEAD 开始，打开时高亮 HEAD
        #expect(selector.commits.count == CommitSelectorState.pageSize)
        #expect(selector.commits.first?.id == head)
        #expect(selector.highlightedID == head)
        #expect(selector.hasMore)

        // 续载到 100、120 后读到不满一页，不再续载
        selector.loadNextPage()
        try await FileViewsTests.wait { !selector.isLoading }
        #expect(selector.commits.count == 100)

        selector.loadNextPage()
        try await FileViewsTests.wait { !selector.isLoading }
        #expect(selector.commits.count == 120)
        #expect(!selector.hasMore)
        #expect(try #require(selector.commits.last).parents.isEmpty)

        selector.loadNextPage()
        #expect(!selector.isLoading)

        // 搜索只按提交说明过滤，大小写不同也命中
        let all = selector.commits
        let matching = all.filter { $0.message.localizedCaseInsensitiveContains("commit 7") }

        selector.search("COMMIT 7")
        try await FileViewsTests.wait { !selector.isLoading && selector.commits.count < all.count }
        #expect(selector.commits.map(\.id) == matching.map(\.id))
        #expect(selector.commits.count == 11)
        #expect(!selector.hasMore)

        // HEAD 不在结果里时高亮第一行
        #expect(selector.highlightedID == matching.first?.id)

        // 清空后回到第一页，高亮的提交仍在第一页里就保留
        selector.search("")
        try await FileViewsTests.wait { !selector.isLoading && selector.commits.count == CommitSelectorState.pageSize }
        #expect(selector.commits.map(\.id) == all.prefix(CommitSelectorState.pageSize).map(\.id))
        #expect(selector.hasMore)
        #expect(selector.highlightedID == matching.first?.id)

        selector.close()
        #expect(selector.commits.isEmpty)
        #expect(selector.highlightedID == nil)
    }

    /// ↑ ↓ 逐行移动高亮，到两端停住；搜索框的内容按基本正则匹配说明，编译不了时列表为空、不报错。
    @Test("版本选择器的高亮移动与正则搜索")
    func commitSelectorKeyboardAndRegex() async throws {
        let fixture = try await Self.makeSession(commits: (0 ..< 120).map { "commit \($0)" })
        defer { fixture.close() }

        let head = try #require(fixture.session.status?.branch.oid)
        let selector = CommitSelectorState()
        selector.open(runner: fixture.runner, head: head)
        try await FileViewsTests.wait { !selector.isLoading && !selector.commits.isEmpty }

        // 第一行再往上不动，往下逐行移动
        selector.moveHighlight(by: -1)
        #expect(selector.highlightedID == head)

        selector.moveHighlight(by: 1)
        selector.moveHighlight(by: 1)
        #expect(selector.highlightedID == selector.commits[2].id)

        // 移到已读到的最后一行后停住
        for _ in 0 ..< CommitSelectorState.pageSize {
            selector.moveHighlight(by: 1)
        }

        #expect(selector.highlightedID == selector.commits.last?.id)

        // 点号匹配任一字符：只剩 commit 119 与 commit 109
        selector.search("COMMIT 1.9")
        try await FileViewsTests.wait { !selector.isLoading && selector.commits.count == 2 }
        #expect(selector.commits.map(\.subject) == ["commit 119", "commit 109"])
        #expect(selector.highlightedID == selector.commits.first?.id)

        // 编译不了的正则：列表为空，没有失败，也没有可移动的高亮
        selector.search("x[")
        try await FileViewsTests.wait { !selector.isLoading && selector.commits.isEmpty }
        #expect(selector.failure == nil)
        #expect(!selector.hasMore)
        #expect(selector.highlightedID == nil)

        selector.moveHighlight(by: 1)
        #expect(selector.highlightedID == nil)

        selector.close()
    }
}
