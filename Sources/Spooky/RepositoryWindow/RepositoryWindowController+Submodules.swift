import AppKit
import SpookyKit
import SwiftUI

// MARK: - Submodules

extension RepositoryWindowController {
    /// Repository › Add New Submodule… 与侧边栏的添加入口。
    @objc
    func addSubmodule() {
        presentSubmoduleRequest(.add)
    }

    /// Repository › Fetch Submodule…：在对话框里选子模块。
    @objc
    func fetchSubmodule() {
        presentSubmoduleRequest(.fetch(session.submodules.selected))
    }

    /// Repository › Fetch All Submodules：不经对话框，按上次的清理选项依次获取。
    @objc
    func fetchAllSubmodules() {
        let targets = session.submodules.items.filter { session.canFetch($0) }
        session.fetchSubmodules(targets, prunes: UserDefaults.standard.bool(forKey: SubmodulePreferences.fetchPrune))
    }

    /// Repository › Update Submodule…：在对话框里选子模块。
    @objc
    func updateSubmodule() {
        presentSubmoduleRequest(.update(session.submodules.selected))
    }

    /// Repository › Update All Submodules：不经对话框，按上次的递归选项更新全部子模块。
    @objc
    func updateAllSubmodules() {
        session.updateSubmodules(nil, recursive: UserDefaults.standard.bool(forKey: SubmodulePreferences.updateRecursive))
    }

    /// 工具栏的 Parent Repository：在本窗口打开父仓库。
    @objc
    func showParentRepository() {
        guard let location = session.superprojectLocation else {
            NSSound.beep()
            return
        }

        coordinator?.openRepository(at: location, from: self, inNewWindow: false)
    }

    /// 子模块动作的可用性；动作不属于本组时为 nil。
    func submoduleAvailability(of action: Selector?, repositoryView: Bool) -> Bool? {
        switch action {
        case #selector(addSubmodule):
            repositoryView && session.canWrite

        case #selector(fetchSubmodule), #selector(fetchAllSubmodules):
            repositoryView && session.canFetchSubmodules

        case #selector(updateSubmodule), #selector(updateAllSubmodules):
            repositoryView && session.canUpdateSubmodules

        case #selector(showParentRepository):
            repositoryView && session.superprojectLocation != nil

        default:
            nil
        }
    }

    /// 子模块视图：所选子模块的状态与两处配置。
    func makeSubmoduleDetailView() -> NSViewController {
        let controller = NSHostingController(rootView: SubmoduleDetailView(session: session))
        controller.sizingOptions = [.minSize]
        return controller
    }

    /// 呈现子模块的对话框或询问；对话框在写操作开始后才关闭，失败后的询问与错误 sheet 一样排队显示。
    func presentSubmoduleRequest(_ request: SubmoduleRequest) {
        guard let window, session.repository != nil else {
            return
        }

        switch request {
        case .forceDelete(let offer):
            askForceDeletion(offer, in: window)
            return

        case .forceAdd(let offer):
            askForceAddition(offer, in: window)
            return

        case .autoUpdate(let submodules):
            askAutoUpdate(submodules, in: window)
            return

        default:
            break
        }

        guard window.attachedSheet == nil, session.canWrite else {
            return
        }

        let sheet = NSWindow()
        sheet.styleMask = [.titled]
        sheet.tabbingMode = .disallowed

        let close = { [weak sheet] in
            if let sheet { window.endSheet(sheet) }
        }

        sheet.contentViewController = NSHostingController(rootView: dialog(for: request, close: close))
        window.beginSheet(sheet)
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 按请求选择对话框。
    private func dialog(for request: SubmoduleRequest, close: @escaping () -> Void) -> AnyView {
        switch request {
        case .add:
            AnyView(AddSubmoduleDialog(session: session, close: close))

        case .fetch(let submodule):
            AnyView(SubmoduleOperationDialog(session: session, kind: .fetch, submodule: submodule, close: close))

        case .update(let submodule):
            AnyView(SubmoduleOperationDialog(session: session, kind: .update, submodule: submodule, close: close))

        case .initialize(let submodule):
            AnyView(SubmoduleOperationDialog(session: session, kind: .initialize, submodule: submodule, close: close))

        case .synchronize(let submodule):
            AnyView(SubmoduleOperationDialog(session: session, kind: .synchronize, submodule: submodule, close: close))

        case .repair(let submodule):
            AnyView(SubmoduleOperationDialog(session: session, kind: .repair, submodule: submodule, close: close))

        case .delete(let submodule):
            AnyView(SubmoduleOperationDialog(session: session, kind: .delete, submodule: submodule, close: close))

        case .move(let submodule):
            AnyView(SubmoduleValueDialog(session: session, submodule: submodule, target: .move, close: close))

        case .rename(let submodule):
            AnyView(SubmoduleValueDialog(session: session, submodule: submodule, target: .rename, close: close))

        case .editURL(let submodule, let scope):
            AnyView(SubmoduleValueDialog(session: session, submodule: submodule, target: .url(scope), close: close))

        case .forceDelete, .forceAdd, .autoUpdate:
            AnyView(EmptyView())
        }
    }

    /// 子模块里有本地改动时询问是否强制删除。
    private func askForceDeletion(_ offer: SubmoduleDeletionOffer, in window: NSWindow) {
        let repository = session.repository

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppLocalization.text("submodule.delete")
        alert.informativeText = AppLocalization.text("submodule.forceDelete.message", offer.submodule.name)
        alert.addButton(withTitle: AppLocalization.text("submodule.forceDelete.submit"))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))
        alert.buttons.first?.hasDestructiveAction = true

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn, session.repository == repository else {
                return
            }

            session.deleteSubmodule(offer.submodule, keepsWorkingTree: offer.keepsWorkingTree, force: true)
        }
    }

    /// 已有同名 Git 目录时询问复用还是覆盖。
    private func askForceAddition(_ offer: SubmoduleAdditionOffer, in window: NSWindow) {
        let repository = session.repository

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppLocalization.text("submodule.forceAdd")
        alert.informativeText = AppLocalization.text("submodule.forceAdd.message", offer.path)
        alert.addButton(withTitle: AppLocalization.text("submodule.forceAdd.reuse"))
        alert.addButton(withTitle: AppLocalization.text("submodule.forceAdd.overwrite"))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))
        alert.buttons[1].hasDestructiveAction = true

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, session.repository == repository else {
                return
            }

            switch response {
            case .alertFirstButtonReturn:
                session.addSubmodule(url: offer.url, path: offer.path, reusesGitDirectory: true)

            case .alertSecondButtonReturn:
                session.addSubmodule(url: offer.url, path: offer.path, overwrites: true)

            default:
                break
            }
        }
    }

    /// 操作改动了已初始化子模块的指针时询问是否更新；勾选 “总是” 后之后的操作直接更新。
    private func askAutoUpdate(_ submodules: [Submodule], in window: NSWindow) {
        let repository = session.repository

        let alert = NSAlert()
        alert.messageText = AppLocalization.text("submodule.autoUpdate")
        alert.informativeText = AppLocalization.text("submodule.autoUpdate.message")
            + "\n\n" + submodules.map(\.name).joined(separator: "\n")
        alert.addButton(withTitle: AppLocalization.text("submodule.autoUpdate.update"))
        alert.addButton(withTitle: AppLocalization.text("submodule.autoUpdate.skip"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = AppLocalization.text("submodule.autoUpdate.always")

        alert.beginSheetModal(for: window) { [weak self, weak alert] response in
            guard let self, response == .alertFirstButtonReturn, session.repository == repository else {
                return
            }

            if alert?.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: SubmodulePreferences.alwaysUpdate)
            }

            session.updateSubmodules(submodules, recursive: false)
        }
    }
}
