import AppKit
import SpookyKit
import SwiftUI

// MARK: - BranchesReviewListView

/// 分支整理的列表：40 pt 表头是基准分支、筛选与视图设置，下面每个本地分支一行，可以多选。
struct BranchesReviewListView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 新建分支的对话框由窗口呈现。
    let request: (RepositoryActionRequest) -> Void

    /// 筛选项，与表头的筛选菜单同一个偏好。
    @AppStorage(BranchesReviewState.filterKey)
    private var filter = BranchesReviewFilter.all.rawValue

    #warning(
        "TODO: 排序默认按名称升序是选定的；核实方式：在全新的偏好里打开分支整理的视图设置菜单看勾选项；影响首次打开时列表的顺序"
    )

    /// 排序属性。
    @AppStorage(BranchesReviewState.sortKey)
    private var sort = BranchesReviewSort.name.rawValue

    /// 是否升序。
    @AppStorage(BranchesReviewState.ascendingKey)
    private var ascending = true

    /// 陈旧阈值，与侧边栏视图设置共用。
    @AppStorage(SidebarPreferences.staleIntervalKey)
    private var staleInterval = SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)

    /// 表头、比较失败的说明与列表。
    var body: some View {
        let state = session.branchesReview
        let items = state.items(
            conditions: session.history.conditions,
            search: session.searchText,
            order: BranchesReviewOrder(
                filter: BranchesReviewFilter(rawValue: filter) ?? .all,
                sort: BranchesReviewSort(rawValue: sort) ?? .name,
                ascending: ascending
            ),
            staleMonths: SidebarPreferences.isValid(staleInterval, for: SidebarPreferences.staleIntervalKey)
                ? staleInterval
                : SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)
        )

        VStack(spacing: 0) {
            ConnectionStatusView(session: session)

            BranchesReviewHeader(session: session)
            Divider()

            if let failure = state.failure {
                FailureDetailsView(failure: failure)
                    .padding(12)
            }

            list(items)
        }
        .frame(minWidth: 300)
        .task(id: snapshotKey) {
            state.update(
                snapshot: session.history.snapshot,
                head: session.status?.branch.head,
                runner: session.runner
            )
        }
    }

    /// 引用快照与当前分支一变就重新比较。
    private var snapshotKey: [String] {
        (session.history.snapshot?.references.filter(\.isLocal).map { $0.id + $0.objectID } ?? [])
            + [session.status?.branch.head ?? ""]
    }

    /// 没有分支时显示空状态，否则显示可多选的列表。
    @ViewBuilder
    private func list(_ items: [BranchesReviewItem]) -> some View {
        if items.isEmpty {
            EmptyStateView(
                title: AppLocalization.text("review.empty"),
                message: "",
                symbol: "arrow.triangle.branch"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: Bindable(session.branchesReview).selectedIDs) {
                ForEach(items) { item in
                    BranchesReviewRow(item: item, base: session.branchesReview.base?.name ?? "")
                        .tag(item.id)
                        .contextMenu {
                            BranchesReviewMenu(session: session, item: item, items: items, request: request)
                        }
                }
            }
            .listStyle(.inset)
        }
    }
}

// MARK: - BranchesReviewHeader

/// 列表表头：左侧选择基准分支，右侧是筛选与视图设置。
private struct BranchesReviewHeader: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 筛选项。
    @AppStorage(BranchesReviewState.filterKey)
    private var filter = BranchesReviewFilter.all.rawValue

    /// 排序属性。
    @AppStorage(BranchesReviewState.sortKey)
    private var sort = BranchesReviewSort.name.rawValue

    /// 是否升序。
    @AppStorage(BranchesReviewState.ascendingKey)
    private var ascending = true

    /// 40 pt 高，左侧 12、右侧 8 的内边距。
    var body: some View {
        HStack(spacing: 4) {
            Text(AppLocalization.text("review.compareTo"))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()

            baseMenu

            Spacer(minLength: 8)

            filterMenu
            viewSettingsMenu
        }
        .font(.system(size: 13))
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(height: 40)
        .background(.bar)
    }

    /// 基准分支下拉：全部本地分支，当前基准打勾。
    private var baseMenu: some View {
        let base = session.branchesReview.base

        return Menu {
            ForEach(session.history.branches.filter(\.isLocal)) { branch in
                Toggle(
                    branch.name,
                    isOn: Binding(
                        get: { branch.id == base?.id },
                        set: { _ in session.branchesReview.selectBase(branch.id) }
                    )
                )
            }
        } label: {
            Text(base?.name ?? AppLocalization.text("review.noBase"))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help(base?.name ?? "")
        .accessibilityLabel(AppLocalization.text("review.compareTo"))
    }

    /// 筛选下拉：有筛选时图标填色。
    private var filterMenu: some View {
        Menu {
            ForEach(BranchesReviewFilter.allCases, id: \.self) { item in
                Toggle(
                    AppLocalization.text(item.titleKey),
                    isOn: Binding(get: { filter == item.rawValue }, set: { _ in filter = item.rawValue })
                )
            }
        } label: {
            Image(
                systemName: filter == BranchesReviewFilter.all.rawValue
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(AppLocalization.text("review.filter"))
        .help(AppLocalization.text("review.filter"))
    }

    /// 视图设置下拉：按名称或时间排序，升序或降序。
    private var viewSettingsMenu: some View {
        Menu {
            Toggle(
                AppLocalization.text("review.sort.name"),
                isOn: Binding(get: { sort == BranchesReviewSort.name.rawValue }, set: { _ in sort = 0 })
            )
            Toggle(
                AppLocalization.text("review.sort.date"),
                isOn: Binding(get: { sort == BranchesReviewSort.date.rawValue }, set: { _ in sort = 1 })
            )

            Divider()

            Toggle(
                AppLocalization.text("review.sort.ascending"),
                isOn: Binding(get: { ascending }, set: { _ in ascending = true })
            )
            Toggle(
                AppLocalization.text("review.sort.descending"),
                isOn: Binding(get: { !ascending }, set: { _ in ascending = false })
            )
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(AppLocalization.text("review.viewSettings"))
        .help(AppLocalization.text("review.viewSettings"))
    }
}

// MARK: - BranchesReviewRow

/// 一行 52 pt：合并状态图标、分支名与超前 / 落后，第二行是跟踪的远端分支与最后更新时间。
struct BranchesReviewRow: View {
    /// 这一行的分支与比较。
    let item: BranchesReviewItem

    /// 基准分支名，用于提示文字。
    let base: String

    /// 两行文字，状态图标挂在左侧。
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            statusIcon
                .frame(width: 14, height: 14)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.reference.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    counts
                }

                HStack(spacing: 4) {
                    tracking

                    Spacer(minLength: 8)

                    if let date = item.reference.date {
                        Text(Self.relative(date))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 11))
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    /// 合并状态的图标与提示；还在比较时不显示。
    @ViewBuilder
    private var statusIcon: some View {
        switch item.comparison?.merge {
        case .unchanged:
            icon("checkmark.circle.fill", color: Color(nsColor: .systemGray), help: "review.status.merged")

        case .clean:
            icon(
                "checkmark.circle.fill",
                color: Color(nsColor: .systemGreen),
                help: "review.status.mergeable"
            )

        case .conflicts:
            icon(
                "exclamationmark.triangle.fill",
                color: Color(nsColor: .systemYellow),
                help: "review.status.conflicts"
            )

        case .unavailable(let details):
            icon("questionmark.circle", color: .secondary, help: "merge.unavailable")
                .help(details)

        case nil:
            Color.clear
        }
    }

    /// 超前 / 落后的提交数；比较完成前显示 “Comparing…”。
    @ViewBuilder
    private var counts: some View {
        if let divergence = item.comparison?.divergence {
            HStack(spacing: 3) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(divergence.ahead.formatted())

                Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(divergence.behind.formatted())
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .accessibilityLabel(AppLocalization.text("review.counts", divergence.ahead, divergence.behind))
        } else {
            Text(AppLocalization.text("review.comparing"))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    /// 跟踪的远端分支；上游已不存在时带红色的错误图标。
    @ViewBuilder
    private var tracking: some View {
        if let missing = item.condition?.missingUpstream {
            Text(Self.shortName(missing))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: .systemRed))
                .help(AppLocalization.text("review.trackingMissing"))
                .accessibilityLabel(AppLocalization.text("review.trackingMissing"))
        } else if let upstream = item.reference.upstream {
            Text(Self.shortName(upstream))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text(AppLocalization.text("review.noTracking"))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    /// 去掉 refs/heads/ 或 refs/remotes/ 前缀的引用名。
    static func shortName(_ reference: String) -> String {
        for prefix in ["refs/remotes/", "refs/heads/"] where reference.hasPrefix(prefix) {
            return String(reference.dropFirst(prefix.count))
        }

        return reference
    }

    /// 相对现在的时间，如 “last year”。
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// 14 pt 的状态图标与提示。
    private func icon(_ name: String, color: Color, help key: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 13))
            .foregroundStyle(color)
            .help(AppLocalization.text(key))
            .accessibilityLabel(AppLocalization.text(key))
    }
}
