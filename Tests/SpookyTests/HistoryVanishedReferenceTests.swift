import AppKit
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - HistoryVanishedReferenceTests

/// 历史按引用筛选时，筛选的引用被删除或在获取时修剪：列表不能停在一个不存在的引用上变成空列表。
///
/// 选中的引用只去掉消失的那些；一个也不剩时，侧边栏选中原位置上接替它的行，先往下找、再往上找。
@MainActor
struct HistoryVanishedReferenceTests {
    /// 本地分支、标签与远端分支（获取时修剪）消失都走同一条路：去掉消失的引用，一个也不剩时回到全部历史并读出提交；
    /// 多选时留下仍在的引用。
    @Test("筛选的引用消失后只留下仍在的，一个不剩时回到全部历史")
    func vanishedReferences() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        try await HistoryListTests.importCommits(["first", "second"], with: runner)

        let history = RepositoryHistoryState()
        defer { history.close() }

        let removals: [(reference: String, create: [String], delete: [String])] = [
            ("refs/heads/gone", ["branch", "gone"], ["branch", "-q", "-D", "gone"]),
            ("refs/tags/v1", ["tag", "v1"], ["tag", "-d", "v1"]),
            ("refs/remotes/origin/gone", ["update-ref", "refs/remotes/origin/gone", "HEAD"], [
                "update-ref", "-d", "refs/remotes/origin/gone",
            ]),
        ]

        for removal in removals {
            _ = try await runner.run(removal.create)
            try await Self.refresh(history, runner: runner) { $0.contains(removal.reference) }

            history.selectedReferences = [removal.reference]
            try await FileViewsTests.wait { !history.isLoading && !history.commits.isEmpty }

            _ = try await runner.run(removal.delete)
            try await Self.refresh(history, runner: runner) { !$0.contains(removal.reference) }
            try await FileViewsTests.wait { !history.isLoading }

            #expect(history.selectedReferences.isEmpty, "\(removal.reference)")
            #expect(history.commits.count == 2, "\(removal.reference)")
        }

        // 多选时只去掉消失的那一个
        _ = try await runner.run(["branch", "gone"])
        try await Self.refresh(history, runner: runner) { $0.contains("refs/heads/gone") }

        history.selectedReferences = ["refs/heads/gone", "refs/heads/main"]
        _ = try await runner.run(["branch", "-q", "-D", "gone"])
        try await Self.refresh(history, runner: runner) { !$0.contains("refs/heads/gone") }

        #expect(history.selectedReferences == ["refs/heads/main"])
    }

    /// 侧边栏按行的位置接替：删掉的分支下面还有可选中的行时选中下面那一行；删掉的是最后一个可选中的行时往上找，选中上面那一行。
    @Test("筛选的分支消失后选中接替它的行")
    func replacementRow() async throws {
        let repository = try await RepositorySidebarViewTests.repository()
        defer { try? FileManager.default.removeItem(atPath: repository.location.path) }

        // 分支按名称排列：alpha、gone、main、zeta；Tags 默认收起，没有远端、子模块与工作树
        for name in ["alpha", "gone", "zeta"] {
            _ = try await repository.runner.run(["branch", name])
        }

        let session = RepositorySession(
            makeRunner: { _ in repository.runner },
            activities: RepositoryActivities()
        )

        defer { session.close() }

        session.display(repository.location)
        try await Self.refresh(session) { $0.contains("refs/heads/gone") }

        let window = RepositorySidebarViewTests.host(session)

        // 删掉中间的 gone：选中下面的 main
        let below = try await Self.delete("gone", filteredIn: session, window: window, runner: repository.runner)
        #expect(below == ["refs/heads/main"])

        // 删掉最后的 zeta：下面没有可选中的行，选中上面的 main
        let above = try await Self.delete("zeta", filteredIn: session, window: window, runner: repository.runner)
        #expect(above == ["refs/heads/main"])
    }

    /// 分支连同它所在的文件夹一起消失时按行号接替：文件夹下面的那一行补到文件夹的行号上，落到原行号上的是再下面一行。
    @Test("筛选的分支连同文件夹一起消失后按行号接替")
    func folderReplacementRow() async throws {
        let repository = try await RepositorySidebarViewTests.repository()
        defer { try? FileManager.default.removeItem(atPath: repository.location.path) }

        // 文件夹排在前面：feature（里面只有 x）、alpha、main、zeta
        for name in ["alpha", "feature/x", "zeta"] {
            _ = try await repository.runner.run(["branch", name])
        }

        let session = RepositorySession(
            makeRunner: { _ in repository.runner },
            activities: RepositoryActivities()
        )

        defer { session.close() }

        session.display(repository.location)
        try await Self.refresh(session) { $0.contains("refs/heads/feature/x") }

        let window = RepositorySidebarViewTests.host(session)

        // 等列表排好行，再展开 feature 文件夹
        try await FileViewsTests.wait {
            window.contentView?.layoutSubtreeIfNeeded()
            return Self.folderRow(in: window) != nil
        }

        let outline = try #require(window.contentView.flatMap(RepositorySidebarViewTests.outline(in:)))
        let rows = outline.numberOfRows
        let folder = try #require(Self.folderRow(in: window))

        outline.expandItem(outline.item(atRow: folder))

        try await FileViewsTests.wait {
            window.contentView?.layoutSubtreeIfNeeded()
            return outline.numberOfRows > rows
        }

        // x 与文件夹一起消失，alpha 补到文件夹的行号上，原行号上是 main
        let replacement = try await Self.delete(
            "feature/x",
            filteredIn: session,
            window: window,
            runner: repository.runner
        )

        #expect(replacement == ["refs/heads/main"])
    }

    /// 后退到筛选引用都已被删除的历史时留在当前视图，记录不变；位置停在那一步，再后退接着往前走。
    @Test("后退到筛选引用已删除的历史时留在当前视图")
    func navigateToVanishedReference() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let session = controller.session
        let runner = try #require(session.runner)
        let gone = ViewReference.repository(fixture.location, .history(references: ["refs/heads/gone"]))
        let main = ViewReference.repository(fixture.location, .history(references: ["refs/heads/main"]))

        _ = try await runner.run(["branch", "gone"])
        try await Self.refresh(session) { $0.contains("refs/heads/gone") }

        controller.show(gone)
        controller.show(main)

        _ = try await runner.run(["branch", "-q", "-D", "gone"])
        try await Self.refresh(session) { !$0.contains("refs/heads/gone") }

        let entries = controller.navigation.entries

        // 后退一步：仍是 main 的历史，位置停在已删除的那一步
        controller.navigateBack()
        #expect(session.activeView == .history)
        #expect(session.history.selectedReferences == ["refs/heads/main"])
        #expect(controller.navigation.entries == entries)
        #expect(controller.navigation.current == gone)

        // 再后退一步回到工作区
        controller.navigateBack()
        #expect(controller.currentReference == .repository(fixture.location, .workingCopy))
    }
}

// MARK: - Helpers

extension HistoryVanishedReferenceTests {
    /// 重读引用，等读到的引用名满足条件。
    private static func refresh(
        _ history: RepositoryHistoryState,
        runner: GitRunner,
        until condition: @escaping (Set<String>) -> Bool
    ) async throws {
        history.refresh(status: try await runner.status(), runner: runner)

        try await FileViewsTests.wait {
            condition(Set(history.snapshot?.references.map(\.id) ?? []))
        }
    }

    /// 完整刷新会话，等读到的引用名满足条件。
    private static func refresh(
        _ session: RepositorySession,
        until condition: @escaping (Set<String>) -> Bool
    ) async throws {
        session.refresh(full: true)
        await session.waitForRefresh()

        try await FileViewsTests.wait {
            condition(Set(session.history.snapshot?.references.map(\.id) ?? []))
        }
    }

    /// 按分支筛选历史，等侧边栏选中它的行后删掉这个分支并刷新；返回侧边栏接替后筛选的引用，没有接替时为空。
    private static func delete(
        _ branch: String,
        filteredIn session: RepositorySession,
        window: NSWindow,
        runner: GitRunner
    ) async throws -> Set<String> {
        let reference = "refs/heads/" + branch
        let previous = selectedRows(in: window)

        session.activeView = .history
        session.history.selectedReferences = [reference]

        // 列表换了选中的行，说明侧边栏已按这个筛选排好了行
        try await FileViewsTests.wait {
            window.contentView?.layoutSubtreeIfNeeded()
            return selectedRows(in: window) != previous
        }

        _ = try await runner.run(["branch", "-q", "-D", branch])
        try await refresh(session) { !$0.contains(reference) }

        // 侧边栏随后选中接替的行
        try await FileViewsTests.wait {
            window.contentView?.layoutSubtreeIfNeeded()
            return !session.history.selectedReferences.isEmpty
        }

        return session.history.selectedReferences
    }

    /// 侧边栏列表选中的行号。
    private static func selectedRows(in window: NSWindow) -> IndexSet? {
        window.contentView.flatMap(RepositorySidebarViewTests.outline(in:))?.selectedRowIndexes
    }

    /// 侧边栏列表里分组下第一个可展开的行的行号；列表还没有排好行时为 nil。
    private static func folderRow(in window: NSWindow) -> Int? {
        guard let outline = window.contentView.flatMap(RepositorySidebarViewTests.outline(in:)) else {
            return nil
        }

        return (0 ..< outline.numberOfRows).first {
            outline.level(forRow: $0) == 1 && outline.isExpandable(outline.item(atRow: $0))
        }
    }
}
