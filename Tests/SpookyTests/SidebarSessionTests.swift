import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SidebarSessionTests

/// 侧边栏的写入经会话的写队列执行，完成后的完整刷新把新状态读回快照；检出分支的记录带上分支名；新建工作树之后窗口不变。
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

        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
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
            session.activities.items
                .contains { $0.repository == location && $0.title == AppLocalization.text("branch.pin") }
        )

        session.setArchived(true, branches: [feature])
        try await waitUntil { session.history.snapshot?.metadata(for: feature.id).isArchived ?? false }
        #expect(session.history.snapshot?.metadata(for: feature.id) == BranchMetadata(isPinned: true, isArchived: true))

        // 整理状态随引用一起读入：main 是基准分支，feature 不是
        #expect(try #require(session.history.conditions[main.id]).isBase)
        #expect(try !#require(session.history.conditions[feature.id]).isBase)

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

    /// 检出本地分支与远端分支时，Activity 的标题带上分支名，读记录的人不必再看日志就知道检出了哪个分支；远端分支带远端名前缀。
    @Test("检出分支的记录带上分支名")
    func checkoutTitles() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-checkout-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["branch", "feature/一"])
        _ = try await runner.run(["remote", "add", "origin", directory.appending(path: "origin.git").path])
        _ = try await runner.run(["update-ref", "refs/remotes/origin/side", "HEAD"])

        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        defer { session.close() }
        session.display(location)
        session.refresh()
        try await waitUntil { session.history.snapshot != nil }

        let feature = try #require(session.history.branches.first { $0.id == "refs/heads/feature/一" })
        session.checkoutBranch(feature) { _ in Issue.record("本地分支直接检出") }
        try await waitUntil { session.status?.branch.head == "feature/一" && !session.isWriting }

        // 远端分支没有对应的本地分支，建同名跟踪分支并检出
        let side = try #require(session.history.snapshot?.references.first { $0.id == "refs/remotes/origin/side" })
        session.checkoutBranch(side) { _ in Issue.record("没有同名的本地分支，不打开跟踪表单") }
        try await waitUntil { session.status?.branch.head == "side" && !session.isWriting }

        let titles = session.activities.items.map(\.title)
        #expect(titles.contains(AppLocalization.text("branch.checkoutNamed", "feature/一")))
        #expect(titles.contains(AppLocalization.text("branch.checkoutNamed", "origin/side")))
    }

    /// 新建的工作树只出现在 Worktrees 分组里，不另开标签或窗口，当前窗口仍显示原来的仓库。
    @Test("新建工作树之后不打开它")
    func addWorktreeKeepsWindow() async throws {
        let parent = FileManager.default.temporaryDirectory.appending(path: "spooky-worktree-" + UUID().uuidString)
        let directory = parent.appending(path: "repo")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["branch", "side"])

        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        defer { session.close() }

        var opened: [RepositoryLocation] = []
        session.onOpenRepository = { target, _ in opened.append(target) }

        session.display(location)
        session.refresh()
        try await waitUntil { session.worktrees.isLoaded }

        // 写入后的完整刷新读回新工作树，再确认没有打开它
        let destination = parent.appending(path: "repo-side").path
        #expect(session.addWorktree(at: destination, revision: "side", detach: false, force: false))
        try await waitUntil { session.worktrees.others.contains { $0.branch == "refs/heads/side" } }

        #expect(opened.isEmpty)
        #expect(session.repository == location)
    }
}

// MARK: - Helpers

extension SidebarSessionTests {
    /// 等待写入与随后的刷新落定，最多 5 分钟。
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("等待超时")
                return
            }

            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
