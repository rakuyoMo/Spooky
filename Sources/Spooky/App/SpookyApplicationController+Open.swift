import AppKit
import SpookyKit

// MARK: - Open Files

extension SpookyApplicationController {
    /// 从 Finder 打开或拖到 Dock 图标上的本机文件：主题文件与拖进 Themes 页的列表一样导入，其余按文件夹打开。
    ///
    /// - Parameter urls: 本机文件的 URL，按交来的顺序依次处理。
    func openFiles(_ urls: [URL]) {
        let themes = urls.filter { $0.pathExtension.lowercased() == TextTheme.fileExtension }
        let folders = urls.filter { $0.pathExtension.lowercased() != TextTheme.fileExtension }

        if !themes.isEmpty {
            // 同名时的询问显示在开着的设置窗口上，设置窗口没开时以模态窗口显示
            let window = settingsWindow?.window.flatMap { $0.isVisible ? $0 : nil }

            Task {
                await ThemeTransfer.importThemes(themes, into: ThemeStore.shared, window: window)
            }
        }

        if !folders.isEmpty {
            openFolders(folders)
        }
    }
}

// MARK: - Private

extension SpookyApplicationController {
    /// 依次打开文件夹：仓库在当前窗口打开；不是仓库的询问是否在这里新建，与拖进仓库管理时相同。
    ///
    /// - Parameter urls: 本机文件夹。
    private func openFolders(_ urls: [URL]) {
        let request = UUID()

        addingTasks[request] = Task { [weak self] in
            guard let self else {
                return
            }

            defer { self.addingTasks[request] = nil }

            for url in urls {
                do {
                    let repository = try await GitRunner(location: .local(path: url.path)).openLocalRepository()
                    try Task.checkCancellation()

                    openRepository(at: repository.location, from: activeWindow, inNewWindow: false)
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }

                    presentFolderFailure(error, at: url)
                }
            }
        }
    }

    /// 文件夹打不开时显示在当前窗口，没有窗口时新开一个：不是仓库的询问是否新建，建好后在这个窗口打开；其它错误显示错误 sheet。
    ///
    /// - Parameters:
    ///   - error: 检查文件夹时的错误。
    ///   - url: 打不开的文件夹。
    private func presentFolderFailure(_ error: any Error, at url: URL) {
        let source = activeWindow ?? makeWindow()

        guard (error as? GitError)?.category == .notRepository else {
            source.showWindow(nil)
            source.showFailure(AppFailure(error: error, opening: true, location: .local(path: url.path)))
            return
        }

        source.presentNoRepositoryFound(url) { [weak self, weak source] in
            guard let source else {
                return
            }

            self?.createRepository(at: url.path, from: source, into: nil, opening: true)
        }
    }
}
