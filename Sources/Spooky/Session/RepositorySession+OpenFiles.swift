import AppKit
import SpookyKit

// MARK: - DiffToolLaunchError

/// 比较工具不存在或启动失败，保留工具的原始输出。
struct DiffToolLaunchError: Error {
    /// 工具的标准输出与标准错误，或启动失败的系统说明。
    let diagnostic: String
}

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

    /// 用默认程序打开所选文件。
    func open(_ entries: [StatusEntry]) {
        guard let repository else { return }

        Task { [weak self] in
            guard let self else { return }

            for url in await localFiles(entries) {
                do {
                    _ = try await NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration())
                } catch {
                    reportOpenFailure(error, in: repository)
                    return
                }
            }
        }
    }

    /// 双击文件的动作：按偏好用默认程序打开，或用比较工具对比 HEAD 版本与工作区文件。
    func performDoubleClickAction(_ entry: StatusEntry) {
        let action = UserDefaults.standard.string(forKey: WorkingCopyPreferences.doubleClickAction)
            .flatMap(WorkingCopyPreferences.DoubleClickAction.init(rawValue:)) ?? .openFile

        switch action {
        case .openFile:
            open([entry])

        case .openDiff:
            openDiffTool(entry)
        }
    }

    /// 用比较工具对比 HEAD 版本与工作区文件：HEAD 版本写成缓存副本，服务器上的工作区文件同样取到缓存。
    func openDiffTool(_ entry: StatusEntry) {
        guard let runner, let fileCache, let repository, !entry.path.hasSuffix("/") else { return }

        Task { [weak self] in
            do {
                // 重命名的文件在 HEAD 里是原路径；HEAD 里没有的文件与已删除的文件以空内容比较
                let base = try await Self.headContent(of: entry.originalPath ?? entry.path, runner: runner)
                let left = try fileCache.store(base, named: entry.path)
                let right = entry.isOpenable
                    ? try await fileCache.workingTreeFile(entry.path)
                    : try fileCache.store(Data(), named: entry.path)

                try await Self.launchDiffTool(left, right)
            } catch {
                self?.reportOpenFailure(error, in: repository)
            }
        }
    }

}

// MARK: - Private

extension RepositorySession {
    /// 文件在 HEAD 里的内容；HEAD 里没有这个文件或仓库还没有提交时为空。
    private static func headContent(of path: String, runner: GitRunner) async throws -> Data {
        let result = try await runner.execute(["cat-file", "blob", "HEAD:" + path], acceptedExitCodes: [0, 128])
        return result.exitCode == 0 ? result.standardOutput : Data()
    }

    /// 在后台启动 FileMerge 的命令行入口并等待它结束；启动失败或非零退出时带回原始输出。
    private static func launchDiffTool(_ left: URL, _ right: URL) async throws {
        #warning("TODO: 比较工具固定为 /usr/bin/opendiff（FileMerge，随 Xcode 安装），核实没有安装 Xcode 时的提示是否足够；只影响双击偏好为 Open Diff tool 时的比较")
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/opendiff")
            process.arguments = [left.path, right.path]
            process.standardInput = FileHandle.nullDevice

            let output = Pipe()
            process.standardOutput = output
            process.standardError = output

            do {
                try process.run()
            } catch {
                throw DiffToolLaunchError(diagnostic: error.localizedDescription)
            }

            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw DiffToolLaunchError(diagnostic: String(decoding: data, as: UTF8.self))
            }
        }.value
    }

    /// 打开文件失败：断线交给重连，其余错误交给窗口呈现。
    private func reportOpenFailure(_ error: Error, in repository: RepositoryLocation) {
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

// MARK: - StatusEntry

extension StatusEntry {
    /// 能交给本机程序打开的文件：工作区里存在且不是目录。
    var isOpenable: Bool {
        isDeletable && !path.hasSuffix("/")
    }
}
