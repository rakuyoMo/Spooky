import SwiftUI

// MARK: - SidebarRefTreeView

/// 侧边栏里一组引用的树：文件夹是可展开、不可选中的行，引用行与文件夹行由调用方生成。
struct SidebarRefTreeView<Row: View, Folder: View>: View {
    /// 这一级的节点。
    let nodes: [SidebarRefNode]

    /// 文件夹的展开状态；过滤时由调用方固定为展开。
    let isExpanded: (SidebarNodeID) -> Binding<Bool>

    /// 引用节点的行。
    @ViewBuilder
    let row: (SidebarRefNode) -> Row

    /// 文件夹节点的标签，调用方可以给它加上拖放落点。
    @ViewBuilder
    let folder: (SidebarRefNode) -> Folder

    /// 文件夹递归展开子节点。
    var body: some View {
        ForEach(nodes) { node in
            if node.isFolder {
                DisclosureGroup(isExpanded: isExpanded(node.id)) {
                    Self(nodes: node.children, isExpanded: isExpanded, row: row, folder: folder)
                } label: {
                    folder(node)
                }
            } else {
                row(node)
            }
        }
    }
}

extension SidebarRefTreeView where Folder == SidebarFolderLabel {
    /// 文件夹只显示图标与名字的树。
    init(
        nodes: [SidebarRefNode],
        isExpanded: @escaping (SidebarNodeID) -> Binding<Bool>,
        @ViewBuilder row: @escaping (SidebarRefNode) -> Row
    ) {
        self.init(nodes: nodes, isExpanded: isExpanded, row: row) { SidebarFolderLabel(name: $0.name) }
    }
}

// MARK: - SidebarFolderLabel

/// 按 “/” 折叠出的文件夹行：文件夹图标与名字，不可选中。
struct SidebarFolderLabel: View {
    /// 文件夹这一级的名字。
    let name: String

    /// 名字过长时截断。
    var body: some View {
        Label(name, systemImage: "folder")
            .lineLimit(1)
            .selectionDisabled()
    }
}
