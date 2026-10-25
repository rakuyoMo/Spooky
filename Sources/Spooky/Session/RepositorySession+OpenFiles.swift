import AppKit
import SpookyKit

// MARK: - Open Files

extension RepositorySession {
    /// 能交给本机程序的条目：工作区里存在的文件；目录不交给本机程序。
    func canOpen(_ entries: [StatusEntry]) -> Bool {
        repository != nil && entries.contains(where: \.isOpenable)
    }

    /// 所选文件在本机的路径：本机仓库是原文件，服务器文件先经 SFTP 取到会话缓存，远端路径不交给本机程序。
    ///
    /// 读取失败时报告错误，并返回已经取到的文件；仓库切换后返回空数组。
    func localFiles(_ entries: [StatusEntry]) async -> [URL] {
        guard let fileCache, let repository else { return [] }

        let request = generation
        var urls: [URL] = []

        for entry in entries where entry.isOpenable {
            do {
                urls.append(try await fileCache.workingTreeFile(entry.path))
            } catch {
                guard generation == request else { return [] }

                reportOpenFailure(error, in: repository)
                break
            }
        }

        return generation == request ? urls : []
    }

    /// 用默认程序或指定的程序打开所选文件。
    ///
    /// 本机仓库直接打开工作区文件；服务器文件交给编辑器：支持远程编辑的编辑器直接远程打开，
    /// 其余经 SFTP 取到临时副本，保存后核对服务器上的版本再写回。
    ///
    /// - Parameters:
    ///   - entries: 所选条目，目录与工作区里没有的文件跳过。
    ///   - application: 打开文件的程序；nil 表示各文件的默认程序。
    func open(_ entries: [StatusEntry], with application: URL? = nil) {
        guard let repository else { return }

        let paths = entries.filter(\.isOpenable).map(\.path)

        guard repository.host == nil else {
            for path in paths { edit(path, with: application) }
            return
        }

        let root = URL(fileURLWithPath: repository.path)

        Task { [weak self] in
            do {
                try await Self.open(paths.map { root.appending(path: $0) }, with: application)
            } catch {
                self?.reportOpenFailure(error, in: repository)
            }
        }
    }

    /// Open With ▸ Other…：在 “应用程序” 里选一个程序打开所选文件。
    func openWithOtherApplication(_ entries: [StatusEntry]) {
        Self.chooseApplication { [weak self] application in
            self?.open(entries, with: application)
        }
    }

    /// 打开某个版本里的文件：内容经 Git 取到会话缓存，再交给默认程序或指定的程序；副本在关闭仓库时删除。
    ///
    /// - Parameters:
    ///   - paths: 文件在仓库内的路径。
    ///   - revision: 提交的完整哈希。
    ///   - application: 打开文件的程序；nil 表示各文件的默认程序。
    func open(_ paths: [String], at revision: String, with application: URL? = nil) {
        guard let fileCache, let repository, !paths.isEmpty else { return }

        let request = generation

        Task { [weak self] in
            do {
                let files = ExternalToolFiles(cache: fileCache)
                var urls: [URL] = []

                for path in paths {
                    try await urls.append(files.file(path, at: .commit(revision)))
                }

                guard let self, generation == request else { return }

                try await Self.open(urls, with: application)
            } catch {
                guard let self, generation == request else { return }
                reportOpenFailure(error, in: repository)
            }
        }
    }

    /// 某个版本里的文件的 Open With ▸ Other…：在 “应用程序” 里选一个程序打开它们。
    func openWithOtherApplication(_ paths: [String], at revision: String) {
        Self.chooseApplication { [weak self] application in
            self?.open(paths, at: revision, with: application)
        }
    }

    /// 双击文件的动作：按偏好用默认程序打开，或用所选的比较工具对比 HEAD 版本与工作区文件。
    func performDoubleClickAction(_ entry: StatusEntry) {
        let action = UserDefaults.standard.string(forKey: WorkingCopyPreferences.doubleClickAction)
            .flatMap(WorkingCopyPreferences.DoubleClickAction.init(rawValue:)) ?? .openFile

        switch action {
        case .openFile:
            open([entry])

        case .openDiff:
            compare([entry], .workingTreeToBase)
        }
    }

    /// 打开文件或启动外部工具失败：断线交给重连，取消不报告，其余错误交给窗口呈现。
    func reportOpenFailure(_ error: Error, in repository: RepositoryLocation) {
        guard !(error is CancellationError), (error as? GitError)?.isCancelled != true else {
            return
        }

        if error is RemoteConnectionError {
            reconnect()
        } else {
            onFailure?(AppFailure(error: error, opening: false, location: repository))
        }
    }
}

// MARK: - Opening

extension RepositorySession {
    /// 用指定程序一起打开多个本机文件；没有指定程序时逐个交给各自的默认程序。
    static func open(_ urls: [URL], with application: URL?) async throws {
        guard let application else {
            for url in urls {
                _ = try await NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration())
            }

            return
        }

        guard !urls.isEmpty else { return }

        _ = try await NSWorkspace.shared.open(urls, withApplicationAt: application, configuration: .init())
    }

    /// 让用户从 “应用程序” 文件夹里选一个程序。
    ///
    /// - Parameter chosen: 选好程序后的动作；取消时不调用。
    static func chooseApplication(_ chosen: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = AppLocalization.text("action.open")
        panel.message = AppLocalization.text("files.openWith.choose")

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            chosen(url)
        }

        // 从本窗口发起的动作，面板附在本窗口上
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            panel.begin(completionHandler: finish)
        }
    }
}

// MARK: - StatusEntry

extension StatusEntry {
    /// 能交给本机程序打开的文件：工作区里存在且不是目录。
    var isOpenable: Bool {
        isDeletable && !path.hasSuffix("/")
    }
}
