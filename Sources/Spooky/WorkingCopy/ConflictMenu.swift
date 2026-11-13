import AppKit
import SpookyKit

// MARK: - ConflictMenu

/// 工作区文件右键菜单的冲突组：“解决合并冲突” 与 “恢复合并冲突的版本” 两个子菜单总能展开，子项按作用的文件逐项判断可用性。
@MainActor
enum ConflictMenu {
    /// 把冲突组的两个子菜单加到菜单末尾。
    ///
    /// - Parameters:
    ///   - menu: 右键菜单。
    ///   - entries: 右键菜单作用的文件。
    ///   - names: 右键菜单作用的各行的名称，标题按它点名或计数；树形里一个目录算一项。
    ///   - session: 执行操作与判断可用性的仓库会话。
    static func add(to menu: NSMenu, entries: [StatusEntry], names: [String], session: RepositorySession) {
        menu.addItem(submenu("conflict.menu.resolve", items: resolveItems(entries, names: names, session: session)))
        menu.addItem(submenu("conflict.menu.restore", items: restoreItems(entries, names: names, session: session)))
    }
}

// MARK: - Private

extension ConflictMenu {
    /// 标记解决与采用某一侧的版本；只作用于其中的冲突文件。
    private static func resolveItems(
        _ entries: [StatusEntry],
        names: [String],
        session: RepositorySession
    ) -> [NSMenuItem] {
        let conflicted = entries.filter { $0.kind == .conflicted }
        let enabled = session.canResolve(conflicted)
        let mark = title(
            names,
            one: "conflict.markResolved.one",
            many: "conflict.markResolved.many",
            generic: "working.resolved"
        )

        // 对方来自补丁或储藏时没有版本名，不加引号
        let theirs =
            session.context?.progress == nil
                ? AppLocalization.text("conflict.resolveUsingVersion.applied")
                : AppLocalization.text("conflict.resolveUsingVersion", session.theirsName)

        return [
            ConflictMenuItem(title: mark, enabled: enabled) {
                session.stage(conflicted, staged: true)
            },
            ConflictMenuItem(
                title: AppLocalization.text("conflict.resolveUsingVersion", session.oursName),
                enabled: enabled
            ) {
                session.resolve(conflicted, theirs: false)
            },
            ConflictMenuItem(title: theirs, enabled: enabled) {
                session.resolve(conflicted, theirs: true)
            },
        ]
    }

    /// 重新生成冲突，以及恢复成我方、对方或共同祖先的版本。
    private static func restoreItems(
        _ entries: [StatusEntry],
        names: [String],
        session: RepositorySession
    ) -> [NSMenuItem] {
        let restoreUnmerged = title(
            names,
            one: "conflict.restoreUnmerged.one",
            many: "conflict.restoreUnmerged.many",
            generic: "conflict.restoreUnmerged"
        )

        // 对方来自补丁或储藏时没有版本名，不加引号
        let theirs =
            session.context?.progress == nil
                ? AppLocalization.text("conflict.restoreVersion.applied")
                : AppLocalization.text("conflict.restoreVersion", session.theirsName)

        let versions: [(String, ConflictVersion)] = [
            (restoreUnmerged, .unmerged),
            (AppLocalization.text("conflict.restoreVersion", session.oursName), .ours),
            (theirs, .theirs),
            (AppLocalization.text("conflict.restoreAncestor"), .base),
        ]

        return versions.map { title, version in
            ConflictMenuItem(title: title, enabled: session.canRestoreConflicts(entries, to: version)) {
                session.restoreConflicts(entries, to: version, title: title)
            }
        }
    }

    /// 带子菜单的菜单项：父项总能展开，子菜单的可用性由各项自己决定。
    private static func submenu(_ key: String, items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: AppLocalization.text(key), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: item.title)

        submenu.autoenablesItems = false
        items.forEach(submenu.addItem)

        item.submenu = submenu
        return item
    }

    /// 按作用的全部对象点名或计数，没有作用对象时用通用标题；不是冲突文件、菜单项不可用时也照此书写。
    private static func title(_ names: [String], one: String, many: String, generic: String) -> String {
        switch names.count {
        case 0: AppLocalization.text(generic)
        case 1: AppLocalization.text(one, names[0])
        default: AppLocalization.text(many, names.count)
        }
    }
}

// MARK: - ConflictMenuItem

/// 自带动作的菜单项：以自己为目标，菜单存在期间动作一直有效，不依赖响应链。
final class ConflictMenuItem: NSMenuItem {
    /// 选中菜单项时执行的动作。
    private let handler: () -> Void

    /// 创建菜单项。
    ///
    /// - Parameters:
    ///   - title: 已本地化的标题。
    ///   - enabled: 是否可用。
    ///   - handler: 选中时执行的动作。
    init(title: String, enabled: Bool, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(performHandler), keyEquivalent: "")

        target = self
        isEnabled = enabled
    }

    /// 菜单项只由代码创建，归档恢复时没有动作。
    required init(coder: NSCoder) {
        handler = { }
        super.init(coder: coder)
    }

    /// 执行选中时的动作。
    @objc
    private func performHandler() {
        handler()
    }
}
