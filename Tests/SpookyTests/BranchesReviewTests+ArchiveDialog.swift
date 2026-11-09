import AppKit
import ApplicationServices
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - ArchiveDialog

extension BranchesReviewTests {
    /// 当前检出的陈旧分支同样是归档建议。对话框每次打开都一个不勾、Archive 不可用，Select All 勾上全部并更新计数；
    /// 取消不归档；提交时已被置顶的候选不再归档，其余只记归档标记，HEAD、分支的提交、索引与工作区都不变。
    ///
    /// 勾选框与计数是 SwiftUI 控件，经辅助功能接口读与按；进程没有辅助功能权限时跳过。
    @Test(
        "归档对话框：初始空选、全选与计数、取消与失效的候选",
        .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限")
    )
    func archiveDialog() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-archive-dialog-" + UUID().uuidString)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        let file = directory.appending(path: "a.txt")

        try Data("base\n".utf8).write(to: file)
        _ = try await runner.run(["add", "a.txt"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])

        try await Self.addStaleBranches(["old-a", "old-b"], runner: runner)

        // HEAD 在陈旧的 old-a 上，索引与工作区各有一处改动
        _ = try await runner.run(["switch", "-q", "old-a"])
        try Data("staged\n".utf8).write(to: file)
        _ = try await runner.run(["add", "a.txt"])
        try Data("unstaged\n".utf8).write(to: file)

        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        defer { session.close() }

        session.display(location)
        session.refresh()
        await waitForWrite(session)

        let candidates = session.archiveCandidates(automatic: false)
        #expect(candidates.map(\.id) == ["refs/heads/old-a", "refs/heads/old-b"])

        await checkSelection(session: session, candidates: candidates)
        try await checkCancelAndSubmit(session: session, candidates: candidates, runner: runner, file: file)
    }
}

// MARK: - Steps

extension BranchesReviewTests {
    /// 打开时一个不勾、Archive 不可用、计数为 0；每行写着陈旧的原因。按 Select All 后全部勾上，Archive 可用，计数为全部。
    private func checkSelection(session: RepositorySession, candidates: [RepositoryReference]) async {
        let selectAll = AppLocalization.text("menu.selectAll")
        let archive = AppLocalization.text("review.archive.submit")

        let opened = await Self.dialogElements(session: session, candidates: candidates, pressing: []) {
            Self.branchBoxes(in: $0).count == candidates.count + 1
        }

        let rows = Self.branchBoxes(in: opened).filter { $0.name != selectAll }

        #expect(Self.branchBoxes(in: opened).allSatisfy { $0.value == "0" })
        #expect(rows.map(\.name) == candidates.map { $0.name + ", " + AppLocalization.text("review.filter.stale") })
        #expect(opened.contains { $0.role == "AXButton" && $0.name == archive && !$0.isEnabled })
        #expect(opened.contains { $0.value == AppLocalization.text("review.archive.selection", 0, candidates.count) })

        // Select All 勾上全部分支
        let selected = await Self.dialogElements(session: session, candidates: candidates, pressing: [selectAll]) {
            let boxes = Self.branchBoxes(in: $0)
            return boxes.count == candidates.count + 1 && boxes.allSatisfy { $0.value == "1" }
        }

        let count = AppLocalization.text("review.archive.selection", candidates.count, candidates.count)

        #expect(selected.contains { $0.role == "AXButton" && $0.name == archive && $0.isEnabled })
        #expect(selected.contains { $0.value == count })
    }

    /// 取消不归档；提交时已被置顶的 old-b 不再归档，old-a 记上归档标记，HEAD、提交、索引与工作区都不变。
    private func checkCancelAndSubmit(
        session: RepositorySession,
        candidates: [RepositoryReference],
        runner: GitRunner,
        file: URL
    ) async throws {
        let tip = try await runner.run(["rev-parse", "refs/heads/old-a"])
        let index = try await runner.run(["ls-files", "-s", "a.txt"])
        var closed = 0

        _ = await Self.dialogElements(
            session: session,
            candidates: candidates,
            pressing: [AppLocalization.text("action.cancel")],
            close: { closed += 1 },
            until: { _ in closed == 1 }
        )

        #expect(session.writeTask == nil)
        #expect(session.history.snapshot?.metadata.isEmpty ?? false)

        // 对话框开着时 old-b 被置顶，它已不是归档建议
        session.setPinned(true, branches: [candidates[1]])
        await waitForWrite(session)

        _ = await Self.dialogElements(
            session: session,
            candidates: candidates,
            pressing: [AppLocalization.text("menu.selectAll"), AppLocalization.text("review.archive.submit")],
            close: { closed += 1 },
            until: { _ in closed == 2 }
        )

        await waitForWrite(session)

        let metadata = { session.history.snapshot?.metadata(for: $0) }

        #expect(metadata("refs/heads/old-a") == BranchMetadata(isArchived: true))
        #expect(metadata("refs/heads/old-b") == BranchMetadata(isPinned: true))
        #expect(session.branchesReview.archivedBranches == ["refs/heads/old-a"])

        // 归档只写分支配置
        #expect(session.status?.branch.head == "old-a")
        #expect(try await runner.run(["rev-parse", "refs/heads/old-a"]) == tip)
        #expect(try await runner.run(["ls-files", "-s", "a.txt"]) == index)
        #expect(try String(contentsOf: file, encoding: .utf8) == "unstaged\n")
    }
}

// MARK: - Helpers

extension BranchesReviewTests {
    /// 在 main 上为每个名字建一个提交时间在 2000 年的分支，按顶端提交的时间判断一定陈旧；不动 HEAD 与工作区。
    private static func addStaleBranches(_ names: [String], runner: GitRunner) async throws {
        let date = "2000-01-01T00:00:00Z"

        let dated = GitRunner(
            location: runner.location,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_AUTHOR_DATE": date,
                "GIT_COMMITTER_DATE": date,
            ])
        )

        for name in names {
            let output = try await dated.run(["commit-tree", "-p", "main", "-m", name, "main^{tree}"])
            let commit = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

            _ = try await dated.run(["branch", name, commit])
        }
    }

    /// 把归档对话框放进窗口，依次按下这些控件，读到满足条件为止。
    private static func dialogElements(
        session: RepositorySession,
        candidates: [RepositoryReference],
        pressing names: [String],
        close: @escaping () -> Void = { },
        until isComplete: @escaping ([AccessibilityProbe.Element]) -> Bool
    ) async -> [AccessibilityProbe.Element] {
        await AccessibilityProbe.elements(pressing: names, until: isComplete) {
            ArchiveBranchesDialog(session: session, automatic: false, candidates: candidates, close: close)
        }
    }

    /// 列表里的勾选框，从上到下：Select All 与各分支，不含下面的自动归档开关。
    private static func branchBoxes(in elements: [AccessibilityProbe.Element]) -> [AccessibilityProbe.Element] {
        let automatic = AppLocalization.text("review.archive.auto")

        return elements
            .filter { $0.role == "AXCheckBox" && $0.name != automatic }
            .sorted { $0.frame.minY < $1.frame.minY }
    }
}
