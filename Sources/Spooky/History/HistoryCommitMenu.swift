import AppKit
import SpookyKit

// MARK: - HistoryCommitMenu

/// 历史列表复制哈希之后的右键菜单项，按 “单选 / 多选 × 是否在看 HEAD 分支 × 是否未拉取” 拼出。
///
/// 不在看 HEAD 分支时反转只有灰色的通用项，改写各项不出现；在看 HEAD 分支时，摘取只对未拉取的提交出现。
/// 多选时检出、重置、新建分支与标签只有灰色的通用项。按住 ⌥ 时保存补丁换成快速保存，比较两个提交换成反向比较。
@MainActor
enum HistoryCommitMenu {
    /// 按选中的提交生成菜单项，前面带一条分隔线。
    ///
    /// - Parameters:
    ///   - commits: 选中的提交，按列表顺序从新到旧。
    ///   - createBranch: 打开以这个版本为起点的新建分支对话框。
    static func items(
        for commits: [HistoryCommit],
        session: RepositorySession,
        createBranch: @escaping (String) -> Void
    ) -> [NSMenuItem] {
        guard !commits.isEmpty else {
            return []
        }

        let rewriting =
            session.isViewingHead
                ? headItems(commits, session: session)
                : otherItems(commits, session: session)

        return [.separator()]
            + checkoutItems(commits, session: session)
            + [.separator()]
            + rewriting
            + [.separator()]
            + creationItems(commits, session: session, createBranch: createBranch)
            + patchItems(commits, session: session)
    }
}

// MARK: - Groups

extension HistoryCommitMenu {
    /// 检出所选提交；多选时是灰色的通用项。
    private static func checkoutItems(_ commits: [HistoryCommit], session: RepositorySession) -> [NSMenuItem] {
        guard commits.count == 1, let commit = commits.first else {
            return [disabled("rewrite.menu.checkoutGeneric")]
        }

        return [
            item(AppLocalization.text("rewrite.menu.checkout", commit.shortID), enabled: session.canCheckoutRevision) {
                session.requestCheckout(commit.id)
            },
        ]
    }

    /// 不在看 HEAD 分支：重置、灰色的反转与摘取。
    private static func otherItems(_ commits: [HistoryCommit], session: RepositorySession) -> [NSMenuItem] {
        [
            reset(commits, session: session),
            disabled("rewrite.menu.revertGeneric"),
            cherryPick(commits, session: session),
        ]
    }

    /// 在看 HEAD 分支：重置、反转、只对未拉取提交的摘取、变基到别处，以及交互式变基的各项。
    private static func headItems(_ commits: [HistoryCommit], session: RepositorySession) -> [NSMenuItem] {
        let ids = commits.map(\.id)
        let single = commits.count == 1
        let unpulled = commits.allSatisfy { session.history.unpulled.contains($0.id) }

        let revert = item(
            single
                ? AppLocalization.text("rewrite.menu.revert", commits[0].shortID)
                : AppLocalization.text("rewrite.menu.revertMany", commits.count),
            enabled: session.canRewrite
        ) {
            session.requestRevert(ids)
        }

        let rebase = item(
            single
                ? AppLocalization.text("rewrite.menu.rebaseOnto", commits[0].shortID)
                : AppLocalization.text("rewrite.menu.rebaseOntoMany", commits.count),
            enabled: session.canRewrite
        ) {
            session.requestRebaseOnto(ids)
        }

        return [reset(commits, session: session), revert]
            + (unpulled ? [cherryPick(commits, session: session)] : [])
            + [rebase, .separator()]
            + interactiveItems(commits, session: session)
    }

    /// 交互式变基：单选是修补、编辑、改信息与删除，多选是删除、压缩与 fixup。
    private static func interactiveItems(_ commits: [HistoryCommit], session: RepositorySession) -> [NSMenuItem] {
        let ids = commits.map(\.id)

        let rewrite = { (key: String, argument: any CVarArg, action: RewriteAction) in
            item(AppLocalization.text(key, argument), enabled: session.canRewrite) {
                session.requestRewrite(action)
            }
        }

        guard commits.count == 1, let commit = commits.first else {
            return [
                rewrite("rewrite.menu.deleteMany", commits.count, .drop(ids)),
                rewrite("rewrite.menu.squashMany", commits.count, .squash(ids, into: nil)),
                rewrite("rewrite.menu.fixupMany", commits.count, .fixup(ids, into: nil)),
            ]
        }

        let reword = item(AppLocalization.text("rewrite.menu.reword", commit.shortID), enabled: session.canRewrite) {
            session.requestReword(commit.id)
        }

        return [
            rewrite("rewrite.menu.amend", commit.shortID, .amend(commit.id)),
            rewrite("rewrite.menu.edit", commit.shortID, .edit(commit.id)),
            reword,
            rewrite("rewrite.menu.delete", commit.shortID, .drop(ids)),
        ]
    }

    /// 从所选提交新建分支与标签；多选时都是灰色的通用项。
    private static func creationItems(
        _ commits: [HistoryCommit],
        session: RepositorySession,
        createBranch: @escaping (String) -> Void
    ) -> [NSMenuItem] {
        guard commits.count == 1, let commit = commits.first else {
            return [disabled("history.createBranchGeneric"), disabled("tag.createMenu")]
        }

        let branch = item(
            AppLocalization.text("history.createBranch", commit.shortID),
            enabled: session.canCreateBranchFromReference
        ) {
            createBranch(commit.id)
        }

        let tag = item(AppLocalization.text("tag.createFrom", commit.shortID), enabled: session.canCreateTag) {
            session.requestReference(.createTag(revision: commit.id))
        }

        return [branch, tag]
    }

    /// 重置到所选提交；多选时是灰色的通用项。
    private static func reset(_ commits: [HistoryCommit], session: RepositorySession) -> NSMenuItem {
        guard commits.count == 1, let commit = commits.first else {
            return disabled("rewrite.menu.resetGeneric")
        }

        return item(AppLocalization.text("rewrite.menu.reset", commit.shortID), enabled: session.canRewrite) {
            session.requestReset(to: commit.id)
        }
    }

    /// 摘取所选提交。
    private static func cherryPick(_ commits: [HistoryCommit], session: RepositorySession) -> NSMenuItem {
        let title =
            commits.count == 1
                ? AppLocalization.text("rewrite.menu.cherryPick", commits[0].shortID)
                : AppLocalization.text("rewrite.menu.cherryPickMany", commits.count)

        return item(title, enabled: session.canRewrite) {
            session.requestCherryPick(commits.map(\.id))
        }
    }
}

// MARK: - Patch, Export and Compare

extension HistoryCommitMenu {
    /// 保存补丁、导出文件与比较版本这一组，前面带一条分隔线。
    private static func patchItems(_ commits: [HistoryCommit], session: RepositorySession) -> [NSMenuItem] {
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
}

// MARK: - Helpers

extension HistoryCommitMenu {
    /// 不适用于当前选择的通用项：标题不带哈希，始终灰色。
    private static func disabled(_ key: String) -> NSMenuItem {
        item(AppLocalization.text(key), enabled: false) { }
    }

    /// 带闭包动作的菜单项。
    private static func item(_ title: String, enabled: Bool = true, perform: @escaping () -> Void) -> NSMenuItem {
        FileViewMenuItem(FileViewAction(title: title, enabled: enabled, perform: perform))
    }
}
