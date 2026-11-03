import AppKit
import Foundation
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - DeveloperMenuTests

/// Developer 菜单：General 页的勾选决定它是否出现在主菜单；Reset 先询问、只删设置并保留用户的数据，Clear 什么都不留；
/// 关掉 Auto-Reload Repository 后文件监听与轮询不再刷新仓库。
@MainActor
struct DeveloperMenuTests {
    /// 菜单排在 Window 与 Help 之间；没有勾选时隐藏，勾上立即出现，取消立即消失。
    @Test("勾选框决定 Developer 菜单是否显示")
    func menuVisibility() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-developer-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        // 勾选框写的是标准偏好，测完恢复原值
        let key = DeveloperPreferences.showsMenuKey
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let controller = SpookyApplicationController(bookmarks: RepositoryBookmarks(defaults: defaults))
        _ = NSApplication.shared
        controller.configureMenu()

        let items = NSApp.mainMenu?.items ?? []
        let index = try #require(items.firstIndex { $0.title == AppLocalization.text("menu.developer") })
        #expect(items[index - 1].title == AppLocalization.text("menu.window"))
        #expect(items[index + 1].title == AppLocalization.text("menu.help"))
        #expect(items[index].isHidden)

        UserDefaults.standard.set(true, forKey: key)
        #expect(!items[index].isHidden)

        UserDefaults.standard.set(false, forKey: key)
        #expect(items[index].isHidden)
    }

    /// Reset 之后只剩书签、身份档案、托管账号、账号关联与服务器仓库的本机目录，设置都回到默认；Clear 之后整个域都空了。
    @Test("Reset 保留数据，Clear 全部删掉")
    func resetAndClear() throws {
        let domain = "com.rakuyo.spooky.tests.developer." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }

        for key in DeveloperPreferences.dataKeys {
            defaults.set(Data("[]".utf8), forKey: key)
        }

        defaults.set(true, forKey: DeveloperPreferences.showsMenuKey)
        defaults.set(AppAppearance.dark.rawValue, forKey: AppAppearance.key)
        defaults.set(["/tmp/仓 库": 1.0], forKey: BranchArchiving.lastCheckKey)

        DeveloperPreferences.removeValues(in: domain, of: defaults, keepingData: true)

        let kept = defaults.persistentDomain(forName: domain) ?? [:]
        #expect(Set(kept.keys) == Set(DeveloperPreferences.dataKeys))
        #expect(defaults.object(forKey: AppAppearance.key) == nil)
        #expect(defaults.object(forKey: BranchArchiving.lastCheckKey) == nil)
        #expect(!defaults.bool(forKey: DeveloperPreferences.showsMenuKey))

        DeveloperPreferences.removeValues(in: domain, of: defaults, keepingData: false)

        #expect(defaults.persistentDomain(forName: domain)?.isEmpty ?? true)
        #expect(DeveloperPreferences.dataKeys.allSatisfy { defaults.object(forKey: $0) == nil })
    }

    /// Reset User Defaults 先以确认对话框询问：说明保留哪些数据，Reset 是主按钮；选 Cancel 不执行，选 Reset 才执行。
    @Test("Reset 先询问，Cancel 时不执行")
    func resetConfirmation() async throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        defer { window.close() }

        for confirms in [false, true] {
            let answer = Task { await SpookyApplicationController.confirmResetUserDefaults(in: window) }
            let sheet = try await Self.attachedSheet(of: window)
            let dialog = try #require((sheet.contentViewController as? NSHostingController<ConfirmationDialog>)?.rootView)

            // 标题与说明来自资源，Reset 是主按钮
            #expect(dialog.title == AppLocalization.text("developer.resetUserDefaults.title"))
            #expect(dialog.message == AppLocalization.text("developer.resetUserDefaults.message"))
            #expect(dialog.submitTitle == AppLocalization.text("developer.resetUserDefaults.confirm"))
            #expect(dialog.cancelTitle == AppLocalization.text("action.cancel"))

            // 照这一轮的选择走对话框的取消或主按钮：Cancel 不执行，Reset 才执行
            dialog.close()

            if confirms {
                dialog.submit(false)
            } else {
                dialog.cancel()
            }

            #expect(await answer.value == confirms)
        }
    }

    /// 关掉 Auto-Reload Repository 后，文件监听与轮询共用的刷新入口不读取状态；没有记录或打开时照常刷新。
    @Test("关掉自动刷新后文件监听与轮询不刷新")
    func autoReload() async throws {
        let domain = "com.rakuyo.spooky.tests.autoreload." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }

        let status = try WorkingCopyStatus(porcelainV2: Data("# branch.oid (initial)\0# branch.head main\0".utf8))
        let session = RepositorySession(loadStatus: { _ in status })
        defer { session.close() }
        session.display(.local(path: "/temporary/auto-reload-" + UUID().uuidString))

        #expect(DeveloperPreferences.autoReloads(in: defaults))

        defaults.set(false, forKey: DeveloperPreferences.autoReloadKey)
        session.autoReload(defaults: defaults)
        #expect(!session.isRefreshing)
        #expect(session.refreshTask == nil)
        #expect(session.status == nil)

        defaults.set(true, forKey: DeveloperPreferences.autoReloadKey)
        session.autoReload(defaults: defaults)
        #expect(session.isRefreshing)

        await session.refreshTask?.value
        #expect(session.status == status)
    }
}

// MARK: - Helpers

extension DeveloperMenuTests {
    /// 等窗口挂上 sheet，最多等 5 秒。
    private static func attachedSheet(of window: NSWindow) async throws -> NSWindow {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))

        while window.attachedSheet == nil, .now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        return try #require(window.attachedSheet)
    }
}
