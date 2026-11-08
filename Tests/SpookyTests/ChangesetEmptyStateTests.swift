import AppKit
import ApplicationServices
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - ChangesetEmptyStateTests

/// 空变更集保留零摘要，失败不能显示为成功的空结果。
///
/// 文字与转圈的位置经辅助功能接口读取，进程没有辅助功能权限时跳过。
@MainActor
struct ChangesetEmptyStateTests {
    /// Git 对象读取失败时，整页详情的列表报告失败，不显示成功空结果的占位行。
    @Test("整页详情读取失败隐藏空行")
    func failedChanges() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        _ = try await runner.run(["commit", "--allow-empty", "-m", "Empty"])

        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let page = try await RepositoryHistory(runner: runner).page(roots: [head], limit: 1)
        let commit = try #require(page.commits.first)

        let session = RepositorySession()
        defer { session.close() }

        // 对象在历史读取后消失，尚未读取过的变更集报告失败
        let objects = directory.appending(path: ".git/objects")
        let saved = directory.appending(path: "saved-objects")

        try FileManager.default.moveItem(at: objects, to: saved)
        defer { try? FileManager.default.moveItem(at: saved, to: objects) }

        session.history.show(commit, runner: runner)

        await until { !session.history.isLoadingChanges }

        #expect(session.history.changesFailure != nil)
        #expect(session.history.changes.isEmpty)
        #expect(CommitFileListView(session: session, history: session.history, back: { }).emptyMessage == nil)
    }

    /// 相同版本的比较与树未改变的储藏都只渲染零摘要，没有文本 Diff 的空提示与展开全部。
    @Test("空比较与空储藏只显示零摘要", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func emptyDetails() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        let (head, stash) = try await Self.commitEmptyStash(runner: runner)

        let session = RepositorySession()
        defer { session.close() }

        session.comparison.open(
            base: .init(id: head, title: "base"),
            target: .init(id: head, title: "target"),
            runner: runner
        )

        session.comparison.showsChangeset = true
        session.stashes.refresh(runner: runner)

        await until { session.stashes.isLoaded && !session.comparison.isLoadingChanges }

        session.stashes.selectedIDs = [stash]

        await until { !session.stashes.isLoadingChanges }

        #expect(session.comparison.failure == nil && session.comparison.changes.isEmpty)
        #expect(session.stashes.changesFailure == nil && session.stashes.changes.isEmpty)

        await Self.expectEmpty { RevisionComparisonView(state: session.comparison, session: session) }
        await Self.expectEmpty { StashDetailView(session: session) }
    }

    /// 加载行高 32，转圈 16 × 16 距左 3，文字距左 25，两者在同一条水平中线上。
    @Test("变更集加载行的转圈与文字位置", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func loadingGeometry() async throws {
        let elements = await AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXBusyIndicator" } }
        ) {
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
}

// MARK: - Helpers

extension ChangesetEmptyStateTests {
    /// 呈现视图，核对只显示零摘要，没有展开全部。
    private static func expectEmpty(@ViewBuilder content: () -> some View) async {
        let summary = ChangesetSummaryBar.summary([])

        let elements = await AccessibilityProbe.elements(
            width: 800,
            until: { elements in elements.contains { $0.value == summary } },
            of: content
        )

        #expect(!elements.contains { $0.name == AppLocalization.text("history.expandAll") })
    }

    /// 提交一个空提交，再存一个树与它相同的储藏；返回这个提交与储藏的哈希。
    private static func commitEmptyStash(runner: GitRunner) async throws -> (head: String, stash: String) {
        _ = try await runner.run(["commit", "--allow-empty", "-m", "Base"])

        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let tree = try await objectID(["rev-parse", "HEAD^{tree}"], runner: runner)
        let index = try await objectID(["commit-tree", tree, "-p", head, "-m", "Index"], runner: runner)

        let stash = try await objectID(
            ["commit-tree", tree, "-p", head, "-p", index, "-m", "Empty stash"],
            runner: runner
        )

        _ = try await runner.run(["stash", "store", "-m", "Empty stash", stash])

        return (head, stash)
    }

    /// 读取 Git 输出的对象哈希，去掉命令末尾换行。
    private static func objectID(_ arguments: [String], runner: GitRunner) async throws -> String {
        let output = try await runner.run(arguments)

        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
