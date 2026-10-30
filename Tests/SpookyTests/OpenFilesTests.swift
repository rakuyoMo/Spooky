import AppKit
import Foundation
import SpookyKit
import SwiftUI
import Testing

@testable import Spooky

// MARK: - OpenFilesTests

/// 从 Finder 打开或拖到 Dock 图标上的文件：Info.plist 的文稿类型决定系统交不交给 App，交来的文件夹按仓库与否分别处理。
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
        let fixture = try await NavigationTests.makeWindow()
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

    /// 不是仓库的文件夹不报错，而是与拖进仓库管理时一样询问是否在这里新建仓库。
    @Test("打开不是仓库的文件夹时询问是否新建")
    func openPlainFolder() async throws {
        let fixture = try await NavigationTests.makeWindow()
        let folder = try FileViewsTests.temporaryDirectory()

        defer {
            for window in fixture.coordinator.windows.compactMap(\.window) {
                if let sheet = window.attachedSheet {
                    window.endSheet(sheet)
                }
            }

            fixture.close()
            try? FileManager.default.removeItem(at: folder)
        }

        let coordinator = fixture.coordinator
        coordinator.application(NSApplication.shared, open: [folder])

        try await FileViewsTests.wait {
            coordinator.windows.contains { $0.window?.attachedSheet != nil }
        }

        // 弹出的是新建仓库的询问，不是错误 sheet；窗口仍显示仓库管理
        let sheet = coordinator.windows.compactMap { $0.window?.attachedSheet }.first
        #expect(sheet?.contentViewController is NSHostingController<NoRepositoryFoundDialog>)
        #expect(!coordinator.windows.contains { !$0.showsManager })
    }
}
