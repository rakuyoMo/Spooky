import SpookyKit
import SwiftUI

// MARK: - Delete Command

extension RepositorySidebarView {
    /// Edit 菜单 Delete（⌘⌫）在侧边栏里的动作：按当前选择打开本地分支、远端分支、标签、远端或子模块各自的删除确认。
    ///
    /// 只在侧边栏的列表有键盘焦点时生效；选择里没有可删除的对象、几种对象混在一起，或会话不允许删除时为 nil，菜单项随之不可用。
    var deleteCommand: (() -> Void)? {
        switch session.activeView {
        case .remote:
            guard let remote = session.selectedRemote, session.canWrite else {
                return nil
            }

            return { session.requestReference(.deleteRemotes([remote])) }

        case .submodule:
            // 有改动时的强制删除确认由子模块的删除入口自己处理
            guard let submodule = session.submodules.selected, session.canWrite else {
                return nil
            }

            return { session.requestSubmodule(.delete(submodule)) }

        case .history:
            return referenceDeletion(session.history.selectedReferences)

        default:
            return nil
        }
    }

    /// 所选引用的删除：全是本地分支、全是远端分支或全是标签时才有；当前分支不能删除。
    private func referenceDeletion(_ selected: Set<String>) -> (() -> Void)? {
        let branches = session.history.branches.filter { selected.contains($0.id) }
        let tags = session.tags.filter { selected.contains($0.id) }

        // 选择里还有分离 HEAD 行或已消失的引用时不删除
        guard !selected.isEmpty, branches.count + tags.count == selected.count else {
            return nil
        }

        if tags.isEmpty, branches.allSatisfy(\.isLocal) {
            guard session.canDelete(branches) else {
                return nil
            }

            return { session.requestReference(.deleteBranches(branches)) }
        }

        if tags.isEmpty, branches.allSatisfy(\.isRemote) {
            guard session.canDeleteRemoteBranches(branches) else {
                return nil
            }

            return { session.requestReference(.deleteRemoteBranches(branches)) }
        }

        guard branches.isEmpty, session.canWrite else {
            return nil
        }

        return { session.requestReference(.deleteTags(tags.map(\.name))) }
    }
}
