import SpookyKit
import SwiftUI

// MARK: - Reselection

extension RepositorySidebarView {
    /// 列表的选择与可选中的行；历史按引用筛选时记下行的顺序，筛选的引用消失后据此找接替它的行。
    struct SelectionState: Equatable {
        /// 选中的行。
        let selection: Set<String>

        /// 按显示顺序排列的可选中的行；历史没有按引用筛选时为空。
        let rows: [String]
    }

    /// 当前的选择；可选中的行只在历史按引用筛选时列出，只有这时引用消失才要找接替的行。
    var selectionState: SelectionState {
        let filtersReferences = session.activeView == .history
            && !session.history.selectedReferences.isEmpty

        return SelectionState(
            selection: selectedItems,
            rows: filtersReferences ? selectableRows : []
        )
    }

    /// 筛选的引用全部被删除、历史回到全部提交时，选中原位置上接替它的行。
    ///
    /// 从原来选中的第一行的位置往下找第一个可选中的行，下面没有时往上找，都没有时选 Working Copy。
    ///
    /// - Parameter old: 引用消失前的选择与行。
    func reselectVanishedRows(from old: SelectionState) {
        guard
            session.activeView == .history,
            session.history.selectedReferences.isEmpty,
            let index = old.rows.firstIndex(where: old.selection.contains)
        else {
            return
        }

        // 原来选中的引用还在时，是点了 History 等操作回到全部历史，不是引用消失；还没有读到引用快照时同样不算
        let references = Set(old.selection.map(Self.reference(forRow:)))

        guard session.history.existingReferences(references).isEmpty else {
            return
        }

        // 行里只有可选中的行：原位置上还有行，它就是往下找到的第一行；原位置越过了末尾，往上找到的是最后一行
        let rows = selectableRows
        let replacement = index < rows.count ? rows[index] : rows.last ?? "workingCopy"

        selection.wrappedValue = [replacement]
    }
}

// MARK: - Private

extension RepositorySidebarView {
    /// 按显示顺序排列的可选中的行：收起的分组、远端与文件夹里的行不算，分组标题与文件夹本身不可选中。
    private var selectableRows: [String] {
        var rows = selectableWorkspaceRows

        rows += selectableBranchRows

        if isExpanded(.tags).wrappedValue {
            rows += visibleRows(in: tagNodes)
        }

        if isExpanded(.remotes).wrappedValue {
            rows += selectableRemoteRows
        }

        if isExpanded(.submodules).wrappedValue {
            rows += filteredSubmodules.map { Self.submoduleRowPrefix + $0.path }
        }

        if isExpanded(.worktrees).wrappedValue {
            rows += filteredWorktrees.map { Self.worktreeRowPrefix + $0.path }
        }

        return rows
    }

    /// Workspace 分组里的行。
    private var selectableWorkspaceRows: [String] {
        guard isExpanded(.workspace).wrappedValue else {
            return []
        }

        // 视图设置打开 Show Reflog 时才有 Reflog 行
        let reflog = showsReflog ? ["reflog"] : []

        return ["workingCopy", "history", "stashes", "pullRequests", "branchesReview"] + reflog + ["settings"]
    }

    /// Pinned、Branches 与 Archived Branches 三个分组里的行。
    private var selectableBranchRows: [String] {
        let local = localReferences
        let pinned = local.filter { metadata(for: $0).isPinned }
        var rows: [String] = []

        // Pinned 分组只在有置顶分支时出现，行身份带前缀
        if !pinned.isEmpty, isExpanded(.pinned).wrappedValue {
            rows += visibleRows(in: branchNodes(pinned, scope: "pinned")).map { Self.pinnedRowPrefix + $0 }
        }

        if isExpanded(.branches).wrappedValue {
            if headRowName != nil {
                rows.append("HEAD")
            }

            rows += visibleRows(
                in: branchNodes(local.filter { !metadata(for: $0).isArchived }, scope: "branches")
            )
        }

        if isExpanded(.archived).wrappedValue {
            rows += visibleRows(
                in: branchNodes(local.filter { metadata(for: $0).isArchived }, scope: "archived")
            )
        }

        return rows
    }

    /// Remotes 分组里的行：每个远端一行，展开的远端下面是它的远端分支。
    private var selectableRemoteRows: [String] {
        (session.history.snapshot?.remotes ?? []).flatMap { remote in
            let branches = isExpanded(remote.sidebarID).wrappedValue
                ? visibleRows(in: remoteBranchNodes(remote))
                : []

            return [Self.remoteRowPrefix + remote.name] + branches
        }
    }

    /// 一组节点里看得见的引用行；文件夹收起时，里面的行看不见。
    private func visibleRows(in nodes: [SidebarRefNode]) -> [String] {
        nodes.flatMap { node -> [String] in
            if let reference = node.reference {
                return [reference.id]
            }

            return isExpanded(node.id).wrappedValue ? visibleRows(in: node.children) : []
        }
    }
}
