import AppKit
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - NavigationTests + RefreshFailure

extension NavigationTests {
    /// 打开着的仓库被移走后：窗口显示仓库列表时后台会话的刷新失败不弹框；显示仓库时换成丢失页、不弹框，
    /// 窗口再次成为 key 窗口也不再读取这个仓库。
    @Test("打开着的仓库被移走后换成丢失页")
    func movedRepository() async throws {
        let fixture = try await Self.makeCoordinator()
        defer { fixture.close() }

        // 丢失页的重试只在协调者管着的窗口里进行，测试的窗口因此由协调者建出
        let controller = fixture.coordinator.makeWindow()
        let moved = fixture.root.appending(path: "moved", directoryHint: .isDirectory)

        controller.display(fixture.location)
        await controller.session.waitForRefresh()

        // 显示仓库列表时，后台会话读不到仓库只记下失败
        controller.showRepositories()
        try FileManager.default.moveItem(at: fixture.directory, to: moved)

        controller.session.refresh(full: true)
        await controller.session.waitForRefresh()

        #expect(controller.session.failure != nil)
        #expect(controller.showsManager)
        #expect(controller.window?.attachedSheet == nil)

        // 显示仓库时读不到仓库：换成丢失页，会话随之关闭
        try FileManager.default.moveItem(at: moved, to: fixture.directory)
        controller.display(fixture.location)
        await controller.session.waitForRefresh()
        try FileManager.default.moveItem(at: fixture.directory, to: moved)

        controller.session.refresh(full: true)
        await controller.session.waitForRefresh()

        #expect(controller.window?.contentViewController is NSHostingController<MissingRepositoryView>)
        #expect(controller.missingLocation == fixture.location)
        #expect(controller.session.repository == nil)
        #expect(controller.window?.attachedSheet == nil)

        // 窗口再次成为 key 窗口时不再读取，也不弹框
        controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: controller.window))

        #expect(!controller.session.isRefreshing)
        #expect(controller.window?.attachedSheet == nil)

        // 等丢失页出现时排进主线程的那次重试结束，页面原样留着
        await Task.yield()
        await until { controller.openingRequest == nil }

        #expect(controller.window?.contentViewController is NSHostingController<MissingRepositoryView>)
    }
}
