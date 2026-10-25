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

    /// App 菜单的关于窗口：图标、名称、版本与构建号，以及项目网站与许可证。
    @objc
    func showAbout() {
        let credits = NSMutableAttributedString(
            string: AppLocalization.text("about.credits"),
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        )

        if let website = HelpLinks.website {
            credits.append(NSAttributedString(string: "\n"))
            credits.append(NSAttributedString(
                string: website.absoluteString,
                attributes: [.font: NSFont.systemFont(ofSize: 11), .link: website]
            ))
        }

        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Help › Spooky Help：在浏览器里打开项目网站上的使用说明。
    @objc
    func showHelp() {
        HelpLinks.website.map { _ = NSWorkspace.shared.open($0) }
    }

    /// Help › What's New：本版本的更新说明。
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
    /// 这个构建没有打包更新说明时 What's New 不可用；其余菜单项总是可用。
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        item.action != #selector(showWhatsNew) || WhatsNewWindowController.notes() != nil
    }
}
