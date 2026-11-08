import AppKit

// MARK: - Auto Fetch

extension RepositoryWindowController {
    /// 窗口挂上 sheet 时暂停自动获取，sheet 关闭后重新计时。
    func observeSheets() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sheetWillBegin),
            name: NSWindow.willBeginSheetNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sheetDidEnd),
            name: NSWindow.didEndSheetNotification,
            object: window
        )
    }

    /// sheet 挂上之前暂停自动获取。
    @objc
    private func sheetWillBegin(_: Notification) {
        autoFetch.pause()
    }

    /// sheet 关闭后，窗口仍显示仓库时自动获取重新计时。
    @objc
    private func sheetDidEnd(_: Notification) {
        guard !showsManager else {
            return
        }

        autoFetch.restart()
    }
}
