import AppKit
import SpookyKit
import SwiftUI

// MARK: - Branch Menu

extension RepositorySidebarView {
    /// 分支的右键菜单：点在侧边栏当前的多选里时作用于整个选区，否则按本地分支与远端分支各一组。
    ///
    /// 各项都作用于被点击的分支或所选的这组引用，不借用 HEAD 或旧的选区。
    @ViewBuilder
    func branchMenu(_ ref: RepositoryReference) -> some View {
        if let selected = selectedReferences(including: ref) {
            multipleReferenceMenu(selected)
        } else {
            BranchMenu(session: session, references: [ref], request: request, willSetPinned: expandPinDestinations)
        }
    }

    /// 右键的引用在侧边栏当前的多选里时，按版本候选的顺序返回选中的全部引用；否则为 nil，菜单只作用于右键的这一项。
    ///
    /// 只看侧边栏当前的选中：选中移到 Working Copy 等行后，之前多选过的引用不再算作选区。
    func selectedReferences(including ref: RepositoryReference) -> [RepositoryReference]? {
        let selected = selectedItems

        guard selected.count > 1, selected.contains(ref.id) else {
            return nil
        }

        let references = (session.history.branches + session.tags).filter { selected.contains($0.id) }

        return ReferenceOrder.candidates(references, in: session.history.snapshot)
    }

    /// 多选引用的菜单：全是本地分支时置顶、归档与删除，全是标签或全是远端分支时只有删除；
    /// 正好选中两项时最后是比较两者，混选时只有这一项。
    @ViewBuilder
    func multipleReferenceMenu(_ selected: [RepositoryReference]) -> some View {
        // 选中的都是同一种引用时前面才有一组
        let isUniform = [\RepositoryReference.isLocal, \.isTag, \.isRemote].contains { kind in
            selected.allSatisfy { $0[keyPath: kind] }
        }

        if selected.allSatisfy(\.isLocal) {
            BranchMenu(session: session, references: selected, request: request, willSetPinned: expandPinDestinations)
        } else if selected.allSatisfy(\.isTag) {
            Button(AppLocalization.text("tag.deleteMenu.multiple", selected.count)) {
                session.requestReference(.deleteTags(selected.map(\.name)))
            }
            .disabled(!session.canWrite)
        } else if selected.allSatisfy(\.isRemote) {
            Button(AppLocalization.text("branch.deleteRemoteMenu.multiple", selected.count)) {
                session.requestReference(.deleteRemoteBranches(selected))
            }
            .disabled(!session.canDeleteRemoteBranches(selected))
        }

        if selected.count == 2 {
            if isUniform {
                Divider()
            }

            // 两项按版本候选的顺序，先者作为比较的基准
            Button(AppLocalization.text("reference.compareMenuPair", selected[0].name, selected[1].name)) {
                session.compare(
                    base: RevisionComparisonState.Side(id: selected[0].objectID, title: selected[0].name),
                    target: RevisionComparisonState.Side(id: selected[1].objectID, title: selected[1].name)
                )
            }
        }
    }
}
