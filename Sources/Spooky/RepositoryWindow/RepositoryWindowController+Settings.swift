import AppKit
import SwiftUI

// MARK: - Repository Settings

extension RepositoryWindowController {
    /// 侧边栏的 Settings 与快捷操作：主视图换成仓库设置。
    @objc
    func showRepositorySettings() {
        guard let repository = session.repository else {
            return
        }

        session.activeView = .settings

        if showsManager {
            display(repository)
        } else {
            session.onActiveViewChange?()
        }
    }

    /// 仓库设置：General、Git LFS、Ignores 与 Excludes 四段。
    func makeRepositorySettingsView() -> NSViewController {
        let controller = NSHostingController(rootView: RepositorySettingsView(session: session))
        controller.sizingOptions = [.minSize]
        return controller
    }
}
