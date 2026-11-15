import SpookyKit
import SwiftUI

// MARK: - Pin

extension RepositorySidebarView {
    /// 置顶后分支移到 Pinned 分组，取消置顶后回到 Branches 或 Archived Branches；置顶前展开它们要去的分组，分支立刻可见。
    func expandPinDestinations(_ pinned: Bool, _ branches: [RepositoryReference]) {
        let destinations: [SidebarGroup] =
            pinned
                ? [.pinned]
                : branches.map { metadata(for: $0).isArchived ? .archived : .branches }

        collapsedGroups.subtract(destinations)
    }
}
