import SwiftUI

// MARK: - Reveal

extension RepositorySidebarView {
    /// 分离或未出生 HEAD 那一行的滚动身份。
    static let headRowID = SidebarNodeID(value: "HEAD")

    /// 展开选中的引用所在的分组、远端与各级文件夹，再滚动到其中最靠前的一行。
    ///
    /// 只按完整引用名找行，引用已不在树里时什么都不展开，也不选中同名的其它引用。
    ///
    /// - Parameter proxy: 侧边栏列表的滚动代理。
    func revealSelectedReferences(with proxy: ScrollViewProxy) {
        let references = session.history.selectedReferences
        var target: SidebarNodeID? = nil

        for location in referenceLocations where references.contains(location.reference) {
            collapsedGroups.remove(location.group)
            expandedNodes.formUnion(location.path.dropLast())
            target = target ?? location.path.last
        }

        guard let target else {
            return
        }

        // 刚展开的行在这次更新之后才进入列表，下一轮再滚动
        Task { @MainActor in
            proxy.scrollTo(target)
        }
    }
}

// MARK: - Private

extension RepositorySidebarView {
    /// 全部引用行的位置，按显示顺序：所在的分组、行的选择身份与从顶层到它的节点身份；
    /// 远端分支的路径以远端节点开头，分离或未出生 HEAD 的行排在 Branches 分组的最前面。
    private var referenceLocations: [(group: SidebarGroup, reference: String, path: [SidebarNodeID])] {
        let head: [(reference: String, path: [SidebarNodeID])] =
            headRowName == nil ? [] : [("HEAD", [Self.headRowID])]

        let trees: [(group: SidebarGroup, paths: [(reference: String, path: [SidebarNodeID])])] = [
            (.pinned, SidebarRefTree.paths(in: branchNodes(pinnedReferences, scope: "pinned"))),
            (.branches, head + SidebarRefTree.paths(in: branchNodes(activeReferences, scope: "branches"))),
            (.archived, SidebarRefTree.paths(in: branchNodes(archivedReferences, scope: "archived"))),
            (.tags, SidebarRefTree.paths(in: tagNodes)),
            (.remotes, remotePaths),
        ]

        return trees.flatMap { tree in
            tree.paths.map { (tree.group, $0.reference, $0.path) }
        }
    }

    /// 各远端下的远端分支行，路径以远端节点开头。
    private var remotePaths: [(reference: String, path: [SidebarNodeID])] {
        (session.history.snapshot?.remotes ?? []).flatMap { remote in
            SidebarRefTree.paths(in: remoteBranchNodes(remote)).map { entry in
                (entry.reference, [remote.sidebarID] + entry.path)
            }
        }
    }
}
