import SpookyKit
import SwiftUI

// MARK: - Reselection

extension RepositorySidebarView {
    /// 列表的选择与显示的行；历史按引用筛选时记下行的顺序，筛选的引用消失后据此找接替它的行。
    struct SelectionState: Equatable {
        /// 选中的行。
        let selection: Set<String>

        /// 按显示顺序排列的行，分组标题、文件夹与占位文字这些不可选中的行为 nil；历史没有按引用筛选时为空。
        let rows: [String?]
    }

    /// 当前的选择；显示的行只在历史按引用筛选时列出，只有这时引用消失才要找接替的行。
    var selectionState: SelectionState {
        let filtersReferences = session.activeView == .history
            && !session.history.selectedReferences.isEmpty

        return SelectionState(
            selection: selectedItems,
            rows: filtersReferences ? displayedRows : []
        )
    }

    /// 筛选的引用全部被删除、历史回到全部提交时，选中原位置上接替它的行。
    ///
    /// 按行号找：从原来选中的第一行的行号往下找第一个可选中的行，下面没有时往上找，都没有时选 Working Copy。
    /// 分组标题、文件夹与占位文字同样占行号，引用连同它所在的文件夹一起消失时，接替的是落到原行号上的那一行。
    ///
    /// - Parameter old: 引用消失前的选择与行。
    func reselectVanishedRows(from old: SelectionState) {
        guard
            session.activeView == .history,
            session.history.selectedReferences.isEmpty,
            let index = old.rows.firstIndex(where: { $0.map(old.selection.contains) ?? false })
        else {
            return
        }

        // 原来选中的引用还在时，是点了 History 等操作回到全部历史，不是引用消失；还没有读到引用快照时同样不算
        let references = Set(old.selection.map(Self.reference(forRow:)))

        guard session.history.existingReferences(references).isEmpty else {
            return
        }

        let rows = displayedRows
        let below = rows.dropFirst(index).compactMap(\.self).first
        let above = rows.prefix(index).compactMap(\.self).last

        selection.wrappedValue = [below ?? above ?? "workingCopy"]
    }
}

// MARK: - Private

extension RepositorySidebarView {
    /// 按显示顺序排列的行：分组标题、文件夹与占位文字不可选中，记为 nil；收起的分组、远端与文件夹里的行看不见，不算。
    private var displayedRows: [String?] {
        var rows = workspaceRows

        rows += branchRows
        rows += section(.tags) { displayedRows(in: tagNodes) }
        rows += section(.remotes) { remoteRows }
        rows += section(.submodules) { filteredSubmodules.map { Self.submoduleRowPrefix + $0.path } }
        rows += section(.worktrees) { filteredWorktrees.map { Self.worktreeRowPrefix + $0.path } }

        return rows
    }

    /// Workspace 分组的行。
    private var workspaceRows: [String?] {
        section(.workspace) {
            // 视图设置打开 Show Reflog 时才有 Reflog 行
            let reflog = showsReflog ? ["reflog"] : []

            return ["workingCopy", "history", "stashes", "pullRequests", "branchesReview"] + reflog + ["settings"]
        }
    }

    /// Pinned、Branches 与 Archived Branches 三个分组的行。
    private var branchRows: [String?] {
        let local = localReferences
        let pinned = local.filter { metadata(for: $0).isPinned }
        var rows: [String?] = []

        // Pinned 分组只在有置顶分支时出现，行身份带前缀
        if !pinned.isEmpty {
            rows += section(.pinned) {
                displayedRows(in: branchNodes(pinned, scope: "pinned")).map { row in
                    row.map { Self.pinnedRowPrefix + $0 }
                }
            }
        }

        rows += section(.branches) {
            // 没有本地分支时有一行占位文字，未出生或分离 HEAD 时有一行当前分支
            let placeholder: [String?] = local.isEmpty && !isFiltering ? [nil] : []
            let head: [String?] = headRowName == nil ? [] : ["HEAD"]
            let active = local.filter { !metadata(for: $0).isArchived }

            return placeholder + head + displayedRows(in: branchNodes(active, scope: "branches"))
        }

        rows += section(.archived) {
            let archived = local.filter { metadata(for: $0).isArchived }
            return displayedRows(in: branchNodes(archived, scope: "archived"))
        }

        return rows
    }

    /// Remotes 分组里的行：每个远端一行，展开的远端下面是它的远端分支；没有远端或远端分支时各有一行占位文字。
    private var remoteRows: [String?] {
        let remotes = session.history.snapshot?.remotes ?? []

        guard !remotes.isEmpty else {
            return [nil]
        }

        return remotes.flatMap { remote -> [String?] in
            let row = Self.remoteRowPrefix + remote.name

            guard isExpanded(remote.sidebarID).wrappedValue else {
                return [row]
            }

            let nodes = remoteBranchNodes(remote)
            let placeholder: [String?] = nodes.isEmpty && !isFiltering ? [nil] : []

            return [row] + placeholder + displayedRows(in: nodes)
        }
    }

    /// 一个分组的行：标题占一行，不可选中；分组收起时里面的行看不见。
    private func section(_ group: SidebarGroup, rows: () -> [String?]) -> [String?] {
        [nil] + (isExpanded(group).wrappedValue ? rows() : [])
    }

    /// 一组节点显示的行：文件夹本身占一行，不可选中；文件夹收起时里面的行看不见。
    private func displayedRows(in nodes: [SidebarRefNode]) -> [String?] {
        nodes.flatMap { node -> [String?] in
            if let reference = node.reference {
                return [reference.id]
            }

            let children = isExpanded(node.id).wrappedValue ? displayedRows(in: node.children) : []
            return [nil] + children
        }
    }
}
