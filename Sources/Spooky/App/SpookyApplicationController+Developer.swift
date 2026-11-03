import AppKit
import SwiftUI

// MARK: - Developer

extension SpookyApplicationController {
    /// Developer 菜单：偏好的打印、重置与清空，崩溃测试，自动归档，新功能卡片，以及自动刷新的开关。
    ///
    /// 菜单总在主菜单里，是否显示绑定到 General 页的 Show Developer menu，勾选变化时立即出现或消失。
    func configureDeveloperMenu(in menu: NSMenu) {
        let developer = addMenu("menu.developer", to: menu)

        // 没有勾选时偏好里没有这个键，取反后为隐藏
        menu.items.last?.bind(
            .hidden,
            to: NSUserDefaultsController.shared,
            withKeyPath: "values." + DeveloperPreferences.showsMenuKey,
            options: [.valueTransformerName: NSValueTransformerName.negateBooleanTransformerName]
        )

        let defaults = addMenu("developer.userDefaults", to: developer)
        addItem("developer.logUserDefaults", action: #selector(logUserDefaults), target: self, to: defaults)
        addItem("developer.resetUserDefaults", action: #selector(resetUserDefaults), target: self, to: defaults)
        addItem("developer.clearUserDefaults", action: #selector(clearUserDefaults), target: self, to: defaults)

        let crash = addMenu("developer.testCrashReporting", to: developer)
        addItem("developer.crashWithException", action: #selector(crashWithException), target: self, to: crash)
        addItem("developer.crashWithBadAccess", action: #selector(crashWithBadAccess), target: self, to: crash)

        // Run Auto-Archive 经响应链交给前台的仓库窗口
        let archive = addMenu("developer.autoArchive", to: developer)
        addItem("developer.runAutoArchive", action: #selector(RepositoryWindowController.runAutoArchive), to: archive)
        addItem(
            "developer.resetAutoArchiveDates",
            action: #selector(resetAutoArchiveDates),
            target: self,
            to: archive
        )

        addItem("developer.showWhatsNewCard", action: #selector(showWhatsNewCard), target: self, to: developer)

        developer.addItem(.separator())
        addItem("developer.autoReload", action: #selector(toggleAutoReload), target: self, to: developer)
    }

    /// Developer › User Defaults › Log User Defaults：把偏好域里的全部键值按键名排列，每项一行写到标准输出。
    @objc
    func logUserDefaults() {
        let values = UserDefaults.standard.persistentDomain(forName: UserDefaults.appDomain) ?? [:]

        let lines = values
            .sorted { $0.key < $1.key }
            .map { "\($0.key) = \($0.value)\n" }

        FileHandle.standardOutput.write(Data(lines.joined().utf8))
    }

    /// Developer › User Defaults › Reset User Defaults：先询问，确认后删掉偏好域里的设置，保留书签、身份档案与托管账号。
    @objc
    func resetUserDefaults() {
        Task {
            guard await Self.confirmResetUserDefaults(in: NSApp.keyWindow ?? NSApp.mainWindow) else {
                return
            }

            DeveloperPreferences.removeValues(in: UserDefaults.appDomain, of: .standard, keepingData: true)
        }
    }

    /// Developer › User Defaults › Clear User Defaults：不询问，直接删掉整个偏好域。
    @objc
    func clearUserDefaults() {
        DeveloperPreferences.removeValues(in: UserDefaults.appDomain, of: .standard, keepingData: false)
    }

    /// Developer › Test Crash Reporting › Crash With Fake Exception：抛出没有人接住的 Objective-C 异常。
    @objc
    func crashWithException() {
        // 菜单动作里抛出的异常会被 NSApplication 接住、App 继续运行；放进主队列的下一个块里抛出，App 才会终止
        DispatchQueue.main.async {
            NSException(name: .genericException, reason: "Crash With Fake Exception", userInfo: nil).raise()
        }
    }

    /// Developer › Test Crash Reporting › Crash With Bad Access：写入无效的内存地址。
    @objc
    func crashWithBadAccess() {
        UnsafeMutablePointer<Int>(bitPattern: 0x10)?.pointee = 0
    }

    /// Developer › Auto-Archive Branches › Reset Auto-Archive Dates：清掉各仓库上次检查自动归档的时刻，下次读完引用时重新检查。
    @objc
    func resetAutoArchiveDates() {
        UserDefaults.standard.removeObject(forKey: BranchArchiving.lastCheckKey)
    }

    /// Developer › Show What's New Card：在仓库窗口的侧边栏重新显示新功能卡片。
    @objc
    func showWhatsNewCard() {
        WhatsNewState.shared.showCardAgain()
    }

    /// Developer › Auto-Reload Repository：打开或关掉文件监听与轮询触发的刷新。
    @objc
    func toggleAutoReload() {
        UserDefaults.standard.set(!DeveloperPreferences.autoReloads(), forKey: DeveloperPreferences.autoReloadKey)
    }
}

// MARK: - Helpers

extension SpookyApplicationController {
    /// Reset User Defaults 的确认：骨架的确认版，Reset 是主按钮；有窗口时挂成 sheet，否则是应用级的模态对话框。
    ///
    /// - Parameter window: 挂 sheet 的窗口。
    /// - Returns: 用户选了 Reset。
    static func confirmResetUserDefaults(in window: NSWindow?) async -> Bool {
        await withCheckedContinuation { continuation in
            var answered = false

            let answer = { (confirmed: Bool) in
                guard !answered else { return }

                answered = true
                continuation.resume(returning: confirmed)
            }

            DialogWindow.present(on: window) { close in
                ConfirmationDialog(
                    title: AppLocalization.text("developer.resetUserDefaults.title"),
                    message: AppLocalization.text("developer.resetUserDefaults.message"),
                    submitTitle: AppLocalization.text("developer.resetUserDefaults.confirm"),
                    close: close,
                    cancel: { answer(false) }
                ) { _ in
                    answer(true)
                }
            }

            // 应用级的模态对话框关闭后才回到这里；用标题栏的关闭按钮关掉时没有选任何按钮，按取消处理
            if window == nil {
                answer(false)
            }
        }
    }
}
