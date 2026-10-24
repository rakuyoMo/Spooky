import SwiftUI

// MARK: - SidebarRefTreeView

/// 侧边栏里一组引用的树：文件夹是可展开、不可选中的行，引用行由调用方生成。
struct SidebarRefTreeView<Row: View>: View {
    /// 这一级的节点。
    let nodes: [SidebarRefNode]

    /// 文件夹的展开状态；过滤时由调用方固定为展开。
    let isExpanded: (SidebarNodeID) -> Binding<Bool>

    /// 引用节点的行。
    @ViewBuilder
    let row: (SidebarRefNode) -> Row

    /// 文件夹递归展开子节点。
    var body: some View {
        ForEach(nodes) { node in
            if node.isFolder {
                DisclosureGroup(isExpanded: isExpanded(node.id)) {
                    Self(nodes: node.children, isExpanded: isExpanded, row: row)
                } label: {
                    Label(node.name, systemImage: "folder")
                        .lineLimit(1)
                        .selectionDisabled()
                }
            } else {
                row(node)
            }
        }
    }
}
