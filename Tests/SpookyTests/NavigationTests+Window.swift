import AppKit
import Foundation
import SwiftUI
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

        /// 独立的偏好域，测试结束时删除。
        let defaults: UserDefaults

        /// 偏好域的名称。
        let suite: String

        /// 关闭全部窗口并删除仓库与偏好域。
        @MainActor
        func close() {
            for window in coordinator.windows + [controller] {
                window.session.close()
                window.window?.close()
            }

            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }

    /// 建立有一个提交的临时仓库，用窗口打开它并读完第一次刷新。
    static func makeWindow() async throws -> WindowFixture {
        let directory = try FileViewsTests.temporaryDirectory()
        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        try Data("one\n".utf8).write(to: directory.appending(path: "a.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "first"])

        let suite = "spooky-navigation-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        let coordinator = SpookyApplicationController(bookmarks: RepositoryBookmarks(defaults: defaults))
        let controller = RepositoryWindowController(
            coordinator: coordinator,
            session: RepositorySession(makeRunner: { _ in runner })
        )

        controller.display(location)
        await controller.session.waitForRefresh()

        return WindowFixture(
            directory: directory,
            location: location,
            coordinator: coordinator,
            controller: controller,
            defaults: defaults,
            suite: suite
        )
    }

    /// 后退与前进按每个窗口自己的记录走，菜单与工具栏的可用性跟着记录变；从中间位置去别的视图后，前进的记录作废。
    @Test("仓库窗口的后退与前进")
    func windowBackForward() async throws {
        let fixture = try await Self.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let location = fixture.location
        let back = NSMenuItem(title: "", action: #selector(RepositoryWindowController.navigateBack), keyEquivalent: "")
        let forward = NSMenuItem(title: "", action: #selector(RepositoryWindowController.navigateForward), keyEquivalent: "")

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

        let commit = ViewReference.repository(location, .commit(head))
        controller.show(commit)
        #expect(session.history.showsCommitPage)
        #expect(controller.currentReference == commit)

        let blame = ViewReference.repository(location, .file(path: "a.txt", revision: head, mode: .blame))
        controller.show(blame)
        #expect(session.activeView == .fileContent)
        #expect(session.fileContent.mode == .blame)
        #expect(controller.currentReference == blame)

        // 中途经过的视图不进记录，后退一步就回到提交整页
        controller.navigateBack()
        #expect(controller.currentReference == commit)
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
        let fixture = try await Self.makeWindow()
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
