import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 变更集命令与自动展开共用的真实 Git 仓库、隔离偏好和六份详情状态。
@MainActor
final class ChangesetFixture {
    /// 测试仓库与命令闸门。
    let directory: URL

    /// 隔离偏好域名称。
    let suite: String

    /// 不接触用户配置的自动展开设置。
    let defaults: UserDefaults

    /// 隔离 Git 执行器。
    let runner: GitRunner

    /// 依次创建的三个提交，各含两个变更文件。
    let commits: [HistoryCommit]

    /// 仓库会话，读取由测试显式启动。
    let session: RepositorySession

    /// 全局菜单动作的接收者。
    let application: SpookyApplicationController

    /// 仓库窗口，只有验证窗口动作时才创建。
    var window: RepositoryWindowController? = nil

    /// 六份状态的展开集合，顺序与命令测试的目标序号一致。
    var expansions: [Set<String>] {
        [
            session.history.expandedPaths,
            session.comparison.expandedPaths,
            session.stashes.expandedPaths,
            session.reflog.detail.expandedPaths,
            session.branchesReview.comparison.expandedPaths,
            session.pullRequests.comparison.expandedPaths,
        ]
    }

    /// 六份状态的补丁缓存键，用来证明不可用动作没有启动补丁读取。
    var cachedPaths: [Set<String>] {
        [
            Set(session.history.diffs.keys),
            Set(session.comparison.diffs.keys),
            Set(session.stashes.diffs.keys),
            Set(session.reflog.detail.diffs.keys),
            Set(session.branchesReview.comparison.diffs.keys),
            Set(session.pullRequests.comparison.diffs.keys),
        ]
    }

    /// 构建隔离状态；仓库内容由异步工厂准备。
    private init(directory: URL, runner: GitRunner, commits: [HistoryCommit]) throws {
        self.directory = directory
        self.runner = runner
        self.commits = commits
        suite = "Spooky.Changeset." + UUID().uuidString
        defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(0, forKey: "historyAutoExpand")
        session = RepositorySession(makeRunner: { _ in runner }, loadStatus: { _ in try await runner.status() })
        application = SpookyApplicationController(bookmarks: RepositoryBookmarks(defaults: defaults))
        application.changesetPreferences = defaults
        session.history.preferences = defaults
        session.reflog.detail.preferences = defaults
        session.stashes.preferences = defaults

        for state in [session.comparison, session.branchesReview.comparison, session.pullRequests.comparison] {
            state.preferences = defaults
        }
    }

    /// 创建三次双文件提交和两份包含 tracked / untracked 的储藏，不启动外部应用。
    static func make() async throws -> ChangesetFixture {
        let directory = try FileViewsTests.temporaryDirectory()
        _ = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        let runner = GitRunner(location: .local(path: directory.path), environment: .inherit.updating([
            "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_DATE": "1700000000 +0000", "GIT_COMMITTER_DATE": "1700000000 +0000",
        ]))
        var commits: [HistoryCommit] = []

        for number in 1 ... 3 {
            for path in ["a.txt", "b.txt"] {
                try Data("version \(number)\n".utf8).write(to: directory.appending(path: path))
            }

            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["commit", "-qm", "Changes \(number)"])
            commits.append(try await HistoryListTests.commit(at: 0, with: runner))
        }

        for number in 1 ... 2 {
            try Data("tracked \(number)\n".utf8).write(to: directory.appending(path: "a.txt"))
            try Data("untracked \(number)\n".utf8).write(to: directory.appending(path: "new.txt"))
            _ = try await runner.run(["stash", "push", "-u", "-m", "Saved \(number)"])
        }

        return try ChangesetFixture(directory: directory, runner: runner, commits: commits)
    }

    /// 读取各处详情；历史比较在普通历史命令的测试开始时由调用方关闭。
    func load() async throws {
        session.display(runner.location)
        session.history.refresh(status: try await runner.status(), runner: runner, records: false)
        session.stashes.refresh(runner: runner, records: false)
        session.reflog.load(runner: runner, location: runner.location)
        try await FileViewsTests.wait {
            !self.session.history.branches.isEmpty && self.session.stashes.isLoaded && self.session.reflog.isLoaded
        }

        session.history.show(commits[2], runner: runner)
        session.stashes.selectedIDs = [try #require(session.stashes.entries.first).id]
        session.reflog.selectedID = try #require(session.reflog.entries.first { $0.commit.id == commits[2].id }).id
        session.branchesReview.selectedIDs = ["refs/heads/main"]

        for state in [session.comparison, session.branchesReview.comparison, session.pullRequests.comparison] {
            open(state)
        }

        try await waitForChanges()
    }

    /// 使用真实版本打开比较，分段保持为 Changeset。
    func open(_ state: RevisionComparisonState, target: Int = 2, runner: GitRunner? = nil) {
        state.showsChangeset = true
        state.open(
            base: .init(id: commits[0].id, title: "base"),
            target: .init(id: commits[target].id, title: "target"),
            runner: runner ?? self.runner
        )
    }

    /// 等待六份状态的清单完成，不以固定延迟判断加载成功。
    func waitForChanges() async throws {
        try await FileViewsTests.wait {
            !self.session.history.isLoadingChanges && !self.session.stashes.isLoadingChanges
                && !self.session.reflog.detail.isLoadingChanges && !self.session.comparison.isLoadingChanges
                && !self.session.branchesReview.comparison.isLoadingChanges
                && !self.session.pullRequests.comparison.isLoadingChanges
        }
    }

    /// 每份状态各留一个真实文件和一个不同的残留身份，以检查隐藏状态是否被改变。
    func seedExpansions() {
        session.history.expandedPaths = ["a.txt", "hidden-history"]
        session.comparison.expandedPaths = ["a.txt", "hidden-comparison"]
        session.stashes.expandedPaths = [session.stashes.changes.first?.id ?? "", "hidden-stash"]
        session.reflog.detail.expandedPaths = ["a.txt", "hidden-reflog"]
        session.branchesReview.comparison.expandedPaths = ["a.txt", "hidden-branches"]
        session.pullRequests.comparison.expandedPaths = ["a.txt", "hidden-request"]
    }

    /// 菜单动作与应用共用偏好入口，不直接修改状态对象。
    func setThreshold(_ value: Int) {
        let item = NSMenuItem()
        item.tag = value
        application.setAutoExpand(item)
    }

    /// 建出仓库窗口以调用真实验证与动作入口；不把显示状态复制进会话。
    func showWindow() {
        _ = NSApplication.shared
        window = RepositoryWindowController(coordinator: application, session: session)
        window?.display(runner.location)
        session.onActiveViewChange = nil
    }

    /// 先取消全部任务，再移除本测试拥有的临时数据。
    func close() {
        session.close()
        window?.window?.close()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}
