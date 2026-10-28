import SpookyKit
import SwiftUI

// MARK: - Pin and Archive

extension RepositorySidebarView {
    /// 置顶菜单项：一个分支时写出名字；多个分支时全部未置顶给 Pin、全部已置顶给 Unpin，混合时不给。
    @ViewBuilder
    func pinMenuItems(_ branches: [RepositoryReference]) -> some View {
        let pinned = branches.map { metadata(for: $0).isPinned }

        if !pinned.contains(true) {
            Button(flagTitle(branches, single: "branch.pinNamed", multiple: "branch.pinMultiple")) {
                setPinned(true, branches)
            }
            .disabled(!session.canSetPinned(branches))
        } else if !pinned.contains(false) {
            Button(flagTitle(branches, single: "branch.unpinNamed", multiple: "branch.unpinMultiple")) {
                setPinned(false, branches)
            }
            .disabled(!session.canSetPinned(branches))
        }
    }

    /// 归档菜单项：规则与置顶相同；一个分支时其下还有 “自动归档时跳过” 勾选项。
    @ViewBuilder
    func archiveMenuItems(_ branches: [RepositoryReference]) -> some View {
        let archived = branches.map { metadata(for: $0).isArchived }

        if !archived.contains(true) {
            Button(flagTitle(branches, single: "branch.archiveNamed", multiple: "branch.archiveMultiple")) {
                session.setArchived(true, branches: branches)
            }
            .disabled(!session.canSetArchived(branches))
        } else if !archived.contains(false) {
            Button(flagTitle(branches, single: "branch.unarchiveNamed", multiple: "branch.unarchiveMultiple")) {
                session.setArchived(false, branches: branches)
            }
            .disabled(!session.canSetArchived(branches))
        }

        if branches.count == 1, let branch = branches.first {
            BranchArchiveOptions(session: session, branch: branch, metadata: metadata(for: branch))
        }
    }

    /// 置顶后展开 Pinned 分组，新置顶的分支立刻可见。
    private func setPinned(_ pinned: Bool, _ branches: [RepositoryReference]) {
        if pinned {
            collapsedGroups.remove(.pinned)
        }

        session.setPinned(pinned, branches: branches)
    }

    /// 一个分支的标题带名字，多个分支的标题带个数。
    private func flagTitle(_ branches: [RepositoryReference], single: String, multiple: String) -> String {
        guard branches.count > 1 else {
            return AppLocalization.text(single, branches.first?.name ?? "")
        }

        return AppLocalization.text(multiple, branches.count)
    }
}
