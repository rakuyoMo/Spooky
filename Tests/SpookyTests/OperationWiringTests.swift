import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - OperationWiringTests

/// 历史与侧边栏上接线的操作入口：历史右键菜单按 “单选 / 多选 × 是否在看 HEAD 分支 × 是否未拉取” 拼出的项与可用状态。
@MainActor
struct OperationWiringTests {
    /// 只有选中当前分支或 HEAD 行才算在看 HEAD 分支，改写类入口据此出现；单选与多选、别的分支与当前分支、
    /// 未拉取与合并提交各自拼出的项与可用状态；菜单项把所选提交交给会话的请求入口。
    @Test("历史右键菜单的项、可用状态与发出的请求")
    func commitMenu() async throws {
        let fixture = try await Self.makeFixture()
        defer { fixture.close() }

        checkViewingHead(in: fixture)
        try await checkSingleSelection(in: fixture)
        try await checkMultipleSelection(in: fixture)
        try await checkMenuRequests(in: fixture)
    }
}

// MARK: - Fixture

extension OperationWiringTests {
    /// 一个仓库与显示它的会话：main 上依次是 A（附注标签 v1）、把 side（S）并进来的合并提交 M、B 与 D，
    /// 上游 origin/main 比本地多一个提交 C。
    struct Fixture {
        /// 仓库目录。
        let directory: URL

        /// 仓库的执行器。
        let runner: GitRunner

        /// 显示仓库的会话。
        let session: RepositorySession

        /// 提交标题到完整哈希。
        let ids: [String: String]

        /// 关闭会话并删除仓库。
        @MainActor
        func close() {
            session.close()
            try? FileManager.default.removeItem(at: directory)
        }

        /// 在历史里显示引用，等列表读完后选中这些标题的提交；返回第一个。
        @MainActor
        @discardableResult
        func select(_ reference: String, subjects: [String]) async throws -> HistoryCommit {
            let history = session.history
            let wanted = Set(subjects.compactMap { ids[$0] })

            // 换了引用时列表同步开始重读，读完再选中
            history.selectedReferences = [reference]
            await untilFinished { history.activeTasks }
            try #require(wanted.isSubset(of: history.commits.map(\.id)))

            history.selectedIDs = wanted
            return try #require(history.commits.first { $0.id == ids[subjects[0]] })
        }

        /// 当前选择的右键菜单。
        @MainActor
        func menu() -> MenuSnapshot {
            let history = session.history
            let selected = history.commits.filter { history.selectedIDs.contains($0.id) }
            return MenuSnapshot(items: HistoryCommitMenu.items(for: selected, session: session) { _ in })
        }
    }

    /// 生成好的菜单项，按资源键与参数找项。
    struct MenuSnapshot {
        /// 菜单项。
        let items: [NSMenuItem]

        /// 有这一项且可用。
        func enabled(_ key: String, _ arguments: any CVarArg...) -> Bool {
            item(key, arguments).map(\.isEnabled) ?? false
        }

        /// 有这一项且灰色。
        func disabled(_ key: String, _ arguments: any CVarArg...) -> Bool {
            item(key, arguments).map { !$0.isEnabled } ?? false
        }

        /// 有这一项。
        func contains(_ key: String, _ arguments: any CVarArg...) -> Bool {
            item(key, arguments) != nil
        }

        /// 选中这一项。
        @MainActor
        func perform(_ key: String, _ arguments: any CVarArg...) {
            guard let item = item(key, arguments), let action = item.action else {
                Issue.record("找不到菜单项：\(key)")
                return
            }

            _ = (item.target as AnyObject?)?.perform(action, with: item)
        }

        /// 标题与资源键和参数拼出的文字相同的项；菜单标题最多带一个参数。
        private func item(_ key: String, _ arguments: [any CVarArg]) -> NSMenuItem? {
            let title = arguments.first.map { AppLocalization.text(key, $0) } ?? AppLocalization.text(key)
            return items.first { $0.title == title }
        }
    }

    /// 建立仓库并打开会话。
    static func makeFixture() async throws -> Fixture {
        let directory = try FileViewsTests.temporaryDirectory()
        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        var ids: [String: String] = [:]

        // 依次提交，每个提交新增一个以标题命名的文件
        func commit(_ subject: String) async throws {
            try Data("\(subject)\n".utf8).write(to: directory.appending(path: subject + ".txt"))
            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["commit", "-q", "-m", subject])
            ids[subject] = try await RepositoryReferences(runner: runner).resolve("HEAD")
        }

        try await commit("A")
        _ = try await runner.run(["tag", "-a", "-m", "v1", "v1"])
        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try await commit("S")
        _ = try await runner.run(["checkout", "-q", "main"])
        _ = try await runner.run(["merge", "-q", "--no-ff", "-m", "M", "side"])
        ids["M"] = try await RepositoryReferences(runner: runner).resolve("HEAD")
        try await commit("B")
        try await commit("D")

        // 上游比本地多一个提交
        try await commit("C")
        _ = try await runner.run(["update-ref", "refs/remotes/origin/main", "HEAD"])
        _ = try await runner.run(["reset", "-q", "--hard", "HEAD~1"])
        _ = try await runner.run(["config", "--local", "remote.origin.url", directory.path])
        let fetch = "+refs/heads/*:refs/remotes/origin/*"
        _ = try await runner.run(["config", "--local", "remote.origin.fetch", fetch])
        _ = try await runner.run(["config", "--local", "branch.main.remote", "origin"])
        _ = try await runner.run(["config", "--local", "branch.main.merge", "refs/heads/main"])

        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        session.display(location)
        session.refresh(full: true)

        // 刷新期间同步开始读引用与列表，一起等完
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
        try #require(session.history.snapshot != nil)

        return Fixture(directory: directory, runner: runner, session: session, ids: ids)
    }
}

// MARK: - Commit Menu

extension OperationWiringTests {
    /// 只有选中当前分支或 HEAD 行才算在看 HEAD 分支；全部引用、别的分支与同时选中几个分支都不算。
    private func checkViewingHead(in fixture: Fixture) {
        let session = fixture.session
        let history = session.history

        #expect(!session.isViewingHead)

        history.selectedReferences = ["refs/heads/main"]
        #expect(session.isViewingHead)

        history.selectedReferences = ["refs/heads/side"]
        #expect(!session.isViewingHead)

        history.selectedReferences = ["HEAD"]
        #expect(session.isViewingHead)

        history.selectedReferences = ["refs/heads/main", "refs/heads/side"]
        #expect(!session.isViewingHead)
    }

    /// 单选一个提交：别的分支上反转只有灰色的通用项、摘取可用、改写各项不出现；当前分支上已在本地的提交可以反转、
    /// 变基到别处与交互式改写，摘取不出现，未拉取的提交才有摘取；合并提交与普通提交的菜单相同。
    private func checkSingleSelection(in fixture: Fixture) async throws {
        // 别的分支上的提交
        let side = try await fixture.select("refs/heads/side", subjects: ["S"])
        var menu = fixture.menu()

        #expect(menu.enabled("rewrite.menu.checkout", side.shortID))
        #expect(menu.enabled("rewrite.menu.reset", side.shortID))
        #expect(menu.disabled("rewrite.menu.revertGeneric"))
        #expect(menu.enabled("rewrite.menu.cherryPick", side.shortID))
        #expect(menu.enabled("history.createBranch", side.shortID))
        #expect(menu.enabled("tag.createFrom", side.shortID))
        #expect(!menu.contains("rewrite.menu.amend", side.shortID))
        #expect(!menu.contains("rewrite.menu.delete", side.shortID))
        #expect(!menu.contains("rewrite.menu.rebaseOnto", side.shortID))

        // 当前分支上已在本地的提交
        let local = try await fixture.select("refs/heads/main", subjects: ["B"])
        menu = fixture.menu()

        #expect(menu.enabled("rewrite.menu.revert", local.shortID))
        #expect(!menu.contains("rewrite.menu.cherryPick", local.shortID))
        #expect(menu.enabled("rewrite.menu.rebaseOnto", local.shortID))

        let rewrites = [
            "rewrite.menu.amend",
            "rewrite.menu.edit",
            "rewrite.menu.reword",
            "rewrite.menu.delete",
        ]

        for key in rewrites {
            #expect(menu.enabled(key, local.shortID))
        }

        // 只在上游里的提交可以摘取到当前分支
        let unpulled = try await fixture.select("refs/heads/main", subjects: ["C"])
        #expect(fixture.session.history.unpulled == [unpulled.id])

        menu = fixture.menu()

        #expect(menu.enabled("rewrite.menu.cherryPick", unpulled.shortID))
        #expect(menu.enabled("rewrite.menu.revert", unpulled.shortID))

        // 合并提交：主线由反转与摘取的对话框选择，范围里的合并提交由交互式变基报告
        let merge = try await fixture.select("refs/heads/main", subjects: ["M"])
        #expect(merge.parents.count == 2)

        menu = fixture.menu()

        #expect(menu.enabled("rewrite.menu.revert", merge.shortID))
        #expect(menu.enabled("rewrite.menu.reset", merge.shortID))
        #expect(menu.enabled("rewrite.menu.amend", merge.shortID))
    }

    /// 多选时检出、重置、新建分支与标签只有灰色的通用项；当前分支上压缩、fixup 与删除作用于全部所选，
    /// 别的分支上反转灰色、可以摘取。
    private func checkMultipleSelection(in fixture: Fixture) async throws {
        _ = try await fixture.select("refs/heads/main", subjects: ["B", "A"])
        var menu = fixture.menu()

        let generic = [
            "rewrite.menu.checkoutGeneric",
            "rewrite.menu.resetGeneric",
            "history.createBranchGeneric",
            "tag.createMenu",
        ]

        for key in generic {
            #expect(menu.disabled(key))
        }

        #expect(menu.enabled("rewrite.menu.revertMany", 2))
        #expect(!menu.contains("rewrite.menu.cherryPickMany", 2))
        #expect(menu.enabled("rewrite.menu.rebaseOntoMany", 2))
        #expect(menu.enabled("rewrite.menu.deleteMany", 2))
        #expect(menu.enabled("rewrite.menu.squashMany", 2))
        #expect(menu.enabled("rewrite.menu.fixupMany", 2))

        // 别的分支上多选
        _ = try await fixture.select("refs/heads/side", subjects: ["S", "A"])
        menu = fixture.menu()

        #expect(menu.disabled("rewrite.menu.revertGeneric"))
        #expect(menu.enabled("rewrite.menu.cherryPickMany", 2))
        #expect(!menu.contains("rewrite.menu.squashMany", 2))
    }

    /// 菜单项把所选提交交给会话的请求入口：反转打开选项对话框，压缩先计划再请求确认。
    private func checkMenuRequests(in fixture: Fixture) async throws {
        var requests: [RewriteRequest] = []
        fixture.session.onRewriteRequest = { requests.append($0) }

        // 反转直接请求打开选项对话框
        let local = try await fixture.select("refs/heads/main", subjects: ["B"])
        fixture.menu().perform("rewrite.menu.revert", local.shortID)

        guard case .revert(let commits) = try #require(requests.first) else {
            Issue.record("反转应打开选项对话框")
            return
        }

        #expect(commits == [local.id])

        // 压缩的计划在后台任务里完成，完成后在主线程请求确认
        let selected = try await fixture.select("refs/heads/main", subjects: ["D", "B"])
        fixture.menu().perform("rewrite.menu.squashMany", 2)
        await until { requests.count == 2 }

        guard
            case .confirm(let plan) = requests.last,
            case .squash(let squashed, into: nil) = plan.action
        else {
            Issue.record("压缩应先计划再请求确认")
            return
        }

        #expect(Set(squashed) == Set([selected.id, fixture.ids["B"] ?? ""]))
    }
}
