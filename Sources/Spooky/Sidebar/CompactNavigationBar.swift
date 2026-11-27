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

/// 极窄版式顶部的视图导航：开头的按钮显示或收起侧边栏，后面是侧边栏 Workspace 分组里的各个视图。
///
/// 各视图排不下时横向滚动，所在视图的一项总在可见范围里。
struct CompactNavigationBar: View {
    /// 导航里的一个视图。
    private struct Entry {
        /// 点按后显示的视图。
        let view: RepositoryView

        /// 标题。
        let title: String

        /// 图标的名字：系统符号或自绘的图形，见 `AppSymbol`。
        let symbol: String
    }

    /// 当前窗口会话。
    let session: RepositorySession

    /// 侧边栏是否显示着。
    let state: CompactNavigationState

    /// 显示或收起侧边栏：分支、标签、远端与其余视图都从侧边栏进入。
    let toggleSidebar: () -> Void

    /// 切换到导航里的一个视图。
    let show: (RepositoryView) -> Void

    /// Stashes 入口显示储藏个数，与侧边栏共用同一项视图设置。
    @AppStorage(SidebarPreferences.showStashCountKey)
    private var showsStashCount = SidebarPreferences.defaultFlag(SidebarPreferences.showStashCountKey)

    /// 显示 Reflog 入口，与侧边栏共用同一项视图设置。
    @AppStorage(SidebarPreferences.showReflogKey)
    private var showsReflog = SidebarPreferences.defaultFlag(SidebarPreferences.showReflogKey)

    /// 导航里的视图，与侧边栏 Workspace 分组的行相同。
    private var entries: [Entry] {
        let entries = [
            Entry(view: .workingCopy, title: AppLocalization.text("workspace.title"), symbol: "folder"),
            Entry(view: .history, title: AppLocalization.text("history.title"), symbol: "clock"),
            Entry(view: .stashes, title: AppLocalization.text("stash.title"), symbol: "tray.full"),

            // 选中远端对应 GitLab 时叫 Merge Requests
            Entry(view: .pullRequests, title: session.pullRequestText("title"), symbol: AppSymbol.pullRequest),
            Entry(
                view: .branchesReview,
                title: AppLocalization.text("review.title"),
                symbol: "arrow.left.arrow.right.circle"
            ),
            Entry(view: .reflog, title: AppLocalization.text("reflog.title"), symbol: "clock.arrow.circlepath"),
            Entry(view: .settings, title: AppLocalization.text("repositorySettings.title"), symbol: "gearshape"),
        ]

        // 视图设置打开 Show Reflog 时才有 Reflog
        return showsReflog ? entries : entries.filter { $0.view != .reflog }
    }

    /// 导航里当前所在的一项；文件历史、文件原文与 Blame 算在 History 里，其余视图不在导航里。
    private var currentView: RepositoryView? {
        switch session.activeView {
        case .history, .fileHistory, .fileContent:
            .history

        case .workingCopy, .stashes, .pullRequests, .branchesReview, .reflog, .settings:
            session.activeView

        default:
            nil
        }
    }

    /// 侧边栏按钮固定在开头，各视图在它后面的滚动区里靠左排成一行，各取标题的宽度。
    var body: some View {
        HStack(spacing: 4) {
            sidebarButton

            // 换了所在的视图、刚出现或宽度变了时，把所在视图的一项滚进可见范围，只滚到完整露出为止；换视图时带动画
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(entries, id: \.view) { entry in
                            entryButton(entry, isSelected: entry.view == currentView)
                        }
                    }
                    .padding(.trailing, 8)
                    .frame(maxHeight: .infinity)
                }
                .scrollIndicators(.never)
                .onChange(of: currentView) { _, view in
                    guard let view else {
                        return
                    }

                    withAnimation {
                        proxy.scrollTo(view)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { _ in
                    guard let currentView else {
                        return
                    }

                    proxy.scrollTo(currentView)
                }
            }
        }
        .padding(.leading, 8)
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
                icon(of: entry)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Text(entry.title)
                    .lineLimit(1)

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

    /// 标题前面的图标；Working Copy 的图标在加载时换成进度。
    @ViewBuilder
    private func icon(of entry: Entry) -> some View {
        let image = AppSymbolImage(name: entry.symbol)

        if entry.view == .workingCopy {
            image.modifier(SidebarWorkingCopyProgress(session: session))
        } else {
            image
        }
    }

    /// 标题后面的标记：Working Copy 是进行中操作的图标或改动文件数，Stashes 是视图设置打开时的储藏个数。
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
