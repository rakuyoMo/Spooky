import AppKit
import SpookyKit
import SwiftUI

// MARK: - Working Copy Files

extension RepositoryWindowController {
    /// 树形显示，按仓库记住。
    @objc
    func viewAsTree() {
        setListMode(.tree)
    }

    /// 平铺显示，按仓库记住。
    @objc
    func viewAsList() {
        setListMode(.list)
    }

    /// 树形里显示或隐藏没有改动的文件，即在树形与全部文件之间切换。
    @objc
    func toggleNonModifiedItems() {
        setListMode(session.listMode == .allFiles ? .tree : .allFiles)
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

    /// 呈现文件操作的参数表单、保存面板或询问；表单提交后写操作开始才关闭。
    func presentFileRequest(_ request: WorkingCopyFileRequest) {
        guard session.canWrite, let window, window.attachedSheet == nil else { return }

        switch request {
        // 本机仓库的 Move… 用系统保存面板；服务器仓库没有本机文件夹可选，用表单
        case .form(.move(let entry)) where session.repository?.localURL != nil:
            presentMovePanel(entry, in: window)

        case .form(let form):
            presentDialog { close in
                WorkingCopyFileDialog(session: session, form: form, close: close)
            }

        case .untrackIgnored(let file, let patterns, let tracked):
            presentDialog { close in
                Self.untrackIgnoredPrompt(file, patterns: patterns, tracked: tracked, in: session, close: close)
            }
        }
    }

    /// 工作区文件显示选项的可用性，菜单项同时标出当前选中的选项；动作不属于本组时为 nil。
    func workingCopyFileAvailability(of item: any NSValidatedUserInterfaceItem) -> Bool? {
        let repositoryView = !showsManager && session.repository != nil
        let menuItem = item as? NSMenuItem

        switch item.action {
        // 当前的显示方式打勾并且不可用，只有另一种可选
        case #selector(viewAsTree):
            menuItem?.state = session.listMode.isTree ? .on : .off
            return repositoryView && !session.listMode.isTree

        case #selector(viewAsList):
            menuItem?.state = session.listMode == .list ? .on : .off
            return repositoryView && session.listMode != .list

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

// MARK: - Prompts

extension RepositoryWindowController {
    /// 要忽略的文件里有已跟踪的文件时询问：停止跟踪是主按钮，只写规则是备选按钮，或取消。
    ///
    /// - Parameters:
    ///   - file: 写入规则的忽略文件。
    ///   - patterns: 要写入的规则。
    ///   - tracked: 规则匹配到的已跟踪文件，选停止跟踪时一并停止跟踪。
    ///   - session: 选定后在它的仓库里写入；仓库已切换时不执行。
    ///   - close: 关闭询问。
    static func untrackIgnoredPrompt(
        _ file: IgnoreFile,
        patterns: [String],
        tracked: [StatusEntry],
        in session: RepositorySession,
        close: @escaping () -> Void
    ) -> ConfirmationDialog {
        let request = session.generation

        // 询问结束后才开始写入，仓库已切换时不执行
        let write: ([StatusEntry]) -> Void = { [weak session] untracking in
            guard let session, session.generation == request else { return }

            session.writePatterns(patterns, in: file, untracking: untracking)
        }

        return ConfirmationDialog(
            title: AppLocalization.text("files.untrackIgnored.title"),
            message: AppLocalization.text("files.untrackIgnored.message", session.scopeDescription(tracked)),
            submitTitle: AppLocalization.text("files.untrack"),
            alternate: (title: AppLocalization.text("files.untrackIgnored.skip"), action: { _ in write([]) }),
            helpArticle: .ignore,
            close: close
        ) { _ in
            write(tracked)
        }
    }
}

// MARK: - Move Destination

extension RepositoryWindowController {
    /// 保存面板选定的位置相对仓库根目录的路径；不在仓库里面，或就是仓库根目录本身时为 nil。
    ///
    /// - Parameters:
    ///   - url: 保存面板选定的位置，可能还不存在。
    ///   - root: 本机仓库的根目录。
    static func movePath(of url: URL, in root: URL) -> String? {
        // 目标可能还不存在，只解析它所在文件夹的符号链接，再与解析后的根目录比较
        let folder = url.deletingLastPathComponent().resolvingSymlinksInPath().path
        let base = root.resolvingSymlinksInPath().path

        guard folder == base || folder.hasPrefix(base + "/") else {
            return nil
        }

        let relativeFolder = folder.dropFirst(base.count).drop { $0 == "/" }

        return relativeFolder.isEmpty
            ? url.lastPathComponent
            : relativeFolder + "/" + url.lastPathComponent
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

    /// 记住当前仓库的显示模式，本窗口与显示同一仓库的其它窗口一起切换。
    private func setListMode(_ mode: WorkingCopyListMode) {
        guard let repository = session.repository else { return }

        WorkingCopyListMode.store(mode, for: repository)
        session.setListMode(mode)

        let others = NSApp.windows
            .compactMap { $0.windowController as? RepositoryWindowController }
            .filter { $0 !== self && $0.session.repository == repository }

        for controller in others {
            controller.session.setListMode(mode)
        }
    }

    /// 本机仓库的 Move…：系统保存面板预填名字（扩展名隐藏），定位到它所在的文件夹，只接受仓库里面的位置；选定后在仓库里移动。
    private func presentMovePanel(_ entry: StatusEntry, in window: NSWindow) {
        guard let root = session.repository?.localURL else { return }

        let source = root.appending(path: entry.path)
        let validator = MoveDestinationValidator(root: root)

        let panel = NSSavePanel()
        panel.nameFieldStringValue = source.lastPathComponent
        panel.directoryURL = source.deletingLastPathComponent()
        panel.isExtensionHidden = true
        panel.delegate = validator

        let request = session.generation

        panel.beginSheetModal(for: window) { [weak self] response in
            // 面板只弱引用代理，关闭前由这里持有
            withExtendedLifetime(validator) { }

            // 仓库已切换时不移动；选回原处时没有要做的
            guard
                response == .OK,
                let url = panel.url,
                let self,
                session.generation == request,
                let path = Self.movePath(of: url, in: root),
                let destination = WorkingCopyFileDialog.destination(path, from: entry.path)
            else { return }

            session.move(entry, to: destination)
        }
    }
}

// MARK: - MoveDestinationValidator

/// Move… 保存面板的代理：选到仓库外面时拒绝，面板保持打开并说明原因。
private final class MoveDestinationValidator: NSObject, NSOpenSavePanelDelegate {
    /// 本机仓库的根目录。
    let root: URL

    /// - Parameter root: 本机仓库的根目录。
    init(root: URL) {
        self.root = root
    }

    /// 位置不在仓库里面时抛出说明，面板把它显示出来。
    func panel(_: Any, validate url: URL) throws {
        guard RepositoryWindowController.movePath(of: url, in: root) == nil else {
            return
        }

        throw CocoaError(
            .fileWriteNoPermission,
            userInfo: [NSLocalizedDescriptionKey: AppLocalization.text("files.move.outside")]
        )
    }
}
