import AppKit
import SpookyKit

// MARK: - ConflictMenu

/// 工作区文件右键菜单的冲突组：“解决合并冲突” 与 “恢复合并冲突的版本” 两个子菜单，可用性按所选文件逐项判断。
@MainActor
enum ConflictMenu {
    /// 把冲突组的两个子菜单加到菜单末尾。
    ///
    /// - Parameters:
    ///   - menu: 右键菜单。
    ///   - entries: 右键菜单作用的文件。
    ///   - session: 执行操作与判断可用性的仓库会话。
    static func add(to menu: NSMenu, entries: [StatusEntry], session: RepositorySession) {
        let conflicted = entries.filter { $0.kind == .conflicted }

        menu.addItem(submenu(
            "conflict.menu.resolve",
            items: resolveItems(conflicted, session: session),
            enabled: !conflicted.isEmpty
        ))

        let restore = restoreItems(entries, session: session)

        menu.addItem(submenu(
            "conflict.menu.restore",
            items: restore,
            enabled: restore.contains(where: \.isEnabled)
        ))
    }
}

// MARK: - Private

extension ConflictMenu {
    /// 标记解决与采用某一侧的版本。
    private static func resolveItems(_ conflicted: [StatusEntry], session: RepositorySession) -> [NSMenuItem] {
        let enabled = session.canResolve(conflicted)

        let mark: String =
            switch conflicted.count {
            case 1: AppLocalization.text("conflict.markResolved.one", fileName(conflicted[0]))
            case 2...: AppLocalization.text("conflict.markResolved.many", conflicted.count)
            default: AppLocalization.text("working.resolved")
            }

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
            ConflictMenuItem(
                title: AppLocalization.text("conflict.resolveUsingVersion", session.theirsName),
                enabled: enabled
            ) {
                session.resolve(conflicted, theirs: true)
            },
        ]
    }

    /// 重新生成冲突，以及恢复成我方、对方或共同祖先的版本。
    private static func restoreItems(_ entries: [StatusEntry], session: RepositorySession) -> [NSMenuItem] {
        let resolved = session.context?.progress?.resolvedPaths ?? []
        let unmerged = entries.filter { $0.kind == .conflicted || resolved.contains($0.path) }

        let restoreUnmerged: String =
            switch unmerged.count {
            case 1: AppLocalization.text("conflict.restoreUnmerged.one", fileName(unmerged[0]))
            case 2...: AppLocalization.text("conflict.restoreUnmerged.many", unmerged.count)
            default: AppLocalization.text("conflict.restoreUnmerged")
            }

        let versions: [(String, ConflictVersion)] = [
            (restoreUnmerged, .unmerged),
            (AppLocalization.text("conflict.restoreVersion", session.oursName), .ours),
            (AppLocalization.text("conflict.restoreVersion", session.theirsName), .theirs),
            (AppLocalization.text("conflict.restoreAncestor"), .base),
        ]

        return versions.map { title, version in
            ConflictMenuItem(title: title, enabled: session.canRestoreConflicts(entries, to: version)) {
                session.restoreConflicts(entries, to: version, title: title)
            }
        }
    }

    /// 带子菜单的菜单项；子菜单的可用性由各项自己决定。
    private static func submenu(_ key: String, items: [NSMenuItem], enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: AppLocalization.text(key), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: item.title)

        submenu.autoenablesItems = false
        items.forEach(submenu.addItem)

        item.submenu = submenu
        item.isEnabled = enabled
        return item
    }

    /// 菜单项里显示的文件名，不含目录。
    private static func fileName(_ entry: StatusEntry) -> String {
        entry.path.split(separator: "/").last.map(String.init) ?? entry.path
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
