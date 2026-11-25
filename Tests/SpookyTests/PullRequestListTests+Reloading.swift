import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Reloading

/// 请求列表的重读：所选请求排在后几页时、切回仓库时与刷新时。
extension PullRequestListTests {
    /// 重读从第一页读起，所选的请求排在后面时接着读到它所在的那一页，选中与详情都留着；
    /// 它已不在列表里时，读回原有的个数就停下并清掉选中。
    /// 同一个窗口里切回停在请求视图的仓库时读取列表。
    /// 刷新只在请求视图里一并重读请求。
    @Test("重读保留后几页的选中，切回仓库与刷新时读取")
    func reloading() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.close() }

        try await expectSelectionKept(in: fixture)
        try await expectLoadOnReturn(in: fixture)
        try await expectRefresh(in: fixture)
    }

    /// 所选的请求在第三页、第二页与已不在列表里时的重读。
    private func expectSelectionKept(in fixture: Fixture) async throws {
        let state = fixture.session.pullRequests
        let numbers = { state.items.map(\.id.number) }

        let select = { (number: Int) async in
            state.select(fixture.id(number), runner: fixture.runner)
            await until { state.detail?.id == fixture.id(number) && !state.isLoadingDetail }
        }

        let reload = {
            state.load(runner: fixture.runner)
            await until { !state.isLoading }
        }

        // 假的 GitLab 每页只给一个：列出全部，一页页读到第三页
        RequestServer.update(fixture.host) { $0.pageSize = 1 }
        state.select(includesClosed: true, runner: fixture.runner)
        await until { !state.isLoading }

        #expect(numbers() == [1] && state.nextPage == 2)

        for _ in 1 ... 2 {
            state.loadMore()
            await until { !state.isLoading }
        }

        #expect(numbers() == [1, 2, 3] && state.nextPage == nil)

        // 所选的请求在第三页：重读接着读到第三页，选中与详情都留着
        await select(3)
        await reload()

        #expect(numbers() == [1, 2, 3])
        #expect(state.selectedID == fixture.id(3) && state.detail?.id == fixture.id(3))

        // 所选的请求在第二页：读到第二页为止
        await select(2)
        await reload()

        #expect(numbers() == [1, 2] && state.nextPage == 3)
        #expect(state.selectedID == fixture.id(2))

        // 所选的请求已不在列表里：读回原有的两个就停下，清掉选中与详情
        RequestServer.update(fixture.host) {
            $0.entries.remove(at: 1)
            $0.entries.append(RequestServer.Entry(iid: 4, state: "closed", branch: "old", character: "e", pipeline: nil))
        }

        await reload()

        #expect(numbers() == [1, 3] && state.nextPage == 3)
        #expect(state.selectedID == nil && state.detail == nil)
    }

    /// 停在请求视图的仓库：换到别的仓库再切回来时读取列表。
    private func expectLoadOnReturn(in fixture: Fixture) async throws {
        let session = fixture.session
        let state = session.pullRequests
        let other = fixture.directory.appending(path: "other", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)

        session.display(fixture.runner.location)
        session.showPullRequests()
        await until { state.isLoaded && !state.isLoading }

        // 换仓库时请求视图清空
        session.display(.local(path: other.path))
        #expect(!state.isLoaded && state.items.isEmpty)

        // 切回来：回到请求视图，随即开始读取
        session.display(fixture.runner.location)
        #expect(session.activeView == .pullRequests && state.isLoading)

        await until { state.isLoaded && !state.isLoading }
        #expect(state.items.map(\.id.number) == [1])
    }

    /// 刷新动作：请求视图里一并重读请求，别的视图里只刷新仓库。
    private func expectRefresh(in fixture: Fixture) async throws {
        let session = fixture.session
        let state = session.pullRequests
        let listReads = { RequestServer.log(of: fixture.host).count { $0.contains("/merge_requests?") } }

        let coordinator = SpookyApplicationController(
            bookmarks: RepositoryBookmarks(defaults: state.defaults),
            recentDocuments: .ignoring
        )

        let controller = RepositoryWindowController(coordinator: coordinator, session: session)
        defer { controller.window?.close() }

        controller.display(fixture.runner.location)
        await session.waitForRefresh()

        // 请求视图里刷新：列表再读一次
        var reads = listReads()

        controller.refreshRepository()
        #expect(state.isLoading)

        await until { !state.isLoading }
        await session.waitForRefresh()
        #expect(listReads() == reads + 1)

        // 别的视图里刷新：不读请求
        controller.showWorkingCopy()
        reads = listReads()

        controller.refreshRepository()
        #expect(!state.isLoading)

        await session.waitForRefresh()
        #expect(listReads() == reads)
    }
}
