import AppKit
import Foundation
import Testing

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
        try await FileViewsTests.wait { history.commits.count == 3 && history.commitCount == 3 }
        #expect(!history.graphRows.isEmpty)

        history.setSearchText("FIX")
        try await FileViewsTests.wait { history.query.isSearching && !history.isLoading && history.commitCount != nil }
        #expect(history.commits.map(\.subject) == ["gamma fix", "alpha fix"])
        #expect(history.commitCount == 2)

        // 搜索结果不连续，不画提交图
        #expect(history.graphRows.isEmpty)

        // 连续输入只按最后一次的内容重读，过时的结果不会覆盖
        history.setSearchText("a")
        history.setSearchText("al")
        history.setSearchText("gamma")
        try await FileViewsTests.wait { history.searchTask == nil && !history.isLoading && history.commitCount != nil }
        #expect(history.commits.map(\.subject) == ["gamma fix"])

        // 换成按作者搜索，再加一个提交信息条件，两类条件取交集
        history.setSearchText("spooky")
        history.setSearchScope(.author)
        let added = history.addSearchCondition()
        var condition = try #require(history.searchConditions.first { $0.id == added })
        condition.text = "beta"
        history.updateSearchCondition(condition)
        try await FileViewsTests.wait { history.searchTask == nil && !history.isLoading && history.commitCount == 1 }
        #expect(history.commits.map(\.subject) == ["beta"])
        #expect(history.primarySearchKind == .author)
        #expect(history.primarySearchText == "spooky")

        // 移除一个条件后只剩作者条件；切换视图结束搜索并重读完整历史
        history.removeSearchCondition(added)
        try await FileViewsTests.wait { history.searchTask == nil && !history.isLoading && history.commitCount == 3 }
        fixture.session.activeView = .history
        fixture.session.activeView = .workingCopy
        #expect(history.searchConditions.isEmpty)
        try await FileViewsTests.wait { !history.query.isSearching && !history.isLoading && history.commits.count == 3 }
    }

    /// 回到的提交不在已加载的分页里时按 1000 条续载直到找到，排在询问的阈值以内不询问；找不到时说明原因。
    @Test("回到历史时扩大加载并选中提交")
    func revealExpandsLoading() async throws {
        let fixture = try await Self.makeSession(commits: (0 ..< 250).map { "commit \($0)" })
        defer { fixture.close() }

        let history = fixture.session.history
        try await FileViewsTests.wait { !history.commits.isEmpty && !history.isLoading }
        #expect(history.commits.count < 250)

        // 记下所有询问，不回调
        var prompts: [String] = []
        fixture.session.onConfirm = { title, _, _, _ in prompts.append(title) }

        // 第 200 个提交不在第一页里
        let head = try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
        let page = try await RepositoryHistory(runner: fixture.runner).page(roots: [head], offset: 200, limit: 1)
        let target = try #require(page.commits.first)
        #expect(!history.commits.contains(target))

        fixture.session.showCommit(target)
        try await FileViewsTests.wait { history.lookup == nil && !history.isLoading }
        #expect(history.commits.contains(target))
        #expect(history.scrollTarget == target.id)
        #expect(history.selectedIDs == [target.id])
        #expect(history.showsCommitPage)
        #expect(history.lookupFailure == nil)
        #expect(prompts.isEmpty)

        // 没有引用指向的提交不在任何历史里
        let orphan = try await Self.makeOrphan(in: fixture)

        fixture.session.showCommit(orphan)
        try await FileViewsTests.wait { history.lookupFailure != nil }
        #expect(
            history.lookupFailure
                == AppLocalization.text("history.reveal.notFound", String(orphan.id.prefix(8)))
        )
        #expect(history.selectedCommit == orphan)
        #expect(prompts.isEmpty)
    }

    /// 排在询问的阈值之后的提交要续载很多页，先询问：取消时列表不变，同意后续载到它为止；不在历史里的提交直接说明找不到。
    @Test("回到排在很后面的提交先询问")
    func revealAsksBeyondThreshold() async throws {
        let total = RepositoryHistoryState.slowLookupThreshold + 50
        let fixture = try await Self.makeSession(commits: (0 ..< total).map { "commit \($0)" })
        defer { fixture.close() }

        let session = fixture.session
        let history = session.history
        try await FileViewsTests.wait { !history.commits.isEmpty && !history.isLoading }
        let loaded = history.commits.count

        // 取消询问时不回调，只记下询问的标题与说明
        var prompts: [(title: String, message: String)] = []
        session.onConfirm = { title, message, _, _ in prompts.append((title, message)) }

        // 没有引用指向的提交不在这段历史里，不询问
        let orphan = try await Self.makeOrphan(in: fixture)

        session.showCommit(orphan)
        try await FileViewsTests.wait { history.lookupFailure != nil && !history.isLoading }
        #expect(
            history.lookupFailure
                == AppLocalization.text("history.reveal.notFound", String(orphan.id.prefix(8)))
        )
        #expect(prompts.isEmpty)

        // 排在第 10,000 个之后的提交先询问，取消后不加载、不说明
        let head = try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
        let offset = RepositoryHistoryState.slowLookupThreshold + 20
        let page = try await RepositoryHistory(runner: fixture.runner).page(
            roots: [head],
            offset: offset,
            limit: 1
        )
        let target = try #require(page.commits.first)

        session.showCommit(target)
        try await FileViewsTests.wait { prompts.count == 1 && !history.isLoading }
        #expect(prompts.first?.title == AppLocalization.text("history.reveal.slow"))
        #expect(
            prompts.first?.message
                == AppLocalization.text(
                    "history.reveal.slow.message",
                    String(target.id.prefix(8)),
                    RepositoryHistoryState.slowLookupThreshold
                )
        )
        #expect(history.lookup == nil)
        #expect(history.lookupFailure == nil)
        #expect(history.commits.count == loaded)

        // 同意后续载到它为止，选中并滚动到它
        session.onConfirm = { title, message, action, _ in
            prompts.append((title, message))
            action()
        }

        session.showCommit(target)
        try await FileViewsTests.wait { history.scrollTarget == target.id && !history.isLoading }
        #expect(prompts.count == 2)
        #expect(history.commits.contains(target))
        #expect(history.selectedIDs == [target.id])
        #expect(history.lookup == nil)
        #expect(history.lookupFailure == nil)

        // 列表一直续载到根提交，不设总数上限
        while history.hasMore {
            history.loadNextPage(pageSize: 1000)
            try await FileViewsTests.wait { !history.isLoading }
        }

        #expect(history.commits.count == total)
        #expect(try #require(history.commits.last).parents.isEmpty)
    }

    /// 从侧边栏回到排在询问的阈值之后的提交：询问框结束后窗口完整刷新、列表从第一页重读，同意后仍选中它，找到后读出它的变更。
    @Test("同意询问后列表重读，仍选中要回到的提交")
    func revealKeepsSelectionAfterReload() async throws {
        let total = RepositoryHistoryState.slowLookupThreshold + 50
        let fixture = try await Self.makeSession(commits: (0 ..< total).map { "commit \($0)" })
        defer { fixture.close() }

        let session = fixture.session
        let history = session.history
        try await FileViewsTests.wait { !history.commits.isEmpty && !history.isLoading }

        let head = try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
        let page = try await RepositoryHistory(runner: fixture.runner).page(
            roots: [head],
            offset: RepositoryHistoryState.slowLookupThreshold + 20,
            limit: 1
        )
        let target = try #require(page.commits.first)

        // 同意后窗口重新成为主窗口，完整刷新从第一页重读列表
        session.onConfirm = { _, _, action, _ in
            action()
            history.reloadCommits()
        }

        session.revealInHistory(target.id)
        try await FileViewsTests.wait { history.scrollTarget == target.id && !history.isLoading }
        try await FileViewsTests.wait { !history.isLoadingChanges }

        #expect(history.selectedIDs == [target.id])
        #expect(history.selectedCommit == target)
        #expect(history.changes.map(\.path) == ["file.txt"])
    }

    /// 工作区写出分支与改动数，分离 HEAD 时不写分支；历史写出所选引用与提交数，数到上限时写 “or more”。
    @Test("工作区与历史的窗口副标题")
    func subtitles() async throws {
        let fixture = try await Self.makeSession(commits: ["first", "second"])
        defer { fixture.close() }

        let session = fixture.session
        let controller = fixture.controller
        _ = try await fixture.runner.run(["branch", "topic", "HEAD~1"])

        // 一个修改的文件与一个未跟踪的文件
        try Data("changed\n".utf8).write(to: fixture.directory.appending(path: "file.txt"))
        try Data("new\n".utf8).write(to: fixture.directory.appending(path: "new.txt"))
        session.refresh(full: true)
        await session.waitForRefresh()
        #expect(controller.repositorySubtitle == AppLocalization.text("working.subtitle.branch", "main", 2))

        session.activeView = .history
        try await FileViewsTests.wait { session.history.commitCount == 2 }
        #expect(controller.repositorySubtitle == AppLocalization.text(
            "history.subtitle",
            AppLocalization.text("history.title"),
            2
        ))

        session.history.selectedReference = "refs/heads/topic"
        try await FileViewsTests.wait { session.history.commitCount == 1 }
        #expect(controller.repositorySubtitle == AppLocalization.text("history.subtitle", "topic", 1))

        session.history.selectedReferences = ["refs/heads/main", "refs/heads/topic"]
        try await FileViewsTests.wait { session.history.commitCount == 2 }
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

        // 读全部引用的命令读完先留下记号，等闸门文件出现后才交出结果；其余命令直接交给 Git
        let script = tools.appending(path: "gated-git")
        try Data("""
            #!/bin/sh
            case "$*" in
                *for-each-ref*--sort=refname*)
                    tools=$(dirname "$0")
                    output=$(mktemp)
                    /usr/bin/git "$@" > "$output"
                    code=$?
                    : > "$tools/read"
                    while [ ! -e "$tools/gate" ]; do sleep 0.02; done
                    cat "$output"
                    rm -f "$output"
                    exit $code
                    ;;
            esac
            exec /usr/bin/git "$@"
            """.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)

        let gated = GitRunner(
            location: location,
            executablePath: script.path,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )
        let status = try await runner.status()
        let history = RepositoryHistoryState()
        defer { history.close() }

        // 第一次读取读完引用后停在闸门前，这时新建分支并再要求刷新
        history.refresh(status: status, runner: gated)
        try await FileViewsTests.wait { FileManager.default.fileExists(atPath: tools.appending(path: "read").path) }
        _ = try await runner.run(["branch", "late"])
        history.refresh(status: status, runner: gated)

        // 闸门打开后，第一次读取交出没有新分支的结果，补上的刷新读到它
        try Data().write(to: tools.appending(path: "gate"))
        try await FileViewsTests.wait { history.snapshot?.references.contains { $0.id == "refs/heads/late" } ?? false }
    }
}

// MARK: - Fixture

extension HistoryListTests {
    /// 一个打开了临时仓库的窗口与会话。
    struct SessionFixture {
        /// 仓库目录。
        let directory: URL

        /// 仓库的执行器。
        let runner: GitRunner

        /// 显示仓库的会话。
        let session: RepositorySession

        /// 会话所在的窗口。
        let controller: RepositoryWindowController

        /// 关闭会话与窗口并删除仓库。
        @MainActor
        func close() {
            session.close()
            controller.window?.close()
            try? FileManager.default.removeItem(at: directory)
        }
    }

    /// 建立按顺序提交的仓库，每个提交改动 file.txt，再打开窗口显示它。
    static func makeSession(commits: [String]) async throws -> SessionFixture {
        let directory = try FileViewsTests.temporaryDirectory()
        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        // 一次 fast-import 写入全部提交，提交人日期逐个递增
        var stream = ""

        for (index, message) in commits.enumerated() {
            let content = "\(index)\n"
            stream += "commit refs/heads/main\nmark :\(index + 1)\n"
            stream += "committer Spooky Test <spooky@example.invalid> \(1_700_000_000 + index * 60) +0000\n"
            stream += "data \(message.utf8.count)\n\(message)\n"
            stream += index == 0 ? "" : "from :\(index)\n"
            stream += "M 100644 inline file.txt\ndata \(content.utf8.count)\n\(content)\n"
        }

        _ = try await runner.run(["fast-import", "--quiet"], input: Data(stream.utf8))
        _ = try await runner.run(["reset", "-q", "--hard"])

        // 列表里的头像不联网，全部显示首字母
        AvatarStore.shared.fetch = { _ in nil }

        let defaults = try temporaryDefaults()
        let session = RepositorySession(makeRunner: { _ in runner })
        let controller = RepositoryWindowController(
            coordinator: SpookyApplicationController(bookmarks: RepositoryBookmarks(defaults: defaults)),
            session: session
        )

        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()

        return SessionFixture(directory: directory, runner: runner, session: session, controller: controller)
    }

    /// 用 HEAD 的树另建一个没有引用指向的提交，它不在仓库的任何历史里。
    static func makeOrphan(in fixture: SessionFixture) async throws -> HistoryCommit {
        let tree = try await fixture.runner.run(["rev-parse", "HEAD^{tree}"])
        let dangling = try await fixture.runner.run(
            ["commit-tree", String(decoding: tree, as: UTF8.self).trimmingCharacters(in: .newlines), "-m", "dangling"]
        )
        let id = String(decoding: dangling, as: UTF8.self).trimmingCharacters(in: .newlines)
        let page = try await RepositoryHistory(runner: fixture.runner).page(roots: [id], limit: 1)

        return try #require(page.commits.first)
    }
}
