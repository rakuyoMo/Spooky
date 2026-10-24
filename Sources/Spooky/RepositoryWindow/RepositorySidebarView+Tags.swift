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
            } folder: { node in
                folderLabel(node, destination: .tagFolder(node.path))
            }
        } header: {
            // 提交或本地分支拖到标题上新建标签
            groupHeader("sidebar.tags", destination: .tags)
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

    /// 标签行：单击显示它的历史，可与分支一起多选；双击检出成分离 HEAD；可拖到 Branches 标题新建分支；右键的 Show Signature 在行上弹出标签的签名。
    private func tagRow(_ ref: RepositoryReference, name: String) -> some View {
        Label(name, systemImage: "tag")
            .lineLimit(1)
            .help(SidebarTooltip.tag(ref, host: session.repository?.host))
            .tag(ref.id)
            .onTapGesture(count: 2) {
                guard session.canCheckoutRevision else { return }

                session.checkout(revision: ref.id)
            }
            .onDrag { dragProvider(kind: .tag, reference: ref.id) }
            .contextMenu { tagMenu(ref) }
            .popover(isPresented: signaturePresented(ref), arrowEdge: .top) {
                TagSignaturePopover(reference: ref.id, runner: session.runner)
            }
    }

    /// 标签的签名弹窗是否打开；同一时间只有右键选了 Show Signature 的那个标签打开。
    private func signaturePresented(_ ref: RepositoryReference) -> Binding<Bool> {
        Binding(
            get: { signatureTag == ref.id },
            set: { presented in
                if !presented, signatureTag == ref.id {
                    signatureTag = nil
                }
            }
        )
    }

    /// 标签菜单：检出；发布与推送；新建分支与删除；导出、比较与签名；在历史中显示与复制名称。
    ///
    /// 点在多选里时只作用于整个选区：全是标签时只有删除所选标签。
    @ViewBuilder
    private func tagMenu(_ ref: RepositoryReference) -> some View {
        let selected = session.history.selectedReferences

        if selected.count <= 1 || !selected.contains(ref.id) {
            Button(AppLocalization.text("tag.checkoutNamed", ref.name)) { session.requestCheckout(ref.id) }
                .disabled(!session.canCheckoutRevision)

            Divider()

            TagManagementMenu(
                session: session,
                reference: ref,
                pushTo: { session.requestSyncDialog(.pushRevision, preselecting: $0.name) },
                createBranch: { request(RepositoryActionRequest(kind: .create, reference: $0.id)) }
            )

            Divider()

            Button(AppLocalization.text("export.menuFrom", ref.name)) {
                session.onRevisionRequest?(.export(revision: ref.name, paths: [], archive: false))
            }

            Button(AppLocalization.text("tag.compareMenu", ref.name)) {
                session.onRevisionRequest?(.compare(base: ref.name))
            }

            Button(AppLocalization.text("signature.show")) { signatureTag = ref.id }
                .disabled(session.runner == nil)

            Divider()

            Button(AppLocalization.text("tag.reveal")) { session.revealInHistory(ref) }
            Button(AppLocalization.text("tag.copyName")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ref.name, forType: .string)
            }
        } else if selected.allSatisfy({ $0.hasPrefix("refs/tags/") }) {
            let names = session.tags.filter { selected.contains($0.id) }.map(\.name)

            Button(AppLocalization.text("tag.deleteMenu.multiple", names.count)) {
                session.requestReference(.deleteTags(names))
            }
            .disabled(!session.canWrite)
        }
    }
}
