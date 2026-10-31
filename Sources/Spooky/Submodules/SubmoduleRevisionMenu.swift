import SpookyKit
import SwiftUI

// MARK: - SubmoduleRevisionMenu

/// 子模块右键菜单里的 Checkout Revision 子菜单：分离 HEAD 时最上面是检出的提交，再是 Branches 与 Tags 两组；
/// 当前版本打勾且不可选，选中别的版本即在子模块里检出它。
struct SubmoduleRevisionMenu: View {
    /// 子菜单里的一项。
    enum Item: Equatable {
        /// 分离 HEAD 且不在任何标签上时检出的提交，打勾且不可选。
        case detached(String)

        /// 分隔线。
        case separator

        /// 不可选的 Branches 组名。
        case branchesHeader

        /// 不可选的 Tags 组名。
        case tagsHeader

        /// 一个分支或标签；当前版本打勾且不可选。
        case revision(SubmoduleRevision)

        /// 一项都没有时不可选的 No revisions。
        case empty
    }

    /// 所在窗口的会话。
    let session: RepositorySession

    /// 子模块。
    let submodule: Submodule

    /// 按 `items(revisions:checkedOut:)` 的顺序列出各项。
    var body: some View {
        let items = Self.items(revisions: session.submodules.revisions[submodule.path], checkedOut: submodule.checkedOut)

        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            view(for: item)
        }
    }

    /// 子菜单的各项：分离 HEAD 的提交、Branches 组、Tags 组依次排列，没有内容的组整组不列；前面有项目时才加分隔线。
    ///
    /// - Parameters:
    ///   - revisions: 子模块里的分支与标签，分支在前；读不到时为 nil。
    ///   - checkedOut: 子模块里检出的提交。
    static func items(revisions: [SubmoduleRevision]?, checkedOut: String?) -> [Item] {
        var items: [Item] = []

        // 读到了版本，却没有停着的分支、也没有标签在检出的提交上，就是分离 HEAD
        if let revisions, let checkedOut, !revisions.contains(where: \.isCurrent) {
            items.append(.detached(checkedOut))
        }

        let all = revisions ?? []
        let groups: [(header: Item, revisions: [SubmoduleRevision])] = [
            (.branchesHeader, all.filter { !$0.isTag }),
            (.tagsHeader, all.filter(\.isTag)),
        ]

        for group in groups where !group.revisions.isEmpty {
            if !items.isEmpty {
                items.append(.separator)
            }

            items.append(group.header)
            items += group.revisions.map(Item.revision)
        }

        return items.isEmpty ? [.empty] : items
    }
}

// MARK: - Private

extension SubmoduleRevisionMenu {
    /// 一项对应的菜单项。
    @ViewBuilder
    private func view(for item: Item) -> some View {
        switch item {
        case .detached(let commit):
            Toggle(String(commit.prefix(8)), isOn: .constant(true))
                .disabled(true)

        case .separator:
            Divider()

        case .branchesHeader:
            Text(AppLocalization.text("branch.group"))

        case .tagsHeader:
            Text(AppLocalization.text("sidebar.tags"))

        case .revision(let revision):
            Toggle(revision.name, isOn: checkoutBinding(revision))
                .disabled(revision.isCurrent)

        case .empty:
            Text(AppLocalization.text("submodule.noRevisions"))
        }
    }

    /// 版本项的勾选：当前版本打勾，选中别的版本即检出它。
    private func checkoutBinding(_ revision: SubmoduleRevision) -> Binding<Bool> {
        Binding(
            get: { revision.isCurrent },
            set: { checked in
                if checked { session.checkoutSubmoduleRevision(revision, in: submodule) }
            }
        )
    }
}
