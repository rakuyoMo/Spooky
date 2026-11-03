import AppKit
import SpookyKit
import SwiftUI

// MARK: - Open Files

extension SpookyApplicationController {
    /// 从 Finder 打开或拖到 Dock 图标上的本机文件：主题文件与拖进 Themes 页的列表一样导入，其余按文件夹打开。
    ///
    /// - Parameter urls: 本机文件的 URL，按交来的顺序依次处理。
    /// - Returns: 导入与打开的任务；结束时询问已经回答，打开的仓库已经显示。
    @discardableResult
    func openFiles(_ urls: [URL]) -> [Task<Void, Never>] {
        let themes = urls.filter { $0.pathExtension.lowercased() == TextTheme.fileExtension }
        let folders = urls.filter { $0.pathExtension.lowercased() != TextTheme.fileExtension }
        var tasks: [Task<Void, Never>] = []

        if !themes.isEmpty {
            // 同名时的询问显示在开着的设置窗口上，设置窗口没开时以模态窗口显示
            let window = settingsWindow?.window.flatMap { $0.isVisible ? $0 : nil }

            tasks.append(Task {
                await ThemeTransfer.importThemes(themes, into: ThemeStore.shared, window: window)
            })
        }

        if !folders.isEmpty {
            tasks.append(openFolders(folders))
        }

        return tasks
    }

    /// 依次打开文件夹：仓库在当前窗口打开，没有窗口时新开一个；不是仓库的询问是否在这里新建。
    ///
    /// 从 Finder 或 Dock 交来的文件夹与 ⌘O 选好的文件夹都走这里。
    ///
    /// - Parameter urls: 本机文件夹。
    /// - Returns: 检查与打开的任务，退出时与仓库管理的拖入检查一起取消、等待。
    @discardableResult
    func openFolders(_ urls: [URL]) -> Task<Void, Never> {
        let request = UUID()

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            defer { self.addingTasks[request] = nil }

            for url in urls {
                do {
                    let repository = try await GitRunner(location: .local(path: url.path)).openLocalRepository()
                    try Task.checkCancellation()

                    await openRepository(at: repository.location, from: activeWindow, inNewWindow: false)?.value
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }

                    presentFolderFailure(error, at: url)
                }
            }
        }

        addingTasks[request] = task
        return task
    }
}

// MARK: - Private

extension SpookyApplicationController {
    /// 文件夹打不开时：不是仓库的询问是否新建，建好后在当前窗口打开；其它错误以 sheet 显示在当前窗口。没有窗口时新开一个。
    ///
    /// - Parameters:
    ///   - error: 检查文件夹时的错误。
    ///   - url: 打不开的文件夹。
    private func presentFolderFailure(_ error: any Error, at url: URL) {
        guard (error as? GitError)?.category == .notRepository else {
            let source = activeWindow ?? makeWindow()
            source.showWindow(nil)
            source.showFailure(AppFailure(error: error, opening: true, location: .local(path: url.path)))
            return
        }

        // 询问期间不会换窗口，先记下当前窗口
        let current = activeWindow

        guard confirmCreatingRepository(in: url) else {
            return
        }

        let source = current ?? makeWindow()
        source.showWindow(nil)
        createRepository(at: url.path, from: source, into: nil, opening: true)
    }

    /// 询问是否在不是仓库的文件夹里新建仓库：单独的模态对话框，不挂在窗口上；标题栏的关闭按钮与 Cancel 相同。
    ///
    /// - Parameter directory: 交来的文件夹。
    /// - Returns: 是否选择新建。
    private func confirmCreatingRepository(in directory: URL) -> Bool {
        var creates = false

        let controller = NSHostingController(
            rootView: NoRepositoryFoundDialog(
                directory: directory,
                close: { NSApp.stopModal() },
                create: { creates = true }
            )
        )
        controller.sizingOptions = .preferredContentSize

        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable]
        window.title = ""
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.center()

        // 点标题栏的关闭按钮时窗口自己关掉，模态循环要另外结束
        let closing = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { NSApp.stopModal() }
        }

        _ = NSApp.runModal(for: window)
        NotificationCenter.default.removeObserver(closing)
        window.orderOut(nil)

        return creates
    }
}
