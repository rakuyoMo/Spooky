import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SidebarSessionTests

/// 侧边栏的写入经会话的写队列执行，完成后的完整刷新把新状态读回快照。
@MainActor
struct SidebarSessionTests {
    /// 置顶、归档与取消都写进分支配置并读回；没有新提交的分支并入 main；标签检出成分离 HEAD。
    @Test("置顶、归档与检出标签")
    func flagsAndTagCheckout() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-sidebar-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["branch", "feature/一"])
        _ = try await runner.run(["tag", "-a", "v1.0", "-m", "Release"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "next"])

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.display(location)
        session.refresh()
        try await waitUntil { session.history.snapshot != nil }

        let feature = try #require(session.history.branches.first { $0.id == "refs/heads/feature/一" })
        let main = try #require(session.history.branches.first { $0.id == "refs/heads/main" })

        // 拖到 Pinned 标题只置顶拖动的分支；拖动的分支在多选中时，拖到 Archived Branches 归档整个选区
        let payload = RepositoryDragPayload(repository: location, kind: .local, reference: feature.id)
        let pin = try #require(BranchFlagDropAction(payload: payload, destination: .pinned, session: session))
        #expect(pin.titleKey == "branch.pin")

        session.history.selectedReferences = [feature.id, main.id]
        guard case .archive(let selected) = BranchFlagDropAction(payload: payload, destination: .archived, session: session)
        else {
            Issue.record("拖到 Archived Branches 应当归档")
            return
        }

        #expect(Set(selected.map(\.id)) == [feature.id, main.id])
        #expect(BranchFlagDropAction(payload: payload, destination: .branches, session: session) == nil)
        session.history.selectedReferences = []

        // 置顶与归档各一次写入，Activity 记下操作名
        session.setPinned(true, branches: [feature])
        try await waitUntil { session.history.snapshot?.metadata(for: feature.id).isPinned ?? false }
        #expect(
            RepositoryActivities.shared.items
                .contains { $0.repository == location && $0.title == AppLocalization.text("branch.pin") }
        )

        session.setArchived(true, branches: [feature])
        try await waitUntil { session.history.snapshot?.metadata(for: feature.id).isArchived ?? false }
        #expect(session.history.snapshot?.metadata(for: feature.id) == BranchMetadata(isPinned: true, isArchived: true))

        // feature 停在 main 的祖先上，算完全合并
        #expect(session.history.conditions[feature.id]?.mergedInto == "refs/heads/main")

        session.setPinned(false, branches: [feature])
        try await waitUntil { !(session.history.snapshot?.metadata(for: feature.id).isPinned ?? true) }
        session.setArchived(false, branches: [feature])
        try await waitUntil { session.history.snapshot?.metadata.isEmpty ?? false }

        // 双击标签按完整标签名检出，HEAD 分离在标签所指的提交上
        let tag = try #require(session.history.snapshot?.references.first { $0.isTag })
        #expect(session.canCheckoutRevision)
        session.checkout(revision: tag.id)
        try await waitUntil { session.status?.branch.head == nil && session.status?.branch.oid == tag.objectID }
    }
}

// MARK: - Helpers

extension SidebarSessionTests {
    /// 等待写入与随后的刷新落定，最多 30 秒。
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))

        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("等待超时")
                return
            }

            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
