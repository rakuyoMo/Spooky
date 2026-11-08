import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Base Branch

extension BranchesReviewTests {
    /// 没选基准时按 next、develop、dev、main、master 取第一个存在的分支，trunk 不在其中；都没有时取当前分支。
    @Test("分支整理的默认基准")
    func reviewDefaultBase() {
        let base = { (names: [String]) -> String? in
            let review = BranchesReviewState()

            // 当前分支 work 的引用名排在 alpha 之后，用来区分 “当前分支” 与 “第一个本地分支”
            let references = (names + ["alpha", "work"])
                .sorted()
                .map { reference("refs/heads/" + $0, date: nil) }

            review.update(
                snapshot: ReferenceSnapshot(references: references, remotes: []),
                head: "work",
                runner: nil
            )

            return review.base?.name
        }

        #expect(base(["main", "master", "trunk", "dev", "develop", "next"]) == "next")
        #expect(base(["main", "master", "trunk", "dev", "develop"]) == "develop")
        #expect(base(["main", "master", "trunk", "dev"]) == "dev")
        #expect(base(["main", "master", "trunk"]) == "main")
        #expect(base(["master", "trunk"]) == "master")
        #expect(base(["trunk"]) == "work")
        #expect(base([]) == "work")
    }
}
