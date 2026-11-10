import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Session

extension HistoryListTests {
    /// 搜索框写入第一个条件，等输入停顿后重读；过滤面板加的条件取交集；切换视图结束搜索。
    @Test("历史搜索、组合条件与结束搜索")
    func search() async throws {
        let fixture = try await Self.makeSession(commits: ["alpha fix", "beta", "gamma fix"])
        defer { fixture.close() }

        let history = fixture.session.history
        #expect(history.commits.count == 3)
        #expect(history.commitCount == 3)
        #expect(!history.graphRows.isEmpty)

        history.setSearchText("FIX")
        await untilFinished { history.activeTasks }

        #expect(history.query.isSearching)
        #expect(history.commits.map(\.subject) == ["gamma fix", "alpha fix"])
        #expect(history.commitCount == 2)

        // 搜索结果不连续，不画提交图
        #expect(history.graphRows.isEmpty)

        // 连续输入只按最后一次的内容重读，过时的结果不会覆盖
        history.setSearchText("a")
        history.setSearchText("al")
        history.setSearchText("gamma")
        await untilFinished { history.activeTasks }

        #expect(history.commits.map(\.subject) == ["gamma fix"])

        // 换成按作者搜索，再加一个提交信息条件，两类条件取交集
        history.setSearchText("spooky")
        history.setSearchScope(.author)

        let added = history.addSearchCondition()
        var condition = try #require(history.searchConditions.first { $0.id == added })
        condition.text = "beta"
        history.updateSearchCondition(condition)
        await untilFinished { history.activeTasks }

        #expect(history.commits.map(\.subject) == ["beta"])
        #expect(history.commitCount == 1)
        #expect(history.primarySearchKind == .author)
        #expect(history.primarySearchText == "spooky")

        // 移除一个条件后只剩作者条件
        history.removeSearchCondition(added)
        await untilFinished { history.activeTasks }

        #expect(history.commitCount == 3)

        // 切换视图结束搜索并重读完整历史
        fixture.session.activeView = .history
        fixture.session.activeView = .workingCopy
        #expect(history.searchConditions.isEmpty)

        await untilFinished { history.activeTasks }

        #expect(!history.query.isSearching)
        #expect(history.commits.count == 3)
    }

    /// 列表已是全部历史并加载了要回到的提交时直接回到，不读取位置；只看一个引用时先核对位置再回到；
    /// 不在已加载的分页里时按 1000 条续载直到找到，排在询问的阈值以内不询问；找不到时说明原因。
    @Test("回到历史时按需核对、扩大加载并选中提交")
    func revealExpandsLoading() async throws {
        let fixture = try await Self.makeSession(
            commits: (0 ..< 250).map { "commit \($0)" },
            createsOrphan: true
        )
        defer { fixture.close() }

        let session = fixture.session
        let history = session.history
        #expect(history.commits.count < 250)

        // 记下所有询问，不回调
        var prompts: [String] = []
        session.onConfirm = { prompts.append($0.title) }

        // 只看 main 时列表不是全部历史，即使已加载也先核对，核对完才切换
        history.selectedReferences = ["refs/heads/main"]
        await untilFinished { history.activeTasks }

        let loaded = try #require(history.commits.last)

        session.showCommit(loaded)
        #expect(history.lookupCheckTask != nil)
        #expect(session.activeView == .workingCopy)

        await untilFinished { history.activeTasks }

        #expect(session.activeView == .history)
        #expect(history.showsCommitPage)
        #expect(history.selectedReferences.isEmpty)
        #expect(history.selectedIDs == [loaded.id])

        // 回到全部历史后列表已加载它，再回到别的已加载的提交时直接切过去
        let second = try #require(history.commits.dropFirst().first)
        session.activeView = .workingCopy

        session.showCommit(second)
        #expect(history.lookupCheckTask == nil)
        #expect(session.activeView == .history)
        #expect(history.selectedIDs == [second.id])

        await untilFinished { history.activeTasks }

        // 第 200 个提交不在第一页里
        let target = try await Self.commit(at: 200, with: fixture.runner)
        #expect(!history.commits.contains(target))

        session.showCommit(target)
        await untilFinished { history.activeTasks }

        #expect(history.commits.contains(target))
        #expect(history.scrollTarget == target.id)
        #expect(history.selectedIDs == [target.id])
        #expect(history.showsCommitPage)
        #expect(history.lookupFailure == nil)

        // 没有引用指向的提交不在任何历史里，不询问，直接说明找不到
        let orphan = try #require(fixture.orphan)

        session.showCommit(orphan)
        await untilFinished { history.activeTasks }

        #expect(
            history.lookupFailure
                == AppLocalization.text("history.reveal.notFound", String(orphan.id.prefix(8)))
        )

        #expect(history.selectedCommit == orphan)
        #expect(prompts.isEmpty)
    }

    /// 排在询问的阈值之后的提交要续载很多页，先核对位置再询问：核对期间又回到别的提交时前一个不询问；
    /// 取消时什么都不变，同意后才切换并续载到它为止；列表一直续载到根提交，不设总数上限。
    @Test("回到排在很后面的提交先询问")
    func revealAsksBeyondThreshold() async throws {
        let total = RepositoryHistoryState.slowLookupThreshold + 50
        let fixture = try await Self.makeSession(commits: (0 ..< total).map { "commit \($0)" })
        defer { fixture.close() }

        let history = fixture.session.history

        let target = try await Self.commit(
            at: RepositoryHistoryState.slowLookupThreshold + 20,
            with: fixture.runner
        )

        try await cancelSlowLookups(to: target, in: fixture)
        try await agreeSlowLookups(to: target, in: fixture)

        // 列表一直续载到根提交，不设总数上限
        while history.hasMore {
            history.loadNextPage(pageSize: 1000)
            await untilFinished { history.activeTasks }
        }

        #expect(history.commits.count == total)
        #expect(try #require(history.commits.last).parents.isEmpty)
    }

    /// 整页详情回到第一页之后的提交，找到以后列表又从第一页重读：列表里不再有它，详情仍显示它。
    @Test("整页详情回到的提交在列表重读后保留")
    func commitPageSurvivesReload() async throws {
        let fixture = try await Self.makeSession(commits: (0 ..< 150).map { "commit \($0)" })
        defer { fixture.close() }

        let session = fixture.session
        let history = session.history
        let target = try await Self.commit(at: 130, with: fixture.runner)

        // 打开整页详情，续载到这个提交
        history.showsCommitPage = true
        history.locate(target.id)
        await untilFinished { history.activeTasks }

        #expect(history.selectedCommit == target)

        // 列表从第一页重读
        history.reloadCommits()
        await untilFinished { history.activeTasks }

        #expect(!history.commits.contains(target))
        #expect(history.selectedIDs == [target.id])
        #expect(history.selectedCommit == target)
    }

    /// 工作区写出分支与改动数，分离 HEAD 时不写分支；历史写出所选引用与提交数，数到上限时写 “or more”。
    @Test("工作区与历史的窗口副标题")
    func subtitles() async throws {
        let fixture = try await Self.makeSession(
            commits: ["first", "second"],
            createsWindowController: true
        ) { runner, directory in
            _ = try await runner.run(["branch", "topic", "HEAD~1"])

            // 一个修改的文件与一个未跟踪的文件
            try Data("changed\n".utf8).write(to: directory.appending(path: "file.txt"))
            try Data("new\n".utf8).write(to: directory.appending(path: "new.txt"))
        }
        defer { fixture.close() }

        let session = fixture.session
        let controller = try #require(fixture.controller)
        #expect(controller.repositorySubtitle == AppLocalization.text("working.subtitle.branch", "main", 2))

        // 切到历史不另读，提交数在打开仓库时已经读好
        session.activeView = .history
        #expect(controller.repositorySubtitle == AppLocalization.text(
            "history.subtitle",
            AppLocalization.text("history.title"),
            2
        ))

        // 换选引用时当场重读第一页与提交数
        session.history.selectedReference = "refs/heads/topic"
        await untilFinished { session.history.activeTasks }
        #expect(controller.repositorySubtitle == AppLocalization.text("history.subtitle", "topic", 1))

        session.history.selectedReferences = ["refs/heads/main", "refs/heads/topic"]
        await untilFinished { session.history.activeTasks }
        #expect(controller.repositorySubtitle == AppLocalization.text("history.subtitle", "main, topic", 2))

        session.history.commitCount = RepositoryHistoryState.countLimit
        #expect(
            controller.repositorySubtitle
                == AppLocalization.text("history.subtitle.more", "main, topic", RepositoryHistoryState.countLimit)
        )

        // 分离 HEAD 时工作区不写分支
        _ = try await fixture.runner.run(["checkout", "-q", "--detach", "HEAD"])
        session.activeView = .workingCopy
        session.refresh(full: true)
        await session.waitForRefresh()
        #expect(controller.repositorySubtitle == AppLocalization.text("working.subtitle", 2))
    }

    /// 读取引用期间又要求刷新时，读完后按最新的请求再读一次，读取开始之后新建的分支随之出现。
    @Test("读取引用期间的刷新在读完后补上")
    func refreshDuringReferenceRead() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        let tools = try FileViewsTests.temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: tools)
        }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        _ = try await runner.run(["commit", "--allow-empty", "-q", "-m", "first"])

        // 读全部引用的命令读完后停在闸门上，放行后才交出结果；其余命令直接交给 Git
        let gate = try ProcessGate(in: tools)
        defer { gate.release() }

        let gated = try Self.scriptedRunner(location: location, tools: tools, cases: """
            *for-each-ref*--sort=refname*)
                output=$(mktemp)
                /usr/bin/git "$@" > "$output"
                code=$?
                \(gate.command)
                cat "$output"
                rm -f "$output"
                exit $code
                ;;
            """)

        let status = try await runner.status()
        let history = RepositoryHistoryState()
        defer { history.close() }

        // 第一次读取读完引用后停在闸门上，这时新建分支并再要求刷新
        history.refresh(status: status, runner: gated)
        await gate.arrival()

        _ = try await runner.run(["branch", "late"])
        history.refresh(status: status, runner: gated)

        // 放行两次：第一次读取交出没有新分支的结果，读完时补上的刷新读到它
        gate.release()
        gate.release()
        await untilFinished { history.activeTasks }

        #expect(history.snapshot?.references.contains { $0.id == "refs/heads/late" } ?? false)
    }
}

// MARK: - Slow Lookup

extension HistoryListTests {
    /// 回到提交前后应保持不变的视图与历史状态。
    private struct LookupScene: Equatable {
        /// 当前主视图。
        let activeView: RepositoryView

        /// 是否显示整页详情。
        let showsCommitPage: Bool

        /// 历史只看的引用。
        let selectedReferences: Set<String>

        /// 搜索条件。
        let searchConditions: [HistorySearchCondition]

        /// 列表里已加载的提交。
        let commits: [HistoryCommit]

        /// 选中的提交。
        let selectedIDs: Set<String>

        /// 正在查找的提交。
        let lookup: String?

        /// 是否正在读取列表。
        let isLoading: Bool

        /// 记下会话此刻的状态。
        @MainActor
        init(_ session: RepositorySession) {
            activeView = session.activeView
            showsCommitPage = session.history.showsCommitPage
            selectedReferences = session.history.selectedReferences
            searchConditions = session.history.searchConditions
            commits = session.history.commits
            selectedIDs = session.history.selectedIDs
            lookup = session.history.lookup
            isLoading = session.history.isLoading
        }
    }

    /// 取消询问：从 Working Copy 回到整页详情，核对期间又回到 `target` 时只询问它；在历史里从侧边栏回到它。
    /// 两处取消后视图、所选的引用、搜索条件、列表与选中的提交都不变。
    private func cancelSlowLookups(to target: HistoryCommit, in fixture: SessionFixture) async throws {
        let session = fixture.session
        let history = session.history

        // 停在 Working Copy；历史只看 main、搜着 “commit 1”，并选中一个已加载的提交
        history.selectedReferences = ["refs/heads/main"]
        history.setSearchText("commit 1")
        await untilFinished { history.activeTasks }

        #expect(history.query.isSearching)
        history.selectedIDs = [try #require(history.commits.dropFirst().first).id]

        // 取消询问时不回调，只记下询问
        var requests: [ConfirmationRequest] = []
        session.onConfirm = { requests.append($0) }

        let earlier = try await Self.commit(
            at: RepositoryHistoryState.slowLookupThreshold + 10,
            with: fixture.runner
        )

        // 核对 earlier 期间又回到 target，前一个核对作废，只询问 target；询问时还没切换
        var scene = LookupScene(session)
        session.showCommit(earlier)
        session.showCommit(target)
        await untilFinished { history.activeTasks }

        #expect(requests.map(\.title) == [AppLocalization.text("history.reveal.slow")])
        #expect(requests.map(\.submitTitle) == [AppLocalization.text("history.reveal.slow.submit")])

        #expect(
            requests.first?.message
                == AppLocalization.text(
                    "history.reveal.slow.message",
                    String(target.id.prefix(8)),
                    RepositoryHistoryState.slowLookupThreshold
                )
        )

        #expect(LookupScene(session) == scene)

        // 切到历史结束搜索，再从侧边栏回到 target 并取消
        session.activeView = .history
        await untilFinished { history.activeTasks }

        history.selectedIDs = [try #require(history.commits.dropFirst().first).id]
        scene = LookupScene(session)

        session.revealInHistory(target.id)
        await untilFinished { history.activeTasks }

        #expect(requests.count == 2)
        #expect(LookupScene(session) == scene)
    }

    /// 同意询问：从 Working Copy 回到 `target` 时切到整页详情并续载到它为止；
    /// 在历史里从侧边栏回到更靠后的提交时，询问框结束后窗口完整刷新、列表从第一页重读，仍选中它并读出它的变更。
    private func agreeSlowLookups(to target: HistoryCommit, in fixture: SessionFixture) async throws {
        let session = fixture.session
        let history = session.history
        var prompts = 0

        // 回到 Working Copy 再搜 “commit 1”，同意后切到整页详情，所选的引用与搜索条件随之清掉
        session.activeView = .workingCopy
        history.setSearchText("commit 1")
        await untilFinished { history.activeTasks }

        session.onConfirm = { request in
            prompts += 1
            request.action()
        }

        session.showCommit(target)
        await untilFinished { history.activeTasks }

        #expect(prompts == 1)
        #expect(session.activeView == .history)
        #expect(history.showsCommitPage)
        #expect(history.selectedReferences.isEmpty)
        #expect(history.searchConditions.isEmpty)
        #expect(history.commits.contains(target))
        #expect(history.selectedIDs == [target.id])
        #expect(history.lookup == nil)
        #expect(history.lookupFailure == nil)

        // 只看 main 时从侧边栏回到更靠后的提交；同意后窗口重新成为主窗口，完整刷新从第一页重读列表
        let deeper = try await Self.commit(
            at: RepositoryHistoryState.slowLookupThreshold + 40,
            with: fixture.runner
        )

        history.selectedReferences = ["refs/heads/main"]
        await untilFinished { history.activeTasks }

        session.onConfirm = { request in
            prompts += 1
            request.action()
            history.reloadCommits()
        }

        session.revealInHistory(deeper.id)
        await untilFinished { history.activeTasks }

        #expect(prompts == 2)
        #expect(!history.showsCommitPage)
        #expect(history.selectedReferences.isEmpty)
        #expect(history.selectedIDs == [deeper.id])
        #expect(history.selectedCommit == deeper)
        #expect(history.changes.map(\.path) == ["file.txt"])
    }
}

// MARK: - Fixture

extension HistoryListTests {
    /// 一个显示临时仓库的会话，按需带上它所在的窗口。
    struct SessionFixture {
        /// 仓库目录。
        let directory: URL

        /// 仓库的执行器。
        let runner: GitRunner

        /// 显示仓库的会话。
        let session: RepositorySession

        /// 会话所在的窗口；建立时没有要求则为 nil。
        let controller: RepositoryWindowController?

        /// 显示仓库之前另建的、没有引用指向的提交；建立时没有要求则为 nil。
        let orphan: HistoryCommit?

        /// 窗口的偏好域所在的临时目录；没有建窗口时为 nil。
        let defaultsDirectory: URL?

        /// 关闭会话与窗口，删除仓库与窗口的偏好域。
        @MainActor
        func close() {
            session.close()
            controller?.window?.close()
            try? FileManager.default.removeItem(at: directory)

            if let defaultsDirectory {
                try? FileManager.default.removeItem(at: defaultsDirectory)
            }
        }
    }

    /// 建立按顺序提交的仓库，每个提交改动 file.txt，再用会话显示它。
    ///
    /// 显示后再写入仓库，文件监听会引起自动刷新，重读历史时清掉找不到的说明。
    ///
    /// - Parameters:
    ///   - createsOrphan: 是否在显示仓库之前另建一个没有引用指向的提交，见 ``SessionFixture/orphan``。
    ///   - createsWindowController: 是否建出会话所在的窗口；副标题、远端变化后重读请求这类由窗口接上的行为才需要。
    ///   - prepare: 显示仓库之前对仓库的改动，参数是仓库的 runner 与目录；改动不会引起自动刷新。
    static func makeSession(
        commits: [String],
        createsOrphan: Bool = false,
        createsWindowController: Bool = false,
        prepare: (GitRunner, URL) async throws -> Void = { _, _ in }
    ) async throws -> SessionFixture {
        let directory = try FileViewsTests.temporaryDirectory()
        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        try await importCommits(commits, with: runner)

        // 在文件监听开始之前写入，不会引起自动刷新
        let orphan = createsOrphan ? try await makeOrphan(with: runner) : nil
        try await prepare(runner, directory)

        // 列表里的头像不联网，全部显示首字母
        AvatarStore.shared.fetch = { _ in nil }

        let session = RepositorySession(makeRunner: { _ in runner })
        var controller: RepositoryWindowController?
        var defaultsDirectory: URL?

        // 窗口要在显示仓库之前建好，与 App 里先有窗口、再在其中打开仓库的顺序相同
        if createsWindowController {
            let temporary = try temporaryDefaults()
            defaultsDirectory = temporary.directory

            controller = RepositoryWindowController(
                coordinator: SpookyApplicationController(bookmarks: RepositoryBookmarks(defaults: temporary.defaults)),
                session: session
            )
        }

        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()

        // 刷新带起的引用、第一页与提交数也都读完，测试从读好的历史开始
        await untilFinished { session.history.activeTasks }

        return SessionFixture(
            directory: directory,
            runner: runner,
            session: session,
            controller: controller,
            orphan: orphan,
            defaultsDirectory: defaultsDirectory
        )
    }

    /// 在空仓库的 main 上按顺序写入提交，每个提交改动 file.txt，提交人日期逐个递增。
    static func importCommits(_ messages: [String], with runner: GitRunner) async throws {
        // 一次 fast-import 写入全部提交
        var stream = ""

        for (index, message) in messages.enumerated() {
            let content = "\(index)\n"
            stream += "commit refs/heads/main\nmark :\(index + 1)\n"
            stream += "committer Spooky Test <spooky@example.invalid> \(1_700_000_000 + index * 60) +0000\n"
            stream += "data \(message.utf8.count)\n\(message)\n"
            stream += index == 0 ? "" : "from :\(index)\n"
            stream += "M 100644 inline file.txt\ndata \(content.utf8.count)\n\(content)\n"
        }

        _ = try await runner.run(["fast-import", "--quiet"], input: Data(stream.utf8))
        _ = try await runner.run(["reset", "-q", "--hard"])
    }

    /// 从 HEAD 沿历史往回数的第 `offset` 个提交，HEAD 是第 0 个。
    static func commit(at offset: Int, with runner: GitRunner) async throws -> HistoryCommit {
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let page = try await RepositoryHistory(runner: runner).page(
            roots: [head],
            offset: offset,
            limit: 1
        )

        return try #require(page.commits.first)
    }

    /// 经脚本执行 Git 的执行器：脚本按 `cases` 处理匹配的命令，其余命令直接交给 Git；
    /// 与临时仓库一样忽略系统和用户的全局配置。
    ///
    /// - Parameters:
    ///   - location: 仓库位置。
    ///   - tools: 放脚本的临时目录，由调用方删除。
    ///   - cases: 按命令参数匹配的 `case` 分支，每个分支自行以 `;;` 结束。
    static func scriptedRunner(location: RepositoryLocation, tools: URL, cases: String) throws -> GitRunner {
        let script = tools.appending(path: "scripted-git")

        try Data("""
            #!/bin/sh
            case "$*" in
            \(cases)
            esac
            exec /usr/bin/git "$@"
            """.utf8).write(to: script)

        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)

        return GitRunner(
            location: location,
            executablePath: script.path,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )
    }

    /// 用 HEAD 的树另建一个没有引用指向的提交，它不在仓库的任何历史里。
    private static func makeOrphan(with runner: GitRunner) async throws -> HistoryCommit {
        let tree = try await runner.run(["rev-parse", "HEAD^{tree}"])

        // commit-tree 只写入提交对象，不移动任何引用
        let dangling = try await runner.run([
            "commit-tree",
            String(decoding: tree, as: UTF8.self).trimmingCharacters(in: .newlines),
            "-m",
            "dangling",
        ])
        let id = String(decoding: dangling, as: UTF8.self).trimmingCharacters(in: .newlines)

        // 以它为根的第一条记录就是它自己
        let page = try await RepositoryHistory(runner: runner).page(roots: [id], limit: 1)

        return try #require(page.commits.first)
    }
}
