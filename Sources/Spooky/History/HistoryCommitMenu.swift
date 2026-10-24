import AppKit
import SpookyKit

// MARK: - HistoryCommitMenu

/// 历史列表右键菜单里保存补丁、导出文件与比较版本这一组；按住 ⌥ 时保存补丁换成快速保存，比较两个提交换成反向比较。
@MainActor
enum HistoryCommitMenu {
    /// 按选中的提交生成菜单项，前面带一条分隔线。
    ///
    /// - Parameter commits: 选中的提交，按列表顺序从新到旧。
    static func items(for commits: [HistoryCommit], session: RepositorySession) -> [NSMenuItem] {
        guard let first = commits.first else {
            return []
        }

        if commits.count == 1 {
            return [.separator()] + savePatch(
                commits,
                title: "patch.menu",
                quickTitle: "patch.quickMenu",
                argument: first.shortID,
                session: session
            ) + [
                item(AppLocalization.text("export.menuFrom", first.shortID)) {
                    session.onRevisionRequest?(.export(revision: first.shortID, paths: [], archive: false))
                },
                item(AppLocalization.text("compare.menuFrom", first.shortID)) {
                    session.onRevisionRequest?(.compare(base: first.shortID))
                },
            ]
        }

        let patches = savePatch(
            commits,
            title: "patch.menuMany",
            quickTitle: "patch.quickMenuMany",
            argument: commits.count,
            session: session
        )

        return [.separator()] + patches + [.separator()] + compare(commits, session: session)
    }

    /// 保存补丁与它的 ⌥ 快速保存。
    private static func savePatch(
        _ commits: [HistoryCommit],
        title: String,
        quickTitle: String,
        argument: any CVarArg,
        session: RepositorySession
    ) -> [NSMenuItem] {
        let quick = item(AppLocalization.text(quickTitle, argument)) {
            session.requestSavePatch(commits, quick: true)
        }

        quick.isAlternate = true
        quick.keyEquivalentModifierMask = .option

        return [
            item(AppLocalization.text(title, argument)) { session.requestSavePatch(commits, quick: false) },
            quick,
        ]
    }

    /// 选中两个提交时直接比较，默认从较早的到较新的，⌥ 时反向；其余数量打开比较对话框。
    private static func compare(_ commits: [HistoryCommit], session: RepositorySession) -> [NSMenuItem] {
        guard commits.count == 2 else {
            return [item(AppLocalization.text("compare.menu")) { session.onRevisionRequest?(.compare(base: nil)) }]
        }

        let (newer, older) = (commits[0], commits[1])

        let reversed = item(AppLocalization.text("compare.menuPair", newer.shortID, older.shortID)) {
            session.compareSelectedCommits(reversed: true)
        }

        reversed.isAlternate = true
        reversed.keyEquivalentModifierMask = .option

        return [
            item(AppLocalization.text("compare.menuPair", older.shortID, newer.shortID)) {
                session.compareSelectedCommits(reversed: false)
            },
            reversed,
        ]
    }

    /// 带闭包动作的菜单项。
    private static func item(_ title: String, perform: @escaping () -> Void) -> NSMenuItem {
        FileViewMenuItem(FileViewAction(title: title, perform: perform))
    }
}
