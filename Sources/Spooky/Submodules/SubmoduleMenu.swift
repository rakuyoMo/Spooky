import AppKit
import SpookyKit

// MARK: - SubmoduleMenu

/// 子模块的右键菜单：打开、检出版本、获取与更新（按住 ⌥ 跳过对话框）、初始化、同步、移动、改名与删除。
///
/// 用 AppKit 菜单生成，Checkout Revision 子菜单的条目才能缩进；各项的可用性取自会话的 `can…` 规则。
@MainActor
enum SubmoduleMenu {
    /// 按子模块与会话现在的状态生成菜单，分四组，组间以分隔线隔开。
    static func menu(session: RepositorySession, submodule: Submodule) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let open = item(
            AppLocalization.text("submodule.open", submodule.name),
            enabled: submodule.isPopulated
        ) {
            session.open(submodule)
        }

        let groups = [
            [open],
            [checkoutItem(session: session, submodule: submodule)],
            updateItems(session: session, submodule: submodule),
            structureItems(session: session, submodule: submodule),
        ]

        for (index, group) in groups.enumerated() {
            if index > 0 {
                menu.addItem(.separator())
            }

            group.forEach(menu.addItem)
        }

        return menu
    }
}

// MARK: - Groups

extension SubmoduleMenu {
    /// Checkout Revision 子菜单。
    private static func checkoutItem(session: RepositorySession, submodule: Submodule) -> NSMenuItem {
        let item = NSMenuItem(
            title: AppLocalization.text("submodule.checkoutRevision"),
            action: nil,
            keyEquivalent: ""
        )

        item.submenu = SubmoduleRevisionMenu.menu(session: session, submodule: submodule)
        item.isEnabled = session.canCheckoutRevision(in: submodule)
        return item
    }

    /// 获取与更新（各带按住 ⌥ 时跳过对话框的快速项）、初始化与同步。
    private static func updateItems(session: RepositorySession, submodule: Submodule) -> [NSMenuItem] {
        let name = submodule.name
        let canFetch = session.canFetch(submodule)
        let canModify = session.canModify(submodule)

        let fetch = item(AppLocalization.text("submodule.fetch.menu", name), enabled: canFetch) {
            session.requestSubmodule(.fetch(submodule))
        }

        let quickFetch = alternate(AppLocalization.text("submodule.quickFetch", name), enabled: canFetch) {
            session.fetchSubmodules(
                [submodule],
                prunes: UserDefaults.standard.bool(forKey: SubmodulePreferences.fetchPrune)
            )
        }

        let update = item(AppLocalization.text("submodule.update.menu", name), enabled: canModify) {
            session.requestSubmodule(.update(submodule))
        }

        let quickUpdate = alternate(AppLocalization.text("submodule.quickUpdate", name), enabled: canModify) {
            session.updateSubmodules(
                [submodule],
                recursive: UserDefaults.standard.bool(forKey: SubmodulePreferences.updateRecursive)
            )
        }

        let initialize = item(AppLocalization.text("submodule.initialize.menu", name), enabled: canModify) {
            session.requestSubmodule(.initialize(submodule))
        }

        let synchronize = item(
            AppLocalization.text("submodule.synchronize.menu", name),
            enabled: session.canSynchronize(submodule)
        ) {
            session.requestSubmodule(.synchronize(submodule))
        }

        return [fetch, quickFetch, update, quickUpdate, initialize, synchronize]
    }

    /// 移动、改名与删除。
    private static func structureItems(session: RepositorySession, submodule: Submodule) -> [NSMenuItem] {
        let name = submodule.name
        let canModify = session.canModify(submodule)

        return [
            item(AppLocalization.text("submodule.move.menu", name), enabled: canModify) {
                session.requestSubmodule(.move(submodule))
            },
            item(AppLocalization.text("submodule.rename.menu", name), enabled: canModify) {
                session.requestSubmodule(.rename(submodule))
            },
            item(AppLocalization.text("submodule.delete.menu", name), enabled: session.canWrite) {
                session.requestSubmodule(.delete(submodule))
            },
        ]
    }
}

// MARK: - Helpers

extension SubmoduleMenu {
    /// 按住 ⌥ 时代替上一项显示的快速项。
    private static func alternate(
        _ title: String,
        enabled: Bool,
        perform: @escaping () -> Void
    ) -> NSMenuItem {
        let quick = item(title, enabled: enabled, perform: perform)
        quick.isAlternate = true
        quick.keyEquivalentModifierMask = .option
        return quick
    }

    /// 带闭包动作的菜单项。
    private static func item(
        _ title: String,
        enabled: Bool,
        perform: @escaping () -> Void
    ) -> NSMenuItem {
        FileViewMenuItem(FileViewAction(title: title, enabled: enabled, perform: perform))
    }
}
