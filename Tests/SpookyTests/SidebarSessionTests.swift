import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - SidebarSessionTests

/// 侧边栏的写入经会话的写队列执行，完成后的完整刷新把新状态读回快照；检出分支的记录带上分支名；新建工作树之后窗口不变。
@MainActor
struct SidebarSessionTests {
    /// 置顶、归档与取消都写进分支配置并读回；检出本地与远端分支的记录带上分支名；标签检出成分离 HEAD；
    /// 新建的工作树只出现在 Worktrees 分组里，不另开标签或窗口，当前窗口仍显示原来的仓库。
    @Test("置顶、归档、检出分支与标签，新建工作树之后不打开它")
    func sidebarWrites() async throws {
        let parent = FileManager.default.temporaryDirectory
            .appending(path: "spooky-sidebar-" + UUID().uuidString)

        let directory = parent.appending(path: "repo")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        // 根提交上有分支、标签与远端分支，main 再前进一个提交
        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        let origin = directory.appending(path: "origin.git").path

        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["branch", "feature/一"])
        _ = try await runner.run(["branch", "工作树"])
        _ = try await runner.run(["tag", "-a", "v1.0", "-m", "Release"])
        _ = try await runner.run(["remote", "add", "origin", origin])
        _ = try await runner.run(["update-ref", "refs/remotes/origin/side", "HEAD"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "next"])

        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        defer { session.close() }

        var opened: [RepositoryLocation] = []
        session.onOpenRepository = { target, _ in opened.append(target) }

        session.display(location)
        session.refresh()
        await settle(session)

        try await checkBranchFlags(in: session, location: location)
        try await checkCheckouts(in: session)

        // 新建工作树：写入后的完整刷新不打开它
        let destination = parent.appending(path: "repo-工作树").path
        let added = session.addWorktree(
            at: destination,
            revision: "工作树",
            detach: false,
            force: false
        )

        #expect(added)
        await settle(session)

        #expect(FileManager.default.fileExists(atPath: destination + "/.git"))
        #expect(opened.isEmpty)
        #expect(session.repository == location)
    }
}

// MARK: - Helpers

extension SidebarSessionTests {
    /// 拖到 Pinned 与 Archived Branches 的动作，置顶与归档的写入与读回，以及随引用读入的整理状态。
    private func checkBranchFlags(
        in session: RepositorySession,
        location: RepositoryLocation
    ) async throws {
        let feature = try #require(session.history.branches.first { $0.id == "refs/heads/feature/一" })
        let main = try #require(session.history.branches.first { $0.id == "refs/heads/main" })
        let metadata = { session.history.snapshot?.metadata(for: feature.id) }

        // 拖到 Pinned 标题只置顶拖动的分支；拖动的分支在多选中时，拖到 Archived Branches 归档整个选区
        let payload = RepositoryDragPayload(
            repository: location,
            kind: .local,
            reference: feature.id
        )

        let pin = try #require(
            BranchFlagDropAction(payload: payload, destination: .pinned, session: session)
        )
        #expect(pin.titleKey == "branch.pin")

        session.history.selectedReferences = [feature.id, main.id]

        let archive = BranchFlagDropAction(
            payload: payload,
            destination: .archived,
            session: session
        )

        guard case .archive(let selected) = archive else {
            Issue.record("拖到 Archived Branches 应当归档")
            return
        }

        #expect(Set(selected.map(\.id)) == [feature.id, main.id])

        #expect(
            BranchFlagDropAction(payload: payload, destination: .branches, session: session) == nil
        )

        session.history.selectedReferences = []

        // 置顶与归档各一次写入，Activity 记下操作名
        session.setPinned(true, branches: [feature])
        await settle(session)

        #expect(metadata()?.isPinned ?? false)

        #expect(
            session.activities.items.contains {
                $0.repository == location && $0.title == AppLocalization.text("branch.pin")
            }
        )

        session.setArchived(true, branches: [feature])
        await settle(session)
        #expect(metadata() == BranchMetadata(isPinned: true, isArchived: true))

        // 整理状态随引用一起读入：main 是基准分支，feature 不是
        #expect(try #require(session.history.conditions[main.id]).isBase)
        #expect(try !#require(session.history.conditions[feature.id]).isBase)

        // 取消置顶与归档后分支配置里不再有整理标记
        session.setPinned(false, branches: [feature])
        await settle(session)
        session.setArchived(false, branches: [feature])
        await settle(session)

        #expect(session.history.snapshot?.metadata.isEmpty ?? false)
    }

    /// 检出本地分支与远端分支时，Activity 的标题带上分支名，远端分支带远端名前缀；双击标签检出成分离 HEAD。
    private func checkCheckouts(in session: RepositorySession) async throws {
        let feature = try #require(session.history.branches.first { $0.id == "refs/heads/feature/一" })
        session.checkoutBranch(feature) { _ in Issue.record("本地分支直接检出") }
        await settle(session)
        #expect(session.status?.branch.head == "feature/一")

        // 远端分支没有对应的本地分支，建同名跟踪分支并检出
        let references = session.history.snapshot?.references ?? []
        let side = try #require(references.first { $0.id == "refs/remotes/origin/side" })
        session.checkoutBranch(side) { _ in Issue.record("没有同名的本地分支，不打开跟踪表单") }
        await settle(session)
        #expect(session.status?.branch.head == "side")

        let titles = session.activities.items.map(\.title)

        #expect(titles.contains(AppLocalization.text("branch.checkoutNamed", "feature/一")))
        #expect(titles.contains(AppLocalization.text("branch.checkoutNamed", "origin/side")))

        // 双击标签按完整标签名检出，HEAD 分离在标签所指的提交上
        let tag = try #require(session.history.snapshot?.references.first { $0.isTag })
        #expect(session.canCheckoutRevision)

        session.checkout(revision: tag.id)
        await settle(session)

        #expect(session.status?.branch.head == nil)
        #expect(session.status?.branch.oid == tag.objectID)
    }

    /// 等写操作、随后的完整刷新与引用读取都结束；读引用期间又要求的读取也一起等完。
    private func settle(_ session: RepositorySession) async {
        await session.writeTask?.value
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
    }
}
