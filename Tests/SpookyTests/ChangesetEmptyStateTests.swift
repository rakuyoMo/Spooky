import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

/// 空变更集保留零摘要，失败不能显示为成功的空结果。
@MainActor
struct ChangesetEmptyStateTests {
    /// Git 对象读取失败时，整页列表不显示成功空结果的占位行。
    @Test("整页详情读取失败隐藏空行")
    func failedChanges() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "Empty"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let commit = try #require(try await RepositoryHistory(runner: runner).page(roots: [head], limit: 1).commits.first)
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        session.display(location)
        session.refresh()
        await session.waitForRefresh()
        try await FileViewsTests.wait { session.history.commits.contains { $0.id == head } }

        // 对象在历史读取后消失，尚未读取过的变更集必须报告失败。
        let objects = directory.appending(path: ".git/objects")
        let saved = directory.appending(path: "saved-objects")
        try FileManager.default.moveItem(at: objects, to: saved)
        defer { try? FileManager.default.moveItem(at: saved, to: objects) }

        session.history.show(commit, runner: runner)
        try await FileViewsTests.wait { !session.history.isLoadingChanges }
        #expect(session.history.changesFailure != nil)
        #expect(session.history.changes.isEmpty)
        #expect(CommitFileListView(session: session, history: session.history, back: { }).emptyMessage == nil)
    }

    /// 相同版本比较与树未改变的储藏都实际渲染零摘要，不再增加文本 Diff 空提示。
    @Test("空比较与空储藏只显示零摘要", .enabled(if: AXIsProcessTrusted()))
    func emptyDetails() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        _ = try await runner.run(["commit", "--allow-empty", "-m", "Base"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let tree = try await objectID(["rev-parse", "HEAD^{tree}"], runner: runner)
        let index = try await objectID(["commit-tree", tree, "-p", head, "-m", "Index"], runner: runner)
        let stash = try await objectID(["commit-tree", tree, "-p", head, "-p", index, "-m", "Empty stash"], runner: runner)
        _ = try await runner.run(["stash", "store", "-m", "Empty stash", stash])
        let session = RepositorySession()
        defer { session.close() }

        session.comparison.open(base: .init(id: head, title: "base"), target: .init(id: head, title: "target"), runner: runner)
        session.comparison.showsChangeset = true
        session.stashes.refresh(runner: runner)
        try await FileViewsTests.wait { session.stashes.isLoaded && !session.comparison.isLoadingChanges }
        session.stashes.selectedIDs = [stash]
        try await FileViewsTests.wait { !session.stashes.isLoadingChanges }
        #expect(session.comparison.failure == nil && session.comparison.changes.isEmpty)
        #expect(session.stashes.changesFailure == nil && session.stashes.changes.isEmpty)

        assertEmpty { RevisionComparisonView(state: session.comparison, session: session) }
        assertEmpty { StashDetailView(session: session) }
    }

    /// 加载组件的实际辅助功能位置与尺寸保持文件行的规格。
    @Test("变更集加载行的转圈与文字位置", .enabled(if: AXIsProcessTrusted()))
    func loadingGeometry() throws {
        let elements = AccessibilityProbe.elements(until: { $0.contains { $0.role == "AXBusyIndicator" } }) {
            ChangesetDiffLoadingView()
        }
        let spinner = try #require(elements.first { $0.role == "AXBusyIndicator" })
        let text = try #require(elements.first { $0.value == AppLocalization.text("working.loadingDiff") })
        let container = try #require(elements.first { $0.role == "AXGroup" })
        #expect(container.frame.height == 32)
        #expect(spinner.frame.width == 16 && spinner.frame.height == 16)
        #expect(spinner.frame.minX == 3)
        #expect(text.frame.minX == 25)
        #expect(spinner.frame.midY == text.frame.midY)
    }

    /// 读取 Git 输出的对象哈希，去掉命令末尾换行。
    private func objectID(_ arguments: [String], runner: GitRunner) async throws -> String {
        let output = try await runner.run(arguments)
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 直接呈现生产视图，检查已完成空结果的全部可见文字与按钮。
    private func assertEmpty(@ViewBuilder content: () -> some View) {
        let summary = ChangesetSummaryBar.summary([])
        let elements = AccessibilityProbe.elements(width: 800, until: { $0.contains { $0.value == summary } }, of: content)
        #expect(elements.contains { $0.value == summary })
        #expect(!elements.contains { $0.value == AppLocalization.text("working.noDiff") })
        #expect(!elements.contains { $0.name == AppLocalization.text("history.expandAll") })
    }
}
