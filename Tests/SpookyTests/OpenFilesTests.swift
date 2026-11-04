import AppKit
import Foundation
import SpookyKit
import SwiftUI
import Testing

@testable import Spooky

// MARK: - OpenFilesTests

/// 从 Finder 打开或拖到 Dock 图标上的文件：Info.plist 的文稿类型决定系统交不交给 App，交来的仓库文件夹在窗口里打开，
/// 经链接或文件启动时只开出需要的窗口；⌘O 选好的文件夹与交来的文件夹走同一条路。
///
/// 不是仓库的文件夹弹出的是模态对话框，不在这里测：测试进程里结束模态循环会让测试进程直接退出，之后的测试都不再运行。
@MainActor
struct OpenFilesTests {
    /// 主题文件归 App 所有、双击即打开；文件夹只接收拖放，不抢 Finder 的默认打开方式；扩展名与主题文件一致。
    @Test("Info.plist 声明主题与文件夹的文稿类型")
    func documentTypes() throws {
        let plist = try LocalizationTests.infoPlist()
        let documentTypes = try #require(plist["CFBundleDocumentTypes"] as? [[String: Any]])
        let exportedTypes = try #require(plist["UTExportedTypeDeclarations"] as? [[String: Any]])

        let theme = try #require(documentTypes.first { $0["CFBundleTypeName"] as? String == "Spooky Theme" })
        #expect(theme["CFBundleTypeRole"] as? String == "Editor")
        #expect(theme["LSHandlerRank"] as? String == "Owner")
        #expect(theme["LSItemContentTypes"] as? [String] == ["com.rakuyo.spooky.theme"])

        let folder = try #require(documentTypes.first { $0["CFBundleTypeName"] as? String == "Folder" })
        #expect(folder["CFBundleTypeRole"] as? String == "Viewer")
        #expect(folder["LSHandlerRank"] as? String == "None")
        #expect(folder["LSItemContentTypes"] as? [String] == ["public.folder"])

        let exported = try #require(
            exportedTypes.first { $0["UTTypeIdentifier"] as? String == "com.rakuyo.spooky.theme" }
        )
        let tags = try #require(exported["UTTypeTagSpecification"] as? [String: [String]])
        #expect(exported["UTTypeConformsTo"] as? [String] == ["public.json"])
        #expect(tags["public.filename-extension"] == [TextTheme.fileExtension])
    }

    /// 交来仓库里的子文件夹时，打开的是它所在的仓库。
    @Test("打开仓库文件夹")
    func openRepositoryFolder() async throws {
        let fixture = try await NavigationTests.makeCoordinator()
        defer { fixture.close() }

        let coordinator = fixture.coordinator
        let folder = fixture.directory.appending(path: "子目录", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)

        coordinator.application(NSApplication.shared, open: [folder])

        try await FileViewsTests.wait {
            coordinator.windows.contains {
                !$0.showsManager && $0.session.repository?.name == fixture.location.name
            }
        }
    }

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

        try await FileViewsTests.wait {
            coordinator.windows.contains { $0.window?.attachedSheet != nil }
        }

        let sheets = coordinator.windows.compactMap { $0.window?.attachedSheet }
        let sheet = try #require(sheets.first)
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

        coordinator.finishLaunchOpenings()

        // 打开流程结束后，窗口停在链接指向的视图
        try await FileViewsTests.wait {
            coordinator.windows.contains { $0.session.activeView == .stashes && !$0.showsManager }
        }

        try await Self.waitForSingleRepositoryWindow(coordinator)
    }

    /// 经仓库文件夹启动时，仓库显示在唯一的窗口里，不另开仓库管理窗口。
    @Test("经仓库文件夹启动只开一个窗口")
    func launchWithRepositoryFolder() async throws {
        let fixture = try await NavigationTests.makeCoordinator()
        defer { fixture.close() }

        let coordinator = fixture.coordinator

        Self.beginLaunching(coordinator)
        coordinator.application(NSApplication.shared, open: [fixture.directory])
        coordinator.finishLaunchOpenings()

        try await Self.waitForSingleRepositoryWindow(coordinator)
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
        coordinator.finishLaunchOpenings()

        try await Task.sleep(for: .milliseconds(300))
        #expect(coordinator.windows.count == 1)
        #expect(coordinator.windows.first?.window?.attachedSheet != nil)
    }
}

// MARK: - Helpers

extension OpenFilesTests {
    /// 让协调者进入启动中：之后交来的链接与文件先存下，由 `finishLaunchOpenings()` 处理。
    private static func beginLaunching(_ coordinator: SpookyApplicationController) {
        coordinator.applicationWillFinishLaunching(Notification(name: NSApplication.willFinishLaunchingNotification))
    }

    /// 等到窗口显示出仓库，再稍等启动收尾的处理结束，核对只有这一个窗口。
    private static func waitForSingleRepositoryWindow(_ coordinator: SpookyApplicationController) async throws {
        try await FileViewsTests.wait {
            coordinator.windows.contains { !$0.showsManager }
        }

        try await Task.sleep(for: .milliseconds(300))
        #expect(coordinator.windows.count == 1)
    }
}
