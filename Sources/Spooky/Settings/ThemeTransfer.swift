import AppKit

// MARK: - ThemeTransfer

/// Themes 页的导入、导出与出错提示：同名时询问是否覆盖，提示显示在设置窗口上。
@MainActor
enum ThemeTransfer {
    /// 用打开面板选择主题文件导入，可以多选。
    static func chooseImport(into store: ThemeStore, window: NSWindow?) async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [TextTheme.fileType]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard await run(panel, in: window) == .OK else {
            return
        }

        await importThemes(panel.urls, into: store, window: window)
    }

    /// 逐个导入主题文件：同名时询问是否覆盖，无法导入的文件各自报错，不影响其余文件。
    static func importThemes(_ urls: [URL], into store: ThemeStore, window: NSWindow?) async {
        for url in urls {
            do {
                try store.importTheme(at: url, replacing: false)
            } catch ThemeStoreError.fileExists(let destination) {
                guard await confirmReplace(destination, window: window) else {
                    continue
                }

                do {
                    try store.importTheme(at: url, replacing: true)
                } catch {
                    await report(error, titleKey: "themes.error.import", file: url, window: window)
                }
            } catch {
                await report(error, titleKey: "themes.error.import", file: url, window: window)
            }
        }
    }

    /// 用存储面板导出主题；目标已有同名文件时由面板自己询问是否替换。
    static func export(_ theme: TextTheme, window: NSWindow?) async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [TextTheme.fileType]
        panel.nameFieldStringValue = TextTheme.fileName(for: theme.name)

        guard await run(panel, in: window) == .OK, let url = panel.url else {
            return
        }

        do {
            try theme.encoded().write(to: url, options: .atomic)
        } catch {
            await report(error, titleKey: "themes.error.export", file: nil, window: window)
        }
    }

    /// 拖到 Finder 时写出主题文件；目标已有同名文件时先询问，不覆盖就当作用户取消。
    ///
    /// 文件承诺在拖放结束后才要求写入，此时可以弹出模态提示。
    static func writePromise(_ theme: TextTheme, to url: URL) -> Error? {
        #warning("TODO: 把主题拖到已有同名文件的 Finder 文件夹，核实是弹出覆盖确认还是由 Finder 改名、确认框开着时 Finder 是否超时；只影响拖出导出的同名处理。")

        let exists = FileManager.default.fileExists(atPath: url.path)

        if exists, replaceAlert(url).runModal() != .alertFirstButtonReturn {
            return CocoaError(.userCancelled)
        }

        do {
            try theme.encoded().write(to: url, options: .atomic)
            return nil
        } catch {
            Task {
                await report(error, titleKey: "themes.error.export", file: nil, window: nil)
            }
            return error
        }
    }

    /// 询问是否覆盖已有的主题文件。
    static func confirmReplace(_ url: URL, window: NSWindow?) async -> Bool {
        await run(replaceAlert(url), in: window) == .alertFirstButtonReturn
    }

    /// 显示一次失败：标题说明是哪个操作，正文说明原因。
    ///
    /// - Parameters:
    ///   - error: 失败原因。
    ///   - titleKey: 操作对应的标题资源键。
    ///   - file: 读取失败的文件，用来说明是哪份文件无效。
    ///   - window: 提示所在的窗口；nil 时以模态窗口显示。
    static func report(_ error: Error, titleKey: String, file: URL?, window: NSWindow?) async {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppLocalization.text(titleKey)
        alert.informativeText = message(for: error, file: file)
        alert.addButton(withTitle: AppLocalization.text("action.close"))
        _ = await run(alert, in: window)
    }
}

// MARK: - Helpers

extension ThemeTransfer {
    /// 覆盖确认：标题、目标路径与 “替换” “取消” 两个按钮。
    private static func replaceAlert(_ url: URL) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppLocalization.text("themes.exists")
        alert.informativeText = AppLocalization.text("themes.exists.message", url.path)
        alert.addButton(withTitle: AppLocalization.text("themes.replace"))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))
        return alert
    }

    /// 主题自己的失败给出本地化说明，文件读写等系统错误使用系统的说明。
    private static func message(for error: Error, file: URL?) -> String {
        guard let failure = error as? ThemeStoreError else {
            return error.localizedDescription
        }

        switch failure {
        case .invalidFile:
            return AppLocalization.text("themes.error.invalidFile", file?.lastPathComponent ?? "")

        case .nameInUse(let name):
            return AppLocalization.text("themes.error.nameInUse", name)

        case .fileExists(let url):
            return AppLocalization.text("themes.exists.message", url.path)
        }
    }

    /// 有窗口时以 sheet 显示提示，否则以模态窗口显示。
    private static func run(_ alert: NSAlert, in window: NSWindow?) async -> NSApplication.ModalResponse {
        guard let window else {
            return alert.runModal()
        }

        return await alert.beginSheetModal(for: window)
    }

    /// 有窗口时以 sheet 显示打开或存储面板，否则以模态窗口显示。
    private static func run(_ panel: NSSavePanel, in window: NSWindow?) async -> NSApplication.ModalResponse {
        guard let window else {
            return panel.runModal()
        }

        return await panel.beginSheetModal(for: window)
    }
}
