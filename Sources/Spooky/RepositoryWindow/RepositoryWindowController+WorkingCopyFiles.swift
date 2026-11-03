import AppKit
import SpookyKit
import SwiftUI

// MARK: - Working Copy Files

extension RepositoryWindowController {
    /// 树形显示，所有仓库共用。
    @objc
    func viewAsTree() {
        Self.setListMode(.tree)
    }

    /// 平铺显示，所有仓库共用。
    @objc
    func viewAsList() {
        Self.setListMode(.list)
    }

    /// 树形里显示或隐藏没有改动的文件，即在树形与全部文件之间切换。
    @objc
    func toggleNonModifiedItems() {
        Self.setListMode(session.listMode == .allFiles ? .tree : .allFiles)
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
            presentDialog { close in
                WorkingCopyFileDialog(session: session, form: form, close: close)
            }

        case .untrackIgnored(let file, let patterns, let tracked):
            askUntrackIgnored(file, patterns: patterns, tracked: tracked)
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

    /// 记住所有仓库共用的显示模式，各仓库窗口的列表一起切换。
    private static func setListMode(_ mode: WorkingCopyListMode) {
        WorkingCopyListMode.store(mode)

        for controller in NSApp.windows.compactMap({ $0.windowController as? RepositoryWindowController }) {
            controller.session.setListMode(mode)
        }
    }

    /// 要忽略的文件里有已跟踪的文件：停止跟踪是主按钮，只写规则是备选按钮，或取消。
    private func askUntrackIgnored(_ file: IgnoreFile, patterns: [String], tracked: [StatusEntry]) {
        let request = session.generation

        // 询问结束后才开始写入，仓库已切换时不执行
        let write: ([StatusEntry]) -> Void = { [weak self] untracking in
            guard let self, session.generation == request else { return }

            session.writePatterns(patterns, in: file, untracking: untracking)
        }

        presentDialog { close in
            ConfirmationDialog(
                title: AppLocalization.text("files.untrackIgnored.title"),
                message: AppLocalization.text("files.untrackIgnored.message", session.scopeDescription(tracked)),
                submitTitle: AppLocalization.text("files.untrack"),
                alternate: (title: AppLocalization.text("files.untrackIgnored.skip"), action: { _ in write([]) }),
                close: close
            ) { _ in
                write(tracked)
            }
        }
    }
}
