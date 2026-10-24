import AppKit
import SpookyKit
import SwiftUI

// MARK: - Tags

extension RepositorySidebarView {
    /// Tags 分组：默认收起；排序与数量照视图设置，过滤时列出全部匹配的标签。
    var tags: some View {
        Section(isExpanded: isExpanded(.tags)) {
            SidebarRefTreeView(nodes: tagNodes, isExpanded: isExpanded) { node in
                if let ref = node.reference {
                    tagRow(ref, name: node.name)
                }
            }
        } header: {
            Text(AppLocalization.text("sidebar.tags"))
        }
    }

    /// 标签的树：没有过滤时只留最新的若干个，选中的总会留下，再按名称排序。
    private var tagNodes: [SidebarRefNode] {
        guard let snapshot = session.history.snapshot else {
            return []
        }

        let limit =
            SidebarPreferences.isValid(newestTags, for: SidebarPreferences.newestTagsKey)
                ? newestTags
                : 0

        let entries = SidebarRefTree.tagEntries(
            in: snapshot,
            filter: filterText,
            limit: limit,
            including: session.history.selectedReferences,
            order: SidebarPreferences.TagOrder(rawValue: tagOrder) ?? .nameAscending
        )

        return SidebarRefTree.nodes(for: entries, grouped: groupsRefs, foldersFirst: groupedRefsOnTop, scope: "tags")
    }

    /// 标签行：单击显示它的历史，可与分支一起多选；双击检出成分离 HEAD；可拖到 Branches 标题新建分支。
    private func tagRow(_ ref: RepositoryReference, name: String) -> some View {
        Label(name, systemImage: "tag")
            .lineLimit(1)
            .help(SidebarTooltip.tag(ref, host: session.repository?.host))
            .tag(ref.id)
            .onTapGesture(count: 2) { session.checkoutTag(ref) }
            .onDrag { dragProvider(kind: .tag, reference: ref.id) }
            .contextMenu { tagMenu(ref) }
    }

    /// 标签菜单：检出、从它新建分支、在历史中显示与复制名称；点在多选里时只作用于整个选区。
    @ViewBuilder
    private func tagMenu(_ ref: RepositoryReference) -> some View {
        let selected = session.history.selectedReferences

        if selected.count <= 1 || !selected.contains(ref.id) {
            Button(AppLocalization.text("tag.checkoutNamed", ref.name)) { confirmCheckout(ref) }
                .disabled(!session.canCheckoutTag(ref))

            Divider()

            Button(AppLocalization.text("tag.createBranch", ref.name)) {
                request(RepositoryActionRequest(kind: .create, reference: ref.id))
            }
            .disabled(!session.canCreateBranchFromReference)

            Divider()

            Button(AppLocalization.text("tag.reveal")) { session.revealInHistory(ref) }
            Button(AppLocalization.text("tag.copyName")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ref.name, forType: .string)
            }
        }
    }

    /// 菜单里的检出先说明 HEAD 会脱离分支，确认后与双击一样检出。
    private func confirmCheckout(_ ref: RepositoryReference) {
        let repository = session.repository

        session.onConfirm?(
            AppLocalization.text("tag.checkout"),
            AppLocalization.text("tag.checkout.confirm", ref.name, repository?.displayPath ?? ""),
            {
                guard session.repository == repository else { return }
                session.checkoutTag(ref)
            },
            nil
        )
    }
}
