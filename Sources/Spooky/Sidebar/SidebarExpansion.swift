import Foundation
import SpookyKit
import SwiftUI

// MARK: - SidebarExpansion

/// 侧边栏的展开状态：收起的分组与展开的远端、文件夹按仓库记在这台 Mac 的偏好里，换仓库、重新打开仓库或重启 App 后回到上次的样子；
/// 过滤时的固定展开与拖动中悬停的临时展开不记下。
///
/// 偏好不登记进 `DeveloperPreferences.dataKeys`，Reset User Defaults 后回到默认。
@MainActor
@Observable
final class SidebarExpansion {
    /// 分组的类型。
    typealias Group = RepositorySidebarView.SidebarGroup

    /// 偏好键：以仓库的 `displayPath`（本机仓库是路径，服务器仓库是 `<别名>:<路径>`）为键的字典。
    static let storageKey = "sidebarExpansion"

    /// 没有记录时收起的分组：只有 Tags。
    private static let defaultCollapsedGroups: Set<Group> = [.tags]

    /// 没有记录时展开的节点：只有名为 origin 的远端，文件夹都收起。
    private static let defaultExpandedNodes: Set<SidebarNodeID> = [.remote("origin")]

    /// 一条记录里收起的分组的键。
    private static let groupsKey = "collapsedGroups"

    /// 一条记录里展开的节点的键。
    private static let nodesKey = "expandedNodes"

    /// 收起的分组。
    private var collapsedGroups = defaultCollapsedGroups

    /// 展开的远端与文件夹。
    private var expandedNodes = defaultExpandedNodes

    /// 拖动中悬停临时展开的节点，拖动结束后收起。
    private var springOpened: Set<SidebarNodeID> = []

    /// 状态所属的仓库；记下时写在它的键下，没有仓库时不记。
    private var repository: RepositoryLocation? = nil

    /// 记录所在的偏好。
    private var defaults = UserDefaults.standard

    /// 换成一个仓库的状态：读出它的记录，没有记录时用默认；临时展开一并清掉。
    ///
    /// - Parameters:
    ///   - repository: 侧边栏显示的仓库；没有时用默认。
    ///   - defaults: 记录所在的偏好，测试使用独立的偏好域。
    func load(_ repository: RepositoryLocation?, defaults: UserDefaults) {
        self.repository = repository
        self.defaults = defaults
        springOpened = []

        let records = defaults.dictionary(forKey: Self.storageKey) as? [String: [String: [String]]]
        let record = repository.flatMap { records?[$0.displayPath] }

        collapsedGroups = record.map { Set(($0[Self.groupsKey] ?? []).compactMap(Group.init(rawValue:))) }
            ?? Self.defaultCollapsedGroups
        expandedNodes = record.map { Set(($0[Self.nodesKey] ?? []).map(SidebarNodeID.init(value:))) }
            ?? Self.defaultExpandedNodes
    }

    /// 分组的展开状态：过滤时固定展开，这时的改动不生效，清空过滤后回到记下的状态。
    ///
    /// - Parameters:
    ///   - group: 分组。
    ///   - filtering: 侧边栏正在过滤。
    func binding(for group: Group, filtering: Bool) -> Binding<Bool> {
        Binding(
            get: { filtering || !self.collapsedGroups.contains(group) },
            set: { expanded in
                guard !filtering else { return }

                if expanded {
                    self.collapsedGroups.remove(group)
                } else {
                    self.collapsedGroups.insert(group)
                }

                self.record()
            }
        )
    }

    /// 远端与文件夹的展开状态：过滤时固定展开，这时的改动不生效；收起时连同拖动中的临时展开一起收起。
    ///
    /// - Parameters:
    ///   - node: 远端或文件夹的节点。
    ///   - filtering: 侧边栏正在过滤。
    func binding(for node: SidebarNodeID, filtering: Bool) -> Binding<Bool> {
        Binding(
            get: { self.isExpanded(node, filtering: filtering) },
            set: { expanded in
                guard !filtering else { return }

                if expanded {
                    self.expandedNodes.insert(node)
                } else {
                    self.expandedNodes.remove(node)
                    self.springOpened.remove(node)
                }

                self.record()
            }
        )
    }

    /// 拖动中悬停展开用的状态：只改临时展开，不记下；读出的值与 `binding(for:filtering:)` 相同。
    ///
    /// - Parameters:
    ///   - node: 远端或文件夹的节点。
    ///   - filtering: 侧边栏正在过滤。
    func springBinding(for node: SidebarNodeID, filtering: Bool) -> Binding<Bool> {
        Binding(
            get: { self.isExpanded(node, filtering: filtering) },
            set: { expanded in
                if expanded {
                    self.springOpened.insert(node)
                } else {
                    self.springOpened.remove(node)
                }
            }
        )
    }

    /// 展开分组与节点并记下，让程序化选中或刚置顶的行可见；都已展开时不改记录。
    ///
    /// - Parameters:
    ///   - groups: 要展开的分组。
    ///   - nodes: 要展开的远端与文件夹。
    func expand(groups: some Sequence<Group>, nodes: some Sequence<SidebarNodeID>) {
        let collapsed = collapsedGroups.subtracting(groups)
        let expanded = expandedNodes.union(nodes)

        guard collapsed != collapsedGroups || expanded != expandedNodes else {
            return
        }

        collapsedGroups = collapsed
        expandedNodes = expanded
        record()
    }
}

// MARK: - Private

extension SidebarExpansion {
    /// 节点是否展开：过滤时固定展开，其余看记下的状态与拖动中的临时展开。
    private func isExpanded(_ node: SidebarNodeID, filtering: Bool) -> Bool {
        filtering || expandedNodes.contains(node) || springOpened.contains(node)
    }

    /// 把收起的分组与展开的节点写进当前仓库的记录，其它仓库的记录不变。
    private func record() {
        guard let repository else {
            return
        }

        var records = defaults.dictionary(forKey: Self.storageKey) ?? [:]

        records[repository.displayPath] = [
            Self.groupsKey: collapsedGroups.map(\.rawValue).sorted(),
            Self.nodesKey: expandedNodes.map(\.value).sorted(),
        ]

        defaults.set(records, forKey: Self.storageKey)
    }
}
