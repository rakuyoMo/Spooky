import AppKit
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Editing

/// 状态图标的资源、标签的增删与作业日志的展开。
extension PullRequestListTests {
    /// 四种状态的图标都能从资源包读出，颜色都在命名色里。
    /// 标签：候选是项目的标签去掉请求已有的、再按名称筛选；增删写到托管服务上，写完重新读取，列表与详情的标签跟着变，
    /// 上一次还没写完时不开始下一次；新建标签先建再加。
    /// 日志：展开时读取并整理成段，收起时丢掉；自动刷新时还在运行的与状态变了的项重读日志，读取失败时记下失败。
    @Test("状态图标、标签的增删与作业日志的展开")
    func iconsLabelsAndLogs() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.close() }

        try expectIcons(in: fixture)
        try await expectLabelEditing(in: fixture)
        try await expectLogs(in: fixture)
    }

    /// 打开、草稿、已关闭与已合并各有 16 × 16 的图标与命名色。
    private func expectIcons(in fixture: Fixture) throws {
        let open = try #require(fixture.session.pullRequests.items.first)
        let directory = try #require(PullRequestStateIcon.directory)

        let requests = [
            open,
            Self.request(open, state: .open, isDraft: true),
            Self.request(open, state: .closed, isDraft: true),
            Self.request(open, state: .merged, isDraft: false),
        ]

        let names = requests.map { PullRequestStateIcon.imageName(for: $0) }

        #expect(Set(names).count == 4)

        for request in requests {
            let file = directory.appending(path: PullRequestStateIcon.imageName(for: request) + ".svg")

            #expect(NSImage(contentsOf: file)?.size == NSSize(width: 16, height: 16))
            #expect(AppPalette.colors[PullRequestStateIcon.colorName(for: request)] != nil)
        }
    }

    /// 标签的候选、增删与新建。
    private func expectLabelEditing(in fixture: Fixture) async throws {
        let session = fixture.session
        let state = session.pullRequests
        let id = fixture.id(1)
        let settled = { !state.isEditingLabels && !state.isLoadingDetail && !state.isLoading }

        // 会话打开仓库后，写操作才有仓库可以记进 Activity
        session.display(fixture.runner.location)
        session.reloadPullRequests()
        await until { state.isLoaded && !state.isLoading }

        state.select(id, runner: fixture.runner)
        await until { state.detail != nil && settled() }

        var request = try #require(state.detail)

        // 候选：项目的标签去掉请求已有的，筛选不分大小写
        let project = try await state.loadLabels()
        let tagged = Self.request(request, labels: [PullRequestLabel(name: "bug")])

        #expect(project.map(\.name) == ["bug", "docs"])
        #expect(PullRequestLabelPicker.candidates(in: project, for: tagged, filter: "").map(\.name) == ["docs"])
        #expect(PullRequestLabelPicker.candidates(in: project, for: request, filter: " BU ").map(\.name) == ["bug"])

        // 加上一个标签：写完之前不开始下一次，写完后列表与详情都带上它
        #expect(session.addLabel("bug", to: request))
        #expect(state.isEditingLabels && !session.addLabel("docs", to: request))

        await until { settled() && state.detail?.labels.count == 1 }

        #expect(state.detail?.labels.map(\.name) == ["bug"])
        #expect(state.items.first?.labels.map(\.name) == ["bug"])

        // 新建标签：先在项目里建，再加到请求上
        request = try #require(state.detail)

        #expect(PullRequestLabelDialog.hex(of: Color(nsColor: PaletteColor(hex: "#FBCA04", alpha: 1).nsColor)) == "fbca04")
        #expect(session.createLabel("review", color: "fbca04", for: request))

        await until { settled() && state.detail?.labels.count == 2 }

        // 去掉一个标签
        request = try #require(state.detail)

        #expect(session.removeLabel("bug", from: request))

        await until { settled() && state.detail?.labels.count == 1 }

        #expect(state.items.first?.labels.map(\.name) == ["review"])

        let path = "/api/v4/projects/group/project"

        #expect(
            RequestServer.writes(of: fixture.host) == [
                "PUT " + path + #"/merge_requests/1 {"add_labels":"bug"}"#,
                "POST " + path + ##"/labels {"color":"#fbca04","name":"review"}"##,
                "PUT " + path + #"/merge_requests/1 {"add_labels":"review"}"#,
                "PUT " + path + #"/merge_requests/1 {"remove_labels":"bug"}"#,
            ]
        )
    }

    /// 日志的展开、收起与随状态的重读。
    private func expectLogs(in fixture: Fixture) async throws {
        let state = fixture.session.pullRequests
        let checks = state.checks
        let client = try #require(state.client)
        let request = try #require(state.detail)
        let gate = RefreshGate()

        checks.wait = { await gate.wait() }
        RequestServer.update(fixture.host) { $0.entries[0].pipeline = "running" }

        let task = Task { await checks.watch(request, client: client, repository: fixture.runner.location) }
        await until { gate.isWaiting }

        let job = try #require(checks.selected?.items.first)

        // 展开：读到整理后的日志，分组标记与控制码都不在
        state.setCheckExpanded(true, job)
        await untilFinished { Array(checks.logTasks.values) }

        #expect(checks.expandedChecks == [job.id])
        #expect(checks.logs[job.id] == ["Running\nfirst"])

        // 作业还在运行：下一次自动刷新重读日志；跑完后的那次同样重读
        RequestServer.update(fixture.host) { $0.trace += "second\n" }
        gate.release()
        await until { gate.isWaiting }
        await untilFinished { Array(checks.logTasks.values) }

        #expect(checks.logs[job.id] == ["Running\nfirst\nsecond"])

        // 流水线跑完
        RequestServer.update(fixture.host) {
            $0.entries[0].pipeline = "success"
            $0.trace += "third\n"
        }

        gate.release()
        await task.value
        await untilFinished { Array(checks.logTasks.values) }

        #expect(checks.selected?.state == .success)
        #expect(checks.logs[job.id] == ["Running\nfirst\nsecond\nthird"])

        // 收起后丢掉日志；读取失败时记下失败，再展开重新读取
        state.setCheckExpanded(false, job)
        #expect(checks.expandedChecks.isEmpty && checks.logs[job.id] == nil)

        RequestServer.update(fixture.host) { $0.fails = true }
        state.setCheckExpanded(true, job)
        await untilFinished { Array(checks.logTasks.values) }

        #expect(checks.logFailures[job.id] != nil && checks.logs[job.id] == nil)

        RequestServer.update(fixture.host) { $0.fails = false }
        state.setCheckExpanded(true, job)
        await untilFinished { Array(checks.logTasks.values) }

        #expect(checks.logFailures[job.id] == nil && checks.logs[job.id]?.count == 1)

        // 长日志按段切开；换一个所选请求后展开与日志都清掉
        let lines = (1 ... 250).map(String.init)
        let chunks = PullRequestChecksState.chunks(of: lines)

        #expect(chunks.map { $0.split(separator: "\n").count } == [100, 100, 50])

        checks.clearSelected()
        #expect(checks.expandedChecks.isEmpty && checks.logs.isEmpty)
    }
}

// MARK: - Helpers

extension PullRequestListTests {
    /// 换了状态的同一个请求。
    private static func request(_ request: PullRequest, state: PullRequestState, isDraft: Bool) -> PullRequest {
        PullRequest(
            id: request.id,
            title: request.title,
            body: request.body,
            state: state,
            isDraft: isDraft,
            author: request.author,
            createdAt: request.createdAt,
            updatedAt: request.updatedAt,
            source: request.source,
            target: request.target
        )
    }
}
