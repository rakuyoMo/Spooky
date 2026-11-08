import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SubmoduleRevisionMenuTests

/// 子模块的 Checkout Revision 子菜单：分离 HEAD 时先列出检出的提交，分支与标签各成一组、带不可选的组名，
/// 组间才有分隔线；一项都没有时只有 No revisions。
@MainActor
struct SubmoduleRevisionMenuTests {
    /// 检出的提交。
    private let commit = String(repeating: "a", count: 40)

    /// 当前所在的分支。
    private let main = SubmoduleRevision(reference: "refs/heads/main", isCurrent: true)

    /// 另一个分支。
    private let feature = SubmoduleRevision(reference: "refs/heads/特性", isCurrent: false)

    /// 一个标签。
    private let tag = SubmoduleRevision(reference: "refs/tags/v1", isCurrent: false)

    /// 停在分支上：两组各带组名，中间一条分隔线，没有分离 HEAD 的一项；
    /// 分离 HEAD 且不在标签上时，检出的提交排在最上面，与下面的分支组隔开；停在标签上时这个标签是当前版本，不单列提交；
    /// 只有一组时没有分隔线；读不到版本时既不列提交也没有组，只有 No revisions。
    @Test("子菜单的分组、分离 HEAD 与读不到版本")
    func menuItems() {
        let onBranch = SubmoduleRevisionMenu.items(revisions: [main, feature, tag], checkedOut: commit)

        #expect(
            onBranch == [.branchesHeader, .revision(main), .revision(feature), .separator, .tagsHeader, .revision(tag)]
        )

        // 分离 HEAD
        let branch = SubmoduleRevision(reference: "refs/heads/main", isCurrent: false)
        let elsewhere = SubmoduleRevisionMenu.items(revisions: [branch, tag], checkedOut: commit)

        #expect(
            elsewhere == [
                .detached(commit),
                .separator,
                .branchesHeader,
                .revision(branch),
                .separator,
                .tagsHeader,
                .revision(tag),
            ]
        )

        let currentTag = SubmoduleRevision(reference: "refs/tags/v1", isCurrent: true)
        let onTag = SubmoduleRevisionMenu.items(revisions: [branch, currentTag], checkedOut: commit)

        #expect(onTag == [.branchesHeader, .revision(branch), .separator, .tagsHeader, .revision(currentTag)])

        // 只有一组
        let branchesOnly = SubmoduleRevisionMenu.items(revisions: [main], checkedOut: commit)
        let tagsOnly = SubmoduleRevisionMenu.items(revisions: [tag], checkedOut: commit)

        #expect(branchesOnly == [.branchesHeader, .revision(main)])
        #expect(tagsOnly == [.detached(commit), .separator, .tagsHeader, .revision(tag)])

        // 读不到版本
        #expect(SubmoduleRevisionMenu.items(revisions: nil, checkedOut: commit) == [.empty])
        #expect(SubmoduleRevisionMenu.items(revisions: [], checkedOut: nil) == [.empty])
    }
}
