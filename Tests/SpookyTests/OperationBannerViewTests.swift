import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - OperationBannerViewTests

/// 进行中操作横幅的计数与提示：按操作种类与阶段选出的文字决定用户下一步点哪个按钮。
@MainActor
struct OperationBannerViewTests {
    /// 出现过冲突的操作从 0 个已解决开始写括号；从没有冲突的操作只写没有未解决的冲突。
    @Test("冲突计数的四种状态")
    func conflictSummary() {
        let none = AppLocalization.text("conflict.unresolved.none")
        let one = AppLocalization.text("conflict.unresolved.one")
        let three = AppLocalization.text("working.conflicts", 3)

        /// 在基础计数后接已解决的数量。
        func resolved(_ base: String, _ count: Int) -> String {
            AppLocalization.text("conflict.resolvedSuffix", base, count)
        }

        #expect(OperationBannerView.conflictSummary(unresolved: 3, resolved: 0) == resolved(three, 0))
        #expect(OperationBannerView.conflictSummary(unresolved: 1, resolved: 2) == resolved(one, 2))
        #expect(OperationBannerView.conflictSummary(unresolved: 0, resolved: 3) == resolved(none, 3))

        // 例如 merge --no-commit：没有冲突记录，不带括号
        #expect(OperationBannerView.conflictSummary(unresolved: 0, resolved: 0) == none)
    }

    /// 合并、压缩合并与单个提交的操作以 Commit 收尾，序列与变基以 Continue 收尾；edit 与尚未开始的交互式变基不分阶段。
    @Test("提示按操作种类与阶段选择")
    func hintKeys() throws {
        let finishing: [[String: String]] = [
            ["MERGE_HEAD": "eeee\n"],
            ["SQUASH_MSG": "Squashed\n"],
            ["CHERRY_PICK_HEAD": "aaaa\n"],
            ["REVERT_HEAD": "aaaa\n"],
        ]

        let sequences: [[String: String]] = [
            ["sequencer/todo": "pick aaaa one\n", "CHERRY_PICK_HEAD": "aaaa\n"],
            ["sequencer/todo": "revert aaaa one\n", "REVERT_HEAD": "aaaa\n"],
        ]

        let rebases: [[String: String]] = [
            [
                "rebase-merge/head-name": "refs/heads/feature",
                "rebase-merge/done": "pick aaaa one\n",
                "rebase-merge/stopped-sha": "aaaa\n",
            ],
            ["rebase-apply/head-name": "refs/heads/feature"],
        ]

        for files in finishing {
            try expectKeys(files, group: "merge")
        }

        for files in sequences {
            try expectKeys(files, group: "sequence")
        }

        for files in rebases {
            try expectKeys(files, group: "rebase")
        }

        let editing = try progress([
            "rebase-merge/head-name": "refs/heads/feature",
            "rebase-merge/done": "edit aaaa one\n",
            "rebase-merge/amend": "aaaa\n",
            "rebase-merge/stopped-sha": "aaaa\n",
        ])

        let pending = try progress([
            "rebase-merge/head-name": "refs/heads/feature",
            "rebase-merge/interactive": "",
        ])

        for phase in [OperationBannerView.Phase.conflicts, .resolved, .empty] {
            #expect(OperationBannerView.hintKey(editing, phase: phase) == "conflict.hint.rebase.edit")
            #expect(OperationBannerView.hintKey(pending, phase: phase) == "conflict.hint.rebase.pending")
        }
    }
}

// MARK: - Private

extension OperationBannerViewTests {
    /// 由状态文件解析出进行中的操作。
    private func progress(_ files: [String: String]) throws -> OperationProgress {
        try #require(OperationProgress(files: files, head: "cccc"))
    }

    /// 三个阶段依次取到同一组提示里的对应资源键。
    private func expectKeys(_ files: [String: String], group: String) throws {
        let progress = try progress(files)

        #expect(OperationBannerView.hintKey(progress, phase: .conflicts) == "conflict.hint.\(group).conflicts")
        #expect(OperationBannerView.hintKey(progress, phase: .resolved) == "conflict.hint.\(group).resolved")
        #expect(OperationBannerView.hintKey(progress, phase: .empty) == "conflict.hint.\(group).empty")
    }
}
