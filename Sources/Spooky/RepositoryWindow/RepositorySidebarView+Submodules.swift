import SpookyKit
import SwiftUI

// MARK: - Submodules

extension RepositorySidebarView {
    /// 子模块行的身份前缀：选中子模块时主视图显示它的状态与配置。
    static let submoduleRowPrefix = "submodule:"

    /// Submodules 分组：按路径排列的子模块，过滤时按名称匹配；没有子模块时只有标题。
    var submoduleGroup: some View {
        Section(isExpanded: isExpanded(.submodules)) {
            ForEach(session.submodules.items.filter { !isFiltering || SidebarRefTree.matches($0.name, filter: filterText) }) {
                submoduleRow($0)
            }
        } header: {
            Text(AppLocalization.text("submodule.group"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contextMenu {
                    Button(AppLocalization.text("submodule.add.menu")) { session.requestSubmodule(.add) }
                        .disabled(!session.canWrite)
                }
        }
    }

    /// 子模块行：单击显示详情，双击当仓库打开，右键是子模块的操作。
    private func submoduleRow(_ submodule: Submodule) -> some View {
        SubmoduleSidebarRow(submodule: submodule, summary: session.submodules.summaries[submodule.path])
            .tag(Self.submoduleRowPrefix + submodule.path)
            .onTapGesture(count: 2) { session.open(submodule) }
            .contextMenu { SubmoduleMenu(session: session, submodule: submodule) }
    }
}

// MARK: - SubmoduleSidebarRow

/// 子模块行：图标、名称，以及本地改动数与相对指针的领先、落后徽标；没有检出时变淡，配置不完整或地址需要同步时换成错误图标。
private struct SubmoduleSidebarRow: View {
    /// 子模块。
    let submodule: Submodule

    /// 工作区概况；没有检出或读不到时为 nil。
    let summary: SubmoduleSummary?

    /// 名称在左、徽标在右。
    var body: some View {
        HStack(spacing: 4) {
            Label {
                Text(submodule.name)
                    .lineLimit(1)
            } icon: {
                Image(systemName: hasProblem ? "exclamationmark.triangle.fill" : "shippingbox")
                    .foregroundStyle(hasProblem ? Color.yellow : Color.secondary)
            }
            .opacity(submodule.state == .uninitialized || !submodule.isValid ? 0.5 : 1)

            Spacer(minLength: 4)

            if let changes = summary?.changes, changes > 0 {
                Text(changes.formatted())
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppPalette.color("sidebarBadgeBackgroundColor"), in: Capsule())
                    .accessibilityLabel(AppLocalization.text("workspace.changed", changes))
            }

            if !segments.isEmpty {
                SidebarBadge(segments: segments)
            }
        }
        .help(tooltip)
    }

    /// 配置不完整或地址需要同步。
    private var hasProblem: Bool {
        !submodule.isValid || submodule.needsSynchronizing
    }

    /// 检出的提交相对指针领先、落后的提交数。
    private var segments: [SidebarBadgeSegment] {
        guard let summary, submodule.state == .updated else {
            return []
        }

        return (summary.ahead > 0 ? [.ahead(summary.ahead)] : []) + (summary.behind > 0 ? [.behind(summary.behind)] : [])
    }

    /// 悬停提示：子模块名与地址。
    private var tooltip: String {
        let name = AppLocalization.text("submodule.tooltip", submodule.name)

        guard let url = submodule.url else {
            return name
        }

        return name + "\n" + AppLocalization.text("submodule.tooltip.url", url)
    }
}

// MARK: - SubmoduleMenu

/// 子模块的右键菜单：打开、检出版本、获取与更新（按住 ⌥ 跳过对话框）、初始化、同步、移动、改名与删除。
struct SubmoduleMenu: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 子模块。
    let submodule: Submodule

    /// 分三组排列，组间以分隔线隔开。
    var body: some View {
        let name = submodule.name

        Button(AppLocalization.text("submodule.open", name)) { session.open(submodule) }
            .disabled(!submodule.isPopulated)

        Divider()

        Menu(AppLocalization.text("submodule.checkoutRevision")) {
            revisionItems
        }
        .disabled(!session.canCheckoutRevision(in: submodule))

        Divider()

        Button(AppLocalization.text("submodule.fetch.menu", name)) { session.requestSubmodule(.fetch(submodule)) }
            .disabled(!session.canFetch(submodule))
            .quickAlternate(AppLocalization.text("submodule.quickFetch", name), enabled: session.canFetch(submodule)) {
                session.fetchSubmodules(
                    [submodule],
                    prunes: UserDefaults.standard.bool(forKey: SubmodulePreferences.fetchPrune)
                )
            }

        Button(AppLocalization.text("submodule.update.menu", name)) { session.requestSubmodule(.update(submodule)) }
            .disabled(!session.canModify(submodule))
            .quickAlternate(AppLocalization.text("submodule.quickUpdate", name), enabled: session.canModify(submodule)) {
                session.updateSubmodules(
                    [submodule],
                    recursive: UserDefaults.standard.bool(forKey: SubmodulePreferences.updateRecursive)
                )
            }

        Button(AppLocalization.text("submodule.initialize.menu", name)) { session.requestSubmodule(.initialize(submodule)) }
            .disabled(!session.canModify(submodule))

        Button(AppLocalization.text("submodule.synchronize.menu", name)) {
            session.requestSubmodule(.synchronize(submodule))
        }
        .disabled(!session.canSynchronize(submodule))

        Divider()

        Button(AppLocalization.text("submodule.move.menu", name)) { session.requestSubmodule(.move(submodule)) }
            .disabled(!session.canModify(submodule))

        Button(AppLocalization.text("submodule.rename.menu", name)) { session.requestSubmodule(.rename(submodule)) }
            .disabled(!session.canModify(submodule))

        Button(AppLocalization.text("submodule.delete.menu", name)) { session.requestSubmodule(.delete(submodule)) }
            .disabled(!session.canWrite)
    }

    /// Checkout Revision 子菜单：分支在前、标签在后，当前分支打勾且不可选。
    @ViewBuilder
    private var revisionItems: some View {
        let revisions = session.submodules.revisions[submodule.path] ?? []
        let branches = revisions.filter { !$0.isTag }
        let tags = revisions.filter(\.isTag)

        ForEach(branches) { revision in
            Toggle(revision.name, isOn: checkoutBinding(revision))
                .disabled(revision.isCurrent)
        }

        if !branches.isEmpty, !tags.isEmpty {
            Divider()
        }

        ForEach(tags) { revision in
            Button(revision.name) { session.checkoutSubmoduleRevision(revision, in: submodule) }
        }
    }

    /// 分支项的勾选：当前分支打勾，选中别的分支即检出它。
    private func checkoutBinding(_ revision: SubmoduleRevision) -> Binding<Bool> {
        Binding(
            get: { revision.isCurrent },
            set: { checked in
                if checked { session.checkoutSubmoduleRevision(revision, in: submodule) }
            }
        )
    }
}
