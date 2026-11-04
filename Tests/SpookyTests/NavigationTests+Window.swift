import AppKit
import Foundation
import SwiftUI
import Synchronization
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Window

extension NavigationTests {
    /// 一个打开了临时仓库的窗口；协调者由测试持有，窗口只弱引用它。
    struct WindowFixture {
        /// 仓库目录。
        let directory: URL

        /// 仓库位置。
        let location: RepositoryLocation

        /// 窗口的协调者。
        let coordinator: SpookyApplicationController

        /// 显示仓库的窗口。
        let controller: RepositoryWindowController

        /// 独立的偏好域，测试结束时随它所在的临时目录删除。
        let defaults: UserDefaults

        /// 偏好域所在的临时目录。
        let defaultsDirectory: URL

        /// 独有工具栏的标识。
        let toolbarIdentifier: String

        /// 关闭全部窗口，删除仓库、偏好域与独有工具栏的配置。
        @MainActor
        func close() {
            for window in coordinator.windows + [controller] {
                window.session.close()
                window.window?.close()
            }

            try? FileManager.default.removeItem(at: defaultsDirectory)
            try? FileManager.default.removeItem(at: directory)

            // 独有工具栏自动保存的配置写在标准偏好里，键名带着它的标识
            UserDefaults.standard.removeObject(forKey: "NSToolbar Configuration " + toolbarIdentifier)
        }
    }

    /// 一个提交过一次的临时仓库与一个协调者，不建窗口：给只用到协调者的测试，省去显示仓库与读第一次刷新。
    struct CoordinatorFixture {
        /// 临时目录，里面放着仓库与协调者的偏好文件。
        let root: URL

        /// 仓库目录。
        let directory: URL

        /// 仓库位置。
        let location: RepositoryLocation

        /// 测试持有的协调者，书签记在临时目录里的偏好文件中。
        let coordinator: SpookyApplicationController

        /// 关闭协调者开出的全部窗口，删除临时目录。
        @MainActor
        func close() {
            for window in coordinator.windows {
                window.session.close()
                window.window?.close()
            }

            try? FileManager.default.removeItem(at: root)
        }
    }

    /// 建立临时仓库，用窗口打开它并读完第一次刷新。
    ///
    /// - Parameters:
    ///   - commits: 按顺序写入 main 的提交信息；nil 时只有一个添加 a.txt 的提交。
    ///   - isolatesToolbar: 工具栏改用本窗口独有的标识。切换显示方式的测试都要打开：同一标识的工具栏会同步显示方式，
    ///     切换一次就要逐个重排同一进程里其它测试的全部仓库窗口。
    static func makeWindow(commits: [String]? = nil, isolatesToolbar: Bool = false) async throws -> WindowFixture {
        let directory = try FileViewsTests.temporaryDirectory()
        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        if let commits {
            try await HistoryListTests.importCommits(commits, with: runner)
        } else {
            try await commitFirstFile(in: directory, with: runner)
        }

        // 偏好域放在以本窗口标识命名的临时目录里，不放进仓库，工作区里不多出文件
        let identifier = "spooky-navigation-" + UUID().uuidString
        let defaultsDirectory = FileManager.default.temporaryDirectory.appending(path: identifier)
        let defaults = try #require(UserDefaults(suiteName: defaultsDirectory.appending(path: "defaults").path))
        let coordinator = SpookyApplicationController(bookmarks: RepositoryBookmarks(defaults: defaults))
        let controller = RepositoryWindowController(
            coordinator: coordinator,
            session: RepositorySession(makeRunner: { _ in runner }),
            toolbarIdentifier: isolatesToolbar ? NSToolbar.Identifier(identifier) : RepositoryToolbar.identifier
        )

        controller.display(location)
        await controller.session.waitForRefresh()

        return WindowFixture(
            directory: directory,
            location: location,
            coordinator: coordinator,
            controller: controller,
            defaults: defaults,
            defaultsDirectory: defaultsDirectory,
            toolbarIdentifier: identifier
        )
    }

    /// 建立一个只有添加 a.txt 这一个提交的临时仓库，以及书签记在临时目录里的协调者。
    static func makeCoordinator() async throws -> CoordinatorFixture {
        // 仓库放在临时目录的子目录里，偏好文件不出现在工作区中
        let root = try FileViewsTests.temporaryDirectory()
        let directory = root.appending(path: "repository", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        try await commitFirstFile(in: directory, with: runner)

        // 偏好以临时目录里的文件路径作 suite 名，随临时目录一起删除
        let defaults = try #require(UserDefaults(suiteName: root.appending(path: "defaults").path))

        return CoordinatorFixture(
            root: root,
            directory: directory,
            location: location,
            coordinator: SpookyApplicationController(bookmarks: RepositoryBookmarks(defaults: defaults))
        )
    }

    /// 后退与前进按每个窗口自己的记录走，菜单与工具栏的可用性跟着记录变；从中间位置去别的视图后，前进的记录作废。
    /// 窗口显示仓库管理时，⌘1–⌘6 与 ⌘0 都不可用，后退照常可用；回到仓库后切换视图的各项恢复可用。
    @Test("仓库窗口的后退与前进，显示仓库管理时不能切换主视图")
    func windowBackForward() async throws {
        let fixture = try await Self.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let location = fixture.location
        let back = NSMenuItem(title: "", action: #selector(RepositoryWindowController.navigateBack), keyEquivalent: "")
        let forward = NSMenuItem(title: "", action: #selector(RepositoryWindowController.navigateForward), keyEquivalent: "")

        // 切换主视图的 ⌘1–⌘6 与 ⌘0，显示仓库时都可用
        let switching = [
            #selector(RepositoryWindowController.showWorkingCopy),
            #selector(RepositoryWindowController.showHistory),
            #selector(RepositoryWindowController.showStashes),
            #selector(RepositoryWindowController.showPullRequests),
            #selector(RepositoryWindowController.showBranchesReview),
            #selector(RepositoryWindowController.showReflog),
            #selector(RepositoryWindowController.showHeadBranch),
        ].map { NSMenuItem(title: "", action: $0, keyEquivalent: "") }

        #expect(switching.allSatisfy { controller.validateUserInterfaceItem($0) })

        controller.showHistory()
        controller.showStashes()
        #expect(controller.navigation.entries == [
            .repositories,
            .repository(location, .workingCopy),
            .repository(location, .history(references: [])),
            .repository(location, .stashes),
        ])
        #expect(controller.validateUserInterfaceItem(back))
        #expect(!controller.validateUserInterfaceItem(forward))

        controller.navigateBack()
        #expect(controller.session.activeView == .history)

        controller.navigateBack()
        #expect(controller.session.activeView == .workingCopy)

        controller.navigateBack()
        #expect(controller.showsManager)
        #expect(!controller.validateUserInterfaceItem(back))

        // 前进回到仓库：会话仍保留着这个仓库，直接切回
        controller.navigateForward()
        #expect(!controller.showsManager)
        #expect(controller.currentReference == .repository(location, .workingCopy))
        #expect(controller.validateUserInterfaceItem(forward))

        controller.showReflog()
        #expect(controller.navigation.entries.last == .repository(location, .reflog))
        #expect(!controller.navigation.entries.contains(.repository(location, .stashes)))
        #expect(!controller.validateUserInterfaceItem(forward))

        // 去仓库管理后不能切换主视图，后退照常可用；后退回到仓库后恢复
        controller.showRepositories()
        #expect(controller.showsManager)
        #expect(switching.allSatisfy { !controller.validateUserInterfaceItem($0) })
        #expect(controller.validateUserInterfaceItem(back))

        controller.navigateBack()
        #expect(!controller.showsManager)
        #expect(switching.allSatisfy { controller.validateUserInterfaceItem($0) })
    }

    /// 按引用切换视图会带上选择：历史选中的引用、提交整页、文件原文的版本与模式，当前引用随之一致。
    @Test("按视图引用切换视图与选择")
    func showReferences() async throws {
        let fixture = try await Self.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let session = controller.session
        let location = fixture.location
        let head = try #require(session.status?.branch.oid)

        let history = ViewReference.repository(location, .history(references: ["refs/heads/main"]))
        controller.show(history)
        #expect(session.history.selectedReferences == ["refs/heads/main"])
        #expect(controller.currentReference == history)

        // 列表只看 main 时先核对提交的位置，核对完才切到整页详情
        let commit = ViewReference.repository(location, .commit(head))
        controller.show(commit)
        try await FileViewsTests.wait { session.history.showsCommitPage }
        #expect(controller.currentReference == commit)

        let blame = ViewReference.repository(location, .file(path: "a.txt", revision: head, mode: .blame))
        controller.show(blame)
        #expect(session.activeView == .fileContent)
        #expect(session.fileContent.mode == .blame)
        #expect(controller.currentReference == blame)

        // 中途经过的视图不进记录，后退一步就回到提交整页
        controller.navigateBack()
        try await FileViewsTests.wait { controller.currentReference == commit }
    }

    /// 经链接、后退或前进回到排在询问的阈值之后的提交：询问时还没切换，取消后视图与后退 / 前进的位置、记录都不变；同意后才切到整页详情。
    @Test("回到很靠后的提交先询问，取消时窗口不变")
    func slowCommitReference() async throws {
        let total = RepositoryHistoryState.slowLookupThreshold + 50
        let fixture = try await Self.makeWindow(commits: (0 ..< total).map { "commit \($0)" })
        defer { fixture.close() }

        let controller = fixture.controller
        let session = controller.session
        let history = session.history
        let runner = try #require(session.runner)
        try await FileViewsTests.wait { !history.commits.isEmpty && !history.isLoading }

        let far = try await HistoryListTests.commit(
            at: RepositoryHistoryState.slowLookupThreshold + 20,
            with: runner
        )

        let working = ViewReference.repository(fixture.location, .workingCopy)
        let page = ViewReference.repository(fixture.location, .commit(far.id))

        // 记下询问的次数，按开关决定同意还是取消
        var prompts = 0
        var agrees = false

        session.onConfirm = { request in
            prompts += 1
            if agrees { request.action() }
        }

        // 链接：询问时窗口仍在 Working Copy，取消后视图与记录都不变
        let entries = controller.navigation.entries
        controller.show(page)
        try await FileViewsTests.wait { prompts == 1 }

        #expect(controller.currentReference == working)
        #expect(controller.navigation.entries == entries)

        // 同意后切到整页详情，续载到它并记进后退 / 前进
        agrees = true
        controller.show(page)
        try await FileViewsTests.wait {
            history.commits.contains(far) && history.lookup == nil && !history.isLoading
        }

        #expect(prompts == 2)
        #expect(controller.currentReference == page)
        #expect(controller.navigation.entries == entries + [page])

        // 去 Stashes，并让列表只看 main，回到这个提交又要核对位置
        controller.showStashes()
        let stashes = controller.currentReference
        history.selectedReferences = ["refs/heads/main"]

        // 后退：取消时位置与视图都不变
        agrees = false
        controller.navigateBack()
        try await FileViewsTests.wait { prompts == 3 }

        #expect(controller.currentReference == stashes)
        #expect(controller.navigation.current == stashes)
        #expect(!controller.navigation.canGoForward)

        // 同意后才后退到整页详情
        agrees = true
        controller.navigateBack()
        try await FileViewsTests.wait {
            controller.currentReference == page && history.lookup == nil && !history.isLoading
        }

        #expect(prompts == 4)
        #expect(controller.navigation.current == page)
        #expect(controller.navigation.next == stashes)

        // 再退到 Working Copy 不用询问；列表只看 main 后前进，取消时同样不动
        controller.navigateBack()
        #expect(controller.currentReference == working)

        history.selectedReferences = ["refs/heads/main"]
        agrees = false
        controller.navigateForward()
        try await FileViewsTests.wait { prompts == 5 }

        #expect(controller.currentReference == working)
        #expect(controller.navigation.current == working)

        // 同意后才前进到整页详情
        agrees = true
        controller.navigateForward()
        try await FileViewsTests.wait { controller.currentReference == page }

        #expect(prompts == 6)
        #expect(controller.navigation.current == page)
    }

    /// 窗口恢复写下当前视图引用，重新启动后按它重新打开同一个仓库与视图。
    @Test("窗口恢复按保存的视图引用重新打开仓库")
    func restoreSavedReference() async throws {
        let fixture = try await Self.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        controller.showHistory()
        controller.session.history.selectedReferences = ["refs/heads/main"]

        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        try controller.window(#require(controller.window), willEncodeRestorableState: archiver)
        archiver.finishEncoding()

        let state = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        let window = try #require(fixture.coordinator.restoreWindow(from: state))
        let restored = try #require(window.windowController as? RepositoryWindowController)

        // 经正常的打开流程验证仓库后显示，位置换成规范的根路径；与已显示同一仓库的窗口互不合并
        try await FileViewsTests.wait { !restored.showsManager }
        let resolved = try #require(realpath(fixture.directory.path, nil))
        defer { free(resolved) }

        let root = RepositoryLocation.local(path: String(cString: resolved))

        #expect(restored !== controller)
        #expect(restored.currentReference == .repository(root, .history(references: ["refs/heads/main"])))
    }

    /// 读不出视图引用时窗口留在仓库管理；仓库已不存在时窗口换成丢失页，书签标为失效。
    @Test("恢复失败时显示仓库管理或丢失页")
    func restoreFailure() async throws {
        let fixture = try await Self.makeCoordinator()
        defer { fixture.close() }

        let coordinator = fixture.coordinator

        let garbage = NSKeyedArchiver(requiringSecureCoding: true)
        garbage.encode("repository?view=nothing", forKey: RepositoryWindowController.viewReferenceKey)
        garbage.finishEncoding()

        let window = try coordinator.restoreWindow(from: NSKeyedUnarchiver(forReadingFrom: garbage.encodedData))
        let manager = try #require(window?.windowController as? RepositoryWindowController)
        #expect(manager.showsManager)
        #expect(manager.currentReference == .repositories)

        // 书签里有这个仓库，打开失败后才有书签可以标为失效
        let missing = RepositoryLocation.local(path: fixture.directory.appending(path: "missing").path)
        coordinator.bookmarks.add(missing)

        let gone = NSKeyedArchiver(requiringSecureCoding: true)
        gone.encode(ViewReference.repository(missing, .workingCopy).string, forKey: RepositoryWindowController.viewReferenceKey)
        gone.finishEncoding()

        let failed = try coordinator.restoreWindow(from: NSKeyedUnarchiver(forReadingFrom: gone.encodedData))
        let controller = try #require(failed?.windowController as? RepositoryWindowController)

        // 仓库管理的后台检查也会标记失效，以丢失页出现为准
        try await FileViewsTests.wait {
            controller.window?.contentViewController is NSHostingController<MissingRepositoryView>
        }

        #expect(!controller.showsManager)
        #expect(coordinator.bookmarks.isMissing(missing))
    }
}

// MARK: - Missing Repository

extension NavigationTests {
    /// 丢失页出现时与窗口重新成为主窗口时都会重试：仓库在就换回仓库界面；
    /// 仍不在时页面原样留着，不弹错误，也不把书签标为失效，页面不重建也就不会反复重试。
    @Test("丢失页自动重试")
    func missingRepositoryRetry() async throws {
        let fixture = try await Self.makeCoordinator()
        defer { fixture.close() }

        // 挪走的仓库仍在临时目录里，随它一起删除
        let moved = fixture.root.appending(path: "moved", directoryHint: .isDirectory)

        // 重试只在协调者管着的窗口里换回仓库，测试的窗口因此由协调者建出
        let controller = fixture.coordinator.makeWindow()

        let showsRepository = {
            !(controller.window?.contentViewController is NSHostingController<MissingRepositoryView>)
                && controller.session.repository != nil
        }

        // 仓库还在时，丢失页一出现就换回仓库界面
        controller.showMissingRepository(fixture.location, reason: .notFound)
        #expect(!showsRepository())
        try await FileViewsTests.wait(showsRepository)

        let restored = try #require(controller.session.repository)

        // 目录不见后，出现时的重试打不开仓库
        try FileManager.default.moveItem(at: fixture.directory, to: moved)
        controller.showMissingRepository(fixture.location, reason: .notFound)
        let page = controller.window?.contentViewController

        // 出现时的重试排在主线程上：让出一会儿后它已经发起，再等它结束
        try await Task.sleep(for: .milliseconds(50))
        try await FileViewsTests.wait { controller.openingRequest == nil }

        #expect(controller.window?.contentViewController === page)
        #expect(controller.window?.attachedSheet == nil)
        #expect(!fixture.coordinator.bookmarks.isMissing(restored))

        // 目录放回后，窗口再次成为主窗口时换回仓库界面
        try FileManager.default.moveItem(at: moved, to: fixture.directory)
        controller.windowDidBecomeMain(
            Notification(name: NSWindow.didBecomeMainNotification, object: controller.window)
        )
        #expect(controller.openingRequest != nil)
        try await FileViewsTests.wait(showsRepository)
    }

    /// 重试不是用户发起的，验证位置时不允许询问用户；同一窗口上一次重试还没结束时不发起新的重试。
    @Test("丢失页的重试不询问用户")
    func missingRepositoryRetryIsQuiet() async throws {
        let fixture = try await Self.makeCoordinator()
        defer { fixture.close() }

        let coordinator = fixture.coordinator
        let controller = coordinator.makeWindow()
        let interactions = Mutex<[Bool]>([])

        let task = coordinator.retryMissingRepository(fixture.location, in: controller) { _ in
            interactions.withLock { $0.append(RemoteCallbackRequest.allowsInteraction) }
            try await Task.sleep(for: .milliseconds(100))
            throw CocoaError(.fileNoSuchFile)
        }

        #expect(task != nil)
        #expect(coordinator.retryMissingRepository(fixture.location, in: controller) == nil)

        await task?.value
        #expect(interactions.withLock { $0 } == [false])
        #expect(controller.openingRequest == nil)
    }

    /// 重试期间窗口回到了仓库管理时，仓库回来了也不把窗口换回仓库界面。
    @Test("离开丢失页后重试不换回仓库")
    func missingRepositoryRetryAfterLeaving() async throws {
        let fixture = try await Self.makeCoordinator()
        defer { fixture.close() }

        let coordinator = fixture.coordinator
        let controller = coordinator.makeWindow()

        // 页面出现时的重试会立即换回仓库，先发起一次慢的重试占住窗口
        let task = coordinator.retryMissingRepository(fixture.location, in: controller) { location in
            try await Task.sleep(for: .milliseconds(200))
            return location
        }

        controller.showMissingRepository(fixture.location, reason: .notFound)
        #expect(controller.missingLocation == fixture.location)

        controller.showRepositories()
        await task?.value

        #expect(controller.showsManager)
        #expect(controller.missingLocation == nil)
    }
}

// MARK: - Helpers

extension NavigationTests {
    /// 写入内容为 “one” 的 a.txt，提交为 “first”。
    private static func commitFirstFile(in directory: URL, with runner: GitRunner) async throws {
        try Data("one\n".utf8).write(to: directory.appending(path: "a.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "first"])
    }
}
