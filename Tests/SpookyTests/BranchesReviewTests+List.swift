import AppKit
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - List

extension BranchesReviewTests {
    /// 列表的规则：行变化后没有仍在列表里的选中时选第一行；读屏的超前 / 落后一个提交时用单数；
    /// 基准菜单先列当前基准、分隔线，再列其它分支，过滤只留匹配的分支；轻扫删除对当前分支只发提示音。
    func checkListRules(session: RepositorySession) throws {
        let review = session.branchesReview
        let ids = review.items(
            conditions: [:],
            search: "",
            order: BranchesReviewOrder(filter: .all, sort: .name, ascending: true),
            staleMonths: 3
        )
        .map(\.id)

        try #require(ids.count == 3)

        // 自动选中：没有选中时选第一行，仍有选中的行在列表里时不动
        review.selectedIDs = []
        review.selectFirstIfNeeded(in: ids)
        #expect(review.selectedIDs == [ids[0]])

        review.selectedIDs = [ids[1]]
        review.selectFirstIfNeeded(in: ids)
        #expect(review.selectedIDs == [ids[1]])

        // 所选的行不在新的行里（如它成了基准）时改选新的第一行
        review.selectFirstIfNeeded(in: Array(ids.dropFirst(2)))
        #expect(review.selectedIDs == [ids[2]])

        // 读屏文字：一个提交用单数键，其它用复数键
        #expect(
            BranchesReviewRow.countsLabel(ReferenceDivergence(ahead: 1, behind: 2))
                == AppLocalization.text(
                    "review.counts",
                    AppLocalization.text("review.ahead.one"),
                    AppLocalization.text("review.behind", 2)
                )
        )

        try checkBaseMenu(session: session)
        try checkSwipeDelete(session: session)
    }
}

// MARK: - Helpers

extension BranchesReviewTests {
    /// 基准菜单：顶部过滤框，当前基准、分隔线，其它本地分支按原顺序；过滤后只留名字含这段文字的分支。
    private func checkBaseMenu(session: RepositorySession) throws {
        let branches = session.history.branches.filter(\.isLocal)
        let base = try #require(session.branchesReview.base)
        let menu = BranchesReviewBaseMenu()

        menu.rebuild(branches: branches, base: base)

        let items = menu.menu.items
        #expect(items.first?.view != nil)

        #expect(
            items.dropFirst().map { $0.isSeparatorItem ? "|" : $0.title }
                == [base.name, "|"] + branches.filter { $0.id != base.id }.map(\.name)
        )

        menu.filter("CON")
        #expect(items.dropFirst().filter { !$0.isHidden }.map(\.title) == ["conflict"])

        menu.filter("")
        #expect(items.allSatisfy { !$0.isHidden })
    }

    /// 轻扫删除：当前分支不打开删除确认，其它分支打开与右键删除相同的确认。
    private func checkSwipeDelete(session: RepositorySession) throws {
        var targets: [[String]] = []
        session.onReferenceRequest = { request in
            if case .deleteBranches(let references) = request {
                targets.append(references.map(\.name))
            }
        }

        let list = BranchesReviewListView(session: session) { _ in }
        let head = try #require(session.headBranch)
        let conflict = try #require(session.history.branches.first { $0.name == "conflict" })

        list.deleteBySwipe(head)
        list.deleteBySwipe(conflict)

        #expect(targets == [["conflict"]])
    }
}
