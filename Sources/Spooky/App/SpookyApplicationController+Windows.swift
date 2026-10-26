import AppKit
import SpookyKit

// MARK: - Windows

extension SpookyApplicationController {
    /// 启动时是否显示启动窗口的偏好键；没有记录时不显示。
    static let showsLaunchWindowKey = "showLaunchWindow"

    /// 窗口恢复的状态只经安全编码读写。
    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }

    /// 启动后的第一个窗口：系统已恢复仓库窗口时不另开；否则按偏好显示启动窗口，或打开显示仓库管理的窗口。
    func openInitialWindow() {
        guard windows.isEmpty else {
            return
        }

        if UserDefaults.standard.bool(forKey: Self.showsLaunchWindowKey) {
            LaunchWindowController.show(coordinator: self)
        } else {
            newWindow()
        }
    }

    /// 按恢复状态重建一个仓库窗口；状态里读不出视图引用时显示仓库管理。
    ///
    /// 仓库经正常的打开流程重新打开，服务器仓库同样先连接并体检；打开失败时窗口留在仓库管理并显示错误。
    func restoreWindow(from state: NSCoder) -> NSWindow? {
        // 安全解码只能按 Objective-C 类取值，文字以 NSString 读出
        // swiftlint:disable:next legacy_objc_type
        let saved = state.decodeObject(of: NSString.self, forKey: RepositoryWindowController.viewReferenceKey)
        let reference = saved.flatMap { ViewReference(string: $0 as String) } ?? .repositories

        let controller = makeWindow()
        controller.show(reference)
        return controller.window
    }

    /// 在发起窗口所在标签组的末尾加一个显示仓库管理的标签；系统不支持窗口标签页时只发出提示音。
    func openTab(after source: RepositoryWindowController) {
        guard NSWindow.allowsAutomaticWindowTabbing, let window = source.window else {
            NSSound.beep()
            return
        }

        let controller = makeWindow()

        guard let tab = controller.window else {
            return
        }

        (window.tabGroup?.windows.last ?? window).addTabbedWindow(tab, ordered: .above)
        tab.makeKeyAndOrderFront(nil)
    }

    /// 在发起窗口所在标签组的末尾加一个标签，在里面打开仓库；系统不支持窗口标签页时改在新窗口里打开。
    func openRepositoryInNewTab(at location: RepositoryLocation, after source: RepositoryWindowController) {
        guard NSWindow.allowsAutomaticWindowTabbing, let window = source.window else {
            openRepository(at: location, from: source, inNewWindow: true)
            return
        }

        let controller = makeWindow()

        guard let tab = controller.window else {
            return
        }

        (window.tabGroup?.windows.last ?? window).addTabbedWindow(tab, ordered: .above)
        tab.makeKeyAndOrderFront(nil)
        openRepository(at: location, from: controller, inNewWindow: false, staysInSource: true)
    }

    /// 没有仓库窗口在前台时的 File › New Tab：打开一个新窗口。
    @objc
    func newWindowForTab(_: Any?) {
        newWindow()
    }

    /// 显式新窗口不并进已有的标签组：显示期间暂不参与自动标签，显示后恢复，之后仍可以手动合并。
    ///
    /// - Parameters:
    ///   - separate: 为 false 时照常显示，由系统偏好决定是否成为标签。
    ///   - show: 让窗口出现在屏幕上的动作。
    func showSeparately(_ controller: RepositoryWindowController, when separate: Bool = true, _ show: () -> Void) {
        guard separate, let window = controller.window else {
            show()
            return
        }

        window.tabbingMode = .disallowed
        show()
        window.tabbingMode = .automatic
    }
}
