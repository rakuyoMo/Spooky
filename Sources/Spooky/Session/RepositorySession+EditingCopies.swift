import AppKit
import SpookyKit

// MARK: - Editing Copies

extension RepositorySession {
    /// 用编辑器打开仓库所在机器上的一个文件；工作区文件的 Open、Open With 与仓库设置里的 “Open in Editor” 共用。
    ///
    /// - 本机仓库：直接打开原文件。
    /// - 服务器仓库：编辑器支持远程编辑时按主机别名远程打开；其余经 SFTP 取到临时副本，
    ///   编辑器保存后核对服务器上的版本再写回，版本不一致时询问是否覆盖。副本在关闭仓库时删除。
    ///
    /// - Parameters:
    ///   - path: 相对工作区根目录的路径，或仓库所在机器上的绝对路径。
    ///   - application: 编辑器；nil 表示文件的默认程序。
    func edit(_ path: String, with application: URL? = nil) {
        guard let repository, let fileCache else {
            return
        }

        let absolute = path.hasPrefix("/") ? path : repository.path + "/" + path
        let request = generation

        Task { [weak self] in
            do {
                guard let host = repository.host else {
                    try await Self.open([URL(fileURLWithPath: absolute)], with: application)
                    return
                }

                // 支持远程编辑的编辑器直接打开服务器上的文件；没有指定程序时按默认程序判断
                let editor = application ?? OpenWithApplications.load(forNames: [absolute]).defaultApplication

                if
                    let editor,
                    let url = RemoteEditor.url(
                        host: host,
                        path: absolute,
                        bundleIdentifier: Bundle(url: editor)?.bundleIdentifier
                    )
                {
                    _ = try await NSWorkspace.shared.open([url], withApplicationAt: editor, configuration: .init())
                    return
                }

                let copy = try await fileCache.editingCopy(of: absolute)

                guard let self, generation == request else { return }

                try await Self.open([copy.file], with: application)
                watch(copy, request: request)
            } catch {
                guard let self, generation == request else { return }
                reportOpenFailure(error, in: repository)
            }
        }
    }

    /// 用编辑器打开仓库设置里的规则文件；文件还不存在时先建一个空文件。
    func edit(_ file: RuleFile) {
        guard !file.exists else {
            edit(file.path)
            return
        }

        let path = file.path

        performGit(
            { runner, _ in try await RepositoryFiles(runner: runner).write(Data(), to: path) },
            title: AppLocalization.text("repositorySettings.openInEditor"),
            recordsActivity: false,
            success: { [weak self] in self?.edit(path) }
        )
    }
}

// MARK: - Private

extension RepositorySession {
    /// 副本的修改时间；副本已随缓存删除时为 nil。
    private static func modificationDate(of file: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
    }

    /// 每秒检查一次副本的修改时间，编辑器保存后写回；仓库关闭或切换后停止。
    private func watch(_ copy: EditingCopy, request: Int) {
        Task { [weak self] in
            var saved = Self.modificationDate(of: copy.file)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))

                guard
                    let self,
                    generation == request,
                    let modified = Self.modificationDate(of: copy.file)
                else { return }

                // 仓库正在执行别的写操作或已断线时不记下这次修改，下一秒再试
                if modified != saved, writeBack(copy) {
                    saved = modified
                }
            }
        }
    }

    /// 把副本写回服务器；服务器上的文件已在别处改过时询问是否覆盖。
    ///
    /// - Returns: 写操作是否已开始；仓库暂不可写时为 false。
    @discardableResult
    private func writeBack(_ copy: EditingCopy, overwrite: Bool = false) -> Bool {
        guard let fileCache else {
            return false
        }

        let changed = ChangeFlag()

        return performGit(
            { _, _ in
                do {
                    try await fileCache.writeBack(copy, overwrite: overwrite)
                } catch ExternalToolError.fileChanged {
                    changed.set()
                }
            },
            title: AppLocalization.text("externalTool.saveCopy", Self.fileName(copy.path)),
            recordsActivity: false,
            success: { [weak self] in
                guard changed.isSet else { return }

                self?.confirmOverwrite(copy.path) {
                    self?.writeBack(copy, overwrite: true)
                }
            }
        )
    }
}
