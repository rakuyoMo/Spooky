import AppKit
import SpookyKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Diff

extension RepositoryWindowController {
    /// View › Diff Context Lines：写入全局偏好，各窗口的 Diff 随偏好重新读取。
    @objc
    func setDiffContextLines(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: DiffPreferences.contextLinesKey)
    }

    /// Working Copy › Save Patch…：先确认范围与前缀选项，再在本机选择保存位置。
    @objc
    func savePatch() {
        let entries = session.selectedEntries

        guard let window, window.attachedSheet == nil, !entries.isEmpty else {
            return
        }

        let name = patchName(for: entries)
        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed
        sheet.contentViewController = NSHostingController(
            rootView: SavePatchDialog(
                count: entries.count,
                cancel: { [weak sheet] in
                    if let sheet { window.endSheet(sheet) }
                },
                submit: { [weak self, weak sheet] omitsPrefixes in
                    if let sheet { window.endSheet(sheet) }

                    // 补丁内容在仓库所在机器上生成，保存面板只决定本机的位置
                    self?.save(named: name, type: "patch") { runner in
                        try await WorkingCopyOperations(runner: runner)
                            .patchFile(for: entries, omittingPrefixes: omitsPrefixes)
                    }
                }
            )
        )
        window.beginSheet(sheet)
    }

    /// Working Copy › Export Diff…：按当前显示的暂存侧、上下文与空白选项导出详情里的 Diff。
    @objc
    func exportDiff() {
        guard let snapshot = session.diffSnapshot, snapshot.diff != nil else {
            return
        }

        let name = (snapshot.entry.path.split(separator: "/").last.map(String.init) ?? "diff") + ".diff"

        save(named: name, type: "diff") { runner in
            try await WorkingCopyOperations(runner: runner)
                .patch(for: snapshot.entry, side: snapshot.side, options: snapshot.options)
        }
    }

    /// Diff 相关菜单项的可用性；不属于本组时返回空，交给其它分组判断。
    func diffAvailability(of item: any NSValidatedUserInterfaceItem) -> Bool? {
        let workingCopy = !showsManager && session.repository != nil && session.activeView == .workingCopy

        switch item.action {
        case #selector(setDiffContextLines(_:)):
            if let item = item as? NSMenuItem {
                item.state = item.tag == DiffPreferences.options().contextLines ? .on : .off
            }

            return !showsManager && session.repository != nil

        case #selector(savePatch):
            return workingCopy && !session.selectedEntries.isEmpty

        case #selector(exportDiff):
            return workingCopy && session.diffSnapshot?.diff != nil

        default:
            return nil
        }
    }

    /// 单个文件以文件名命名，多个文件以仓库名命名。
    private func patchName(for entries: [StatusEntry]) -> String {
        let source = entries.count == 1 ? entries[0].path : (session.repository?.path ?? "changes")
        return (source.split(separator: "/").last.map(String.init) ?? "changes") + ".patch"
    }

    /// 在本机选择位置后生成内容并写入；失败时显示原始错误。
    private func save(
        named name: String,
        type pathExtension: String,
        contents: @escaping @Sendable (GitRunner) async throws -> Data
    ) {
        guard let window, let runner = session.runner else {
            return
        }

        let repository = session.repository
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [UTType(filenameExtension: pathExtension) ?? .plainText]
        panel.canCreateDirectories = true

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            Task { @MainActor [weak self] in
                do {
                    try await contents(runner).write(to: url, options: .atomic)
                } catch {
                    self?.showFailure(AppFailure(error: error, opening: false, location: repository))
                }
            }
        }
    }
}
