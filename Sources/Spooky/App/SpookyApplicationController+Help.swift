import AppKit
import SpookyKit

// MARK: - Help

extension SpookyApplicationController {
    /// Help 菜单：帮助、What's New 与发行说明，问题反馈，以及导出诊断报告；登记为应用的帮助菜单。
    func configureHelpMenu(in menu: NSMenu) {
        let help = addMenu("menu.help", to: menu)
        NSApp.helpMenu = help

        addItem("help.help", action: #selector(showHelp), key: "?", target: self, to: help)
        addItem("help.whatsNew", action: #selector(showWhatsNew), target: self, to: help)
        addItem("help.releaseNotes", action: #selector(openReleaseNotes), target: self, to: help)

        help.addItem(.separator())
        addItem("help.support", action: #selector(openSupport), target: self, to: help)

        help.addItem(.separator())
        addItem("help.diagnosticReport", action: #selector(createDiagnosticReport), target: self, to: help)
    }

    /// App 菜单的关于窗口：图标、名称、版本与 Release Notes，说明、版权与 Acknowledgements、License。
    @objc
    func showAbout() {
        AboutWindowController.show()
    }

    /// Help › Spooky Help：在浏览器里打开项目网站上的使用说明。
    @objc
    func showHelp() {
        HelpLinks.website.map { _ = NSWorkspace.shared.open($0) }
    }

    /// Help › What's New：历次版本的更新说明。
    @objc
    func showWhatsNew() {
        WhatsNewWindowController.show()
    }

    /// Help › Release Notes：GitHub 上每个版本的发行说明。
    @objc
    func openReleaseNotes() {
        HelpLinks.releases.map { _ = NSWorkspace.shared.open($0) }
    }

    /// Help › Support：GitHub 上的问题反馈。
    @objc
    func openSupport() {
        HelpLinks.issues.map { _ = NSWorkspace.shared.open($0) }
    }

    /// Help › Create Diagnostic Report…：生成脱敏的报告，存到用户选的位置。
    @objc
    func createDiagnosticReport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = AppLocalization.text("help.diagnosticReport.file")
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            let report = await DiagnosticReport.make(bookmarks: bookmarks, activities: RepositoryActivities.shared.items)

            do {
                try Data(report.utf8).write(to: url, options: .atomic)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                NSApp.presentError(error)
            }
        }
    }
}

// MARK: - SpookyApplicationController + NSMenuItemValidation

extension SpookyApplicationController: NSMenuItemValidation {
    /// 这个构建没有打包任何版本的更新说明时 What's New 不可用，没有当前版本的说明时 Show What's New Card 不可用；
    /// 最近打开列表为空时 Clear Menu 不可用；Auto-Reload Repository 同时标出开关状态；其余菜单项总是可用。
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(clearRecentRepositories):
            return !bookmarks.recentlyOpened.isEmpty

        case #selector(showWhatsNew):
            return !WhatsNewState.shared.entries.isEmpty

        case #selector(showWhatsNewCard):
            return WhatsNewState.shared.hasCurrentNotes

        case #selector(setAutoExpand(_:)):
            item.state = item.tag == changesetPreferences.integer(forKey: "historyAutoExpand") ? .on : .off
            return true

        case #selector(toggleAutoReload):
            item.state = DeveloperPreferences.autoReloads() ? .on : .off
            return true

        default:
            return true
        }
    }
}
