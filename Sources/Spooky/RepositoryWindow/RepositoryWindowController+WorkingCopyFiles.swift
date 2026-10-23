import AppKit
import SpookyKit
import SwiftUI

// MARK: - Working Copy Files

extension RepositoryWindowController {
    /// 树形显示，记在当前仓库上。
    @objc
    func viewAsTree() {
        session.setListMode(.tree)
    }

    /// 平铺显示，记在当前仓库上。
    @objc
    func viewAsList() {
        session.setListMode(.list)
    }

    /// 树形里显示或隐藏没有改动的文件，即在树形与全部文件之间切换。
    @objc
    func toggleNonModifiedItems() {
        session.setListMode(session.listMode == .allFiles ? .tree : .allFiles)
    }

    /// 显示或隐藏被忽略的文件，全局偏好。
    @objc
    func toggleIgnoredItems() {
        Self.toggleWorkingCopyPreference(WorkingCopyPreferences.showIgnored)
    }

    /// 显示或隐藏 assume-unchanged 文件，全局偏好。
    @objc
    func toggleAssumeUnchangedItems() {
        Self.toggleWorkingCopyPreference(WorkingCopyPreferences.showAssumeUnchanged)
    }

    /// 选择本机的补丁文件并应用到工作区。
    @objc
    func applyPatch() {
        presentFileRequest(.form(.applyPatch))
    }

    /// 呈现文件操作的参数表单或询问；表单提交后写操作开始才关闭。
    func presentFileRequest(_ request: WorkingCopyFileRequest) {
        guard session.canWrite, let window, window.attachedSheet == nil else { return }

        switch request {
        case .form(let form):
            let sheet = NSWindow()
            sheet.styleMask = [.titled]
            sheet.tabbingMode = .disallowed
            sheet.contentViewController = NSHostingController(
                rootView: WorkingCopyFileDialog(session: session, form: form) { [weak sheet] in
                    if let sheet { window.endSheet(sheet) }
                }
            )
            window.beginSheet(sheet)

        case .untrackIgnored(let file, let patterns, let tracked):
            askUntrackIgnored(file, patterns: patterns, tracked: tracked, in: window)
        }
    }

    /// 工作区文件显示选项的可用性，菜单项同时标出当前选中的选项；动作不属于本组时为 nil。
    func workingCopyFileAvailability(of item: any NSValidatedUserInterfaceItem) -> Bool? {
        let repositoryView = !showsManager && session.repository != nil
        let menuItem = item as? NSMenuItem

        switch item.action {
        case #selector(viewAsTree):
            menuItem?.state = session.listMode.isTree ? .on : .off
            return repositoryView

        case #selector(viewAsList):
            menuItem?.state = session.listMode == .list ? .on : .off
            return repositoryView

        case #selector(toggleNonModifiedItems):
            menuItem?.state = session.listMode == .allFiles ? .on : .off
            return repositoryView && session.listMode.isTree

        case #selector(toggleIgnoredItems):
            menuItem?.state = UserDefaults.standard.bool(forKey: WorkingCopyPreferences.showIgnored) ? .on : .off
            return repositoryView

        case #selector(toggleAssumeUnchangedItems):
            let shows = UserDefaults.standard.bool(forKey: WorkingCopyPreferences.showAssumeUnchanged)
            menuItem?.state = shows ? .on : .off
            return repositoryView

        case #selector(applyPatch):
            return repositoryView && session.canWrite

        default:
            return nil
        }
    }

}

// MARK: - Private

extension RepositoryWindowController {
    /// 切换全局显示偏好，所有仓库窗口按新偏好重新读取补充清单。
    private static func toggleWorkingCopyPreference(_ key: String) {
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)

        for controller in NSApp.windows.compactMap({ $0.windowController as? RepositoryWindowController }) {
            controller.session.loadWorkingTreeFiles()
        }
    }

    /// 要忽略的文件里有已跟踪的文件：停止跟踪、只写规则，或取消。
    private func askUntrackIgnored(
        _ file: IgnoreFile,
        patterns: [String],
        tracked: [StatusEntry],
        in window: NSWindow
    ) {
        let request = session.generation
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppLocalization.text("files.untrackIgnored.title")
        alert.informativeText = AppLocalization.text("files.untrackIgnored.message", session.scopeDescription(tracked))
        alert.addButton(withTitle: AppLocalization.text("files.untrack"))
        alert.addButton(withTitle: AppLocalization.text("files.untrackIgnored.skip"))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))

        // 询问结束后才开始写入，仓库已切换时不执行
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, session.generation == request else { return }

            switch response {
            case .alertFirstButtonReturn:
                session.writePatterns(patterns, in: file, untracking: tracked)

            case .alertSecondButtonReturn:
                session.writePatterns(patterns, in: file, untracking: [])

            default:
                break
            }
        }
    }
}
