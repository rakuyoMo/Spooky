import SpookyKit
import SwiftUI

// MARK: - CompactNavigationState

/// 极窄版式视图导航的状态，由仓库窗口持有。
@MainActor
@Observable
final class CompactNavigationState {
    /// 侧边栏是否盖在主视图上。
    var showsSidebar = false
}

// MARK: - CompactNavigationBar

/// 极窄版式顶部的视图导航：开头的按钮显示或收起侧边栏，后面是 Working Copy、History 与 Stashes。
struct CompactNavigationBar: View {
    /// 导航里的一个视图。
    private struct Entry {
        /// 点按后显示的视图。
        let view: RepositoryView

        /// 标题的资源键。
        let title: String

        /// 图标的符号名。
        let symbol: String
    }

    /// 导航里的三个视图，与侧边栏 Workspace 分组开头的三行相同。
    private static let entries = [
        Entry(view: .workingCopy, title: "workspace.title", symbol: "folder"),
        Entry(view: .history, title: "history.title", symbol: "clock"),
        Entry(view: .stashes, title: "stash.title", symbol: "tray.full"),
    ]

    /// 当前窗口会话。
    let session: RepositorySession

    /// 侧边栏是否显示着。
    let state: CompactNavigationState

    /// 显示或收起侧边栏：分支、标签、远端与其余视图都从侧边栏进入。
    let toggleSidebar: () -> Void

    /// 切换到三个视图之一。
    let show: (RepositoryView) -> Void

    /// Stashes 入口显示储藏个数，与侧边栏共用同一项视图设置。
    @AppStorage(SidebarPreferences.showStashCountKey)
    private var showsStashCount = SidebarPreferences.defaultFlag(SidebarPreferences.showStashCountKey)

    /// 三个视图里当前所在的一个；文件历史、文件原文与 Blame 算在 History 里，其余视图不在导航里。
    private var currentView: RepositoryView? {
        switch session.activeView {
        case .workingCopy:
            .workingCopy

        case .history, .fileHistory, .fileContent:
            .history

        case .stashes:
            .stashes

        default:
            nil
        }
    }

    /// 侧边栏按钮与三个视图靠左排成一行，各取文字的宽度，排不下时截短文字。
    var body: some View {
        HStack(spacing: 4) {
            sidebarButton

            ForEach(Self.entries, id: \.view) { entry in
                entryButton(entry, isSelected: entry.view == currentView)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Private

extension CompactNavigationBar {
    /// 显示或收起侧边栏的按钮；侧边栏显示着时垫一块选中底色。
    private var sidebarButton: some View {
        Button(action: toggleSidebar) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14))
                .frame(width: 30, height: 28)
                .background(
                    state.showsSidebar ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(AppLocalization.text("sidebar.menu"))
        .accessibilityLabel(AppLocalization.text("sidebar.menu"))
        .accessibilityAddTraits(state.showsSidebar ? .isSelected : [])
    }

    /// 一个视图的按钮：图标、标题与末尾的标记；所在的视图垫一块选中底色。
    private func entryButton(_ entry: Entry, isSelected: Bool) -> some View {
        Button {
            show(entry.view)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: entry.symbol)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Text(AppLocalization.text(entry.title))
                    .lineLimit(1)
                    .truncationMode(.tail)

                accessory(of: entry)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 标题后面的标记：Working Copy 是进度、进行中操作的图标或改动文件数，Stashes 是视图设置打开时的储藏个数。
    @ViewBuilder
    private func accessory(of entry: Entry) -> some View {
        switch entry.view {
        case .workingCopy:
            SidebarWorkingCopyAccessory(session: session)

        case .stashes where showsStashCount && session.stashes.isLoaded:
            SidebarCountBadge(count: session.stashes.entries.count)
                .accessibilityLabel(AppLocalization.text("stash.count", session.stashes.entries.count))

        default:
            EmptyView()
        }
    }
}
