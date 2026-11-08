import AppKit
import Foundation
import SpookyKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky

// MARK: - OpenFilesTests

/// 从 Finder 打开或拖到 Dock 图标上的文件：交来的仓库文件夹在窗口里打开，经链接或文件启动时只开出需要的窗口；
/// ⌘O 选好的文件夹与交来的文件夹走同一条路。
///
/// 不是仓库的文件夹弹出的是模态对话框，不在这里测：测试进程里结束模态循环会让测试进程直接退出，之后的测试都不再运行。
@MainActor
struct OpenFilesTests {
    /// ⌘O 选好的文件夹与 Finder 交来的走同一条路：不是工作区这类其余的失败显示错误 sheet，可以另选文件夹。
    @Test("⌘O 选了打不开的文件夹")
    func chosenFolderFailure() async throws {
        let fixture = try await NavigationTests.makeCoordinator()
        let bare = try FileViewsTests.temporaryDirectory()

        // 错误框会记下自己的尺寸，测完恢复
        let savedFrame = UserDefaults.standard.object(forKey: GitErrorDialogTests.frameKey)

        defer {
            for window in fixture.coordinator.windows.compactMap(\.window) {
                if let sheet = window.attachedSheet {
                    window.endSheet(sheet)
                }
            }

            UserDefaults.standard.set(savedFrame, forKey: GitErrorDialogTests.frameKey)
            try? FileManager.default.removeItem(at: bare)
            fixture.close()
        }

        let coordinator = fixture.coordinator

        _ = try await GitRunner(location: .local(path: bare.path)).run(
            ["-c", "init.templateDir=", "init", "--bare", "-q"]
        )

        await coordinator.openFolders([bare]).value

        // 检查失败后在开出的窗口上挂错误框
        let window = try #require(coordinator.windows.first?.window)
        let sheet = try await PromptDialogTests.attachedSheet(of: window)
        let dialog = try #require(sheet.contentViewController as? NSHostingController<GitErrorDialog>)

        #expect(dialog.rootView.chooseAnother != nil)
    }

    /// 经链接启动时，链接的仓库经正常的打开流程显示在唯一的窗口里，停在链接指向的视图，不另开仓库管理窗口。
    @Test("经链接启动只开一个窗口，显示链接指向的视图")
    func launchWithLink() async throws {
        let fixture = try await NavigationTests.makeCoordinator()
        defer { fixture.close() }

        let coordinator = fixture.coordinator
        let path = try #require(fixture.directory.path.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
        let url = try #require(URL(string: "spooky://open?repository=" + path + "&view=stashes"))

        // 启动中交来的链接先存下，启动收尾时才处理
        Self.beginLaunching(coordinator)
        coordinator.application(NSApplication.shared, open: [url])
        #expect(coordinator.windows.isEmpty)

        // 链接不带文件，启动收尾同步开出打开链接的窗口；窗口交还打开请求时仓库已经显示
        coordinator.finishLaunchOpenings()
        await until { coordinator.windows.allSatisfy { $0.openingRequest == nil } }

        #expect(coordinator.windows.count == 1)

        let window = try #require(coordinator.windows.first)
        #expect(!window.showsManager)
        #expect(window.session.activeView == .stashes)
    }

    /// 经仓库里的子文件夹启动时，打开的是它所在的仓库，显示在唯一的窗口里，不另开仓库管理窗口。
    @Test("经仓库文件夹启动只开一个窗口，打开文件夹所在的仓库")
    func launchWithRepositoryFolder() async throws {
        let fixture = try await NavigationTests.makeCoordinator()
        defer { fixture.close() }

        let coordinator = fixture.coordinator
        let folder = fixture.directory.appending(path: "子目录", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)

        Self.beginLaunching(coordinator)
        coordinator.application(NSApplication.shared, open: [folder])
        coordinator.finishLaunchOpenings()

        // 打开文件夹的任务结束时仓库已经显示；启动收尾等着它，随后排进主线程，让出一次后也已结束
        await untilFinished { Array(coordinator.addingTasks.values) }
        await Task.yield()

        #expect(coordinator.windows.count == 1)

        let window = try #require(coordinator.windows.first)
        #expect(!window.showsManager)
        #expect(window.session.repository?.name == fixture.location.name)
    }

    /// 经克隆链接启动时，克隆对话框显示在唯一的窗口上，不另开仓库管理窗口。
    @Test("经克隆链接启动只开一个窗口")
    func launchWithCloneLink() async throws {
        let fixture = try await NavigationTests.makeCoordinator()

        defer {
            for window in fixture.coordinator.windows.compactMap(\.window) {
                if let sheet = window.attachedSheet {
                    window.endSheet(sheet)
                }
            }

            fixture.close()
        }

        let coordinator = fixture.coordinator
        let url = try #require(URL(string: "spooky://clone?url=https://github.com/rakuyoMo/Spooky"))

        Self.beginLaunching(coordinator)
        coordinator.application(NSApplication.shared, open: [url])

        // 链接不带文件，启动收尾同步开出挂克隆对话框的窗口
        coordinator.finishLaunchOpenings()
        #expect(coordinator.windows.count == 1)

        let window = try #require(coordinator.windows.first?.window)
        _ = try await PromptDialogTests.attachedSheet(of: window)
    }
}

// MARK: - Helpers

extension OpenFilesTests {
    /// 让协调者进入启动中：之后交来的链接与文件先存下，由 `finishLaunchOpenings()` 处理。
    private static func beginLaunching(_ coordinator: SpookyApplicationController) {
        coordinator.applicationWillFinishLaunching(Notification(name: NSApplication.willFinishLaunchingNotification))
    }
}
