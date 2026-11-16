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
                : SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey),
            pullRequests: session.pullRequests.branchRequests
        )

        VStack(spacing: 0) {
            ConnectionStatusView(session: session)

            BranchesReviewHeader(session: session)
            Divider()

            if let failure = state.failure {
                FailureDetailsView(failure: failure)
                    .padding(12)
            }

            // 按请求筛选却读不到请求状态时说明原因，不把未知当成没有请求
            if BranchesReviewFilter(rawValue: filter)?.isPullRequestFilter ?? false, session.pullRequests.branchRequests == nil {
                pullRequestNotice
            }

            list(items)
        }
        .task(id: snapshotKey) {
            state.update(
                snapshot: session.history.snapshot,
                head: session.status?.branch.head,
                runner: session.runner
            )

            // 托管服务上的请求状态一分钟内不重复读取
            if let runner = session.runner {
                await session.pullRequests.loadBranchRequests(runner: runner, upstreamRemote: session.headBranch?.upstreamRemote)
            }
        }
    }

    /// 读不到请求状态的说明：读取失败时写出原文，没有账号时说明要先登录。
    @ViewBuilder
    private var pullRequestNotice: some View {
        if let failure = session.pullRequests.branchRequestsFailure {
            FailureDetailsView(failure: failure)
                .padding(12)
        } else {
            Text(AppLocalization.text("review.pullRequestsUnavailable"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 引用快照与当前分支一变就重新比较。
    private var snapshotKey: [String] {
        (session.history.snapshot?.references.filter(\.isLocal).map { $0.id + $0.objectID } ?? [])
            + [session.status?.branch.head ?? ""]
    }

    /// 没有分支时显示空状态，否则显示可多选的列表；删除只接 Edit › Delete（⌘⌫），单独的 ⌫ 不删除。
    ///
    /// 行变化后所选的行都不在列表里时，选中第一行。
    @ViewBuilder
    private func list(_ items: [BranchesReviewItem]) -> some View {
        if items.isEmpty {
            EmptyStateView(
                title: AppLocalization.text("review.empty"),
                message: "",
                symbol: AppSymbol.branch
            )
        } else {
            List(selection: Bindable(session.branchesReview).selectedIDs) {
                ForEach(items) { item in
                    BranchesReviewRow(item: item, base: session.branchesReview.base?.name ?? "")
                        .tag(item.id)
                        .contextMenu {
                            BranchesReviewMenu(session: session, item: item, items: items, request: request)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            swipeDelete(item.reference)
                        }
                }
            }
            .listStyle(.inset)
            .onCommand(#selector(NSText.delete(_:)), perform: deleteCommand(items))
            .onChange(of: items.map(\.id), initial: true) { _, ids in
                session.branchesReview.selectFirstIfNeeded(in: ids)
            }
        }
    }

    /// 行尾侧轻扫出的 Delete，破坏性样式；当前分支的底色是灰色。
    private func swipeDelete(_ branch: RepositoryReference) -> some View {
        Button(AppLocalization.text("review.delete"), role: .destructive) {
            deleteBySwipe(branch)
        }
        .tint(branch.id == session.headBranch?.id ? Color(nsColor: .systemGray) : nil)
    }

    /// Edit › Delete（⌘⌫）的动作：确认后删除列表里所选的分支；没有选中或不能删除时为 nil，菜单项随之不可用。
    func deleteCommand(_ items: [BranchesReviewItem]) -> (() -> Void)? {
        let selected = session.branchesReview.selectedIDs
        let targets = items.filter { selected.contains($0.id) }.map(\.reference)

        guard !targets.isEmpty, session.canDelete(targets) else {
            return nil
        }

        return { session.requestReference(.deleteBranches(targets)) }
    }

    /// 轻扫出的 Delete 被点下：与右键删除同一个删除确认；当前分支等不能删除的只发提示音。
    func deleteBySwipe(_ branch: RepositoryReference) {
        guard session.canDelete([branch]) else {
            NSSound.beep()
            return
        }

        session.requestReference(.deleteBranches([branch]))
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

    /// 基准分支的弹出按钮；表头放不下时先截断它。
    private var baseMenu: some View {
        BranchesReviewBasePopUp(
            branches: session.history.branches.filter(\.isLocal),
            base: session.branchesReview.base
        ) { session.branchesReview.selectBase($0) }
    }

    /// 筛选下拉：灰色标题 Filter 下按 `BranchesReviewFilter.menuGroups` 分组，组间是分隔线；有筛选时图标填色。
    private var filterMenu: some View {
        Menu {
            Section(AppLocalization.text("review.filterHeading")) {
                ForEach(BranchesReviewFilter.menuGroups.indices, id: \.self) { index in
                    if index > 0 {
                        Divider()
                    }

                    ForEach(BranchesReviewFilter.menuGroups[index], id: \.self) { item in
                        Toggle(
                            item.isPullRequestFilter
                                ? session.pullRequestText(item.titleKey)
                                : AppLocalization.text(item.titleKey),
                            isOn: Binding(get: { filter == item.rawValue }, set: { _ in filter = item.rawValue })
                        )
                    }
                }
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

    /// 视图设置下拉：灰色标题 Sort By 下是名称与最后更新时间，分隔线后灰色标题 Sort Order 下是升序与降序。
    private var viewSettingsMenu: some View {
        Menu {
            Section(AppLocalization.text("review.sortBy")) {
                Toggle(
                    AppLocalization.text("review.sort.name"),
                    isOn: Binding(get: { sort == BranchesReviewSort.name.rawValue }, set: { _ in sort = 0 })
                )

                Toggle(
                    AppLocalization.text("review.sort.date"),
                    isOn: Binding(get: { sort == BranchesReviewSort.date.rawValue }, set: { _ in sort = 1 })
                )
            }

            Divider()

            Section(AppLocalization.text("review.sortOrder")) {
                Toggle(
                    AppLocalization.text("review.sort.ascending"),
                    isOn: Binding(get: { ascending }, set: { _ in ascending = true })
                )

                Toggle(
                    AppLocalization.text("review.sort.descending"),
                    isOn: Binding(get: { !ascending }, set: { _ in ascending = false })
                )
            }
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

/// 一行 52 pt：合并状态图标、分支名与靠右的超前 / 落后，第二行是跟踪的远端分支与靠右的最后更新时间。
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

                    if let request = item.pullRequest {
                        pullRequestBadge(request)
                    }

                    Spacer(minLength: 8)

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

    /// 合并状态的图标与提示；还在比较时，以及并入基准不带来变化时不显示。
    @ViewBuilder
    private var statusIcon: some View {
        switch item.comparison?.merge {
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

        case .unchanged, nil:
            Color.clear
        }
    }

    /// 超前 / 落后的提交数，箭头斜向；比较完成前显示 “Comparing…”。
    ///
    /// 读屏时整组是一个元素，只读一遍，一个提交时用单数。
    @ViewBuilder
    private var counts: some View {
        if let divergence = item.comparison?.divergence {
            HStack(spacing: 3) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)

                Text(divergence.ahead.formatted())

                Image(systemName: "arrow.down.left")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)

                Text(divergence.behind.formatted())
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.countsLabel(divergence))
        } else {
            Text(AppLocalization.text("review.comparing"))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    /// 跟踪的远端分支，没有时写 No tracking branch，都是次级文字色；上游已不存在时名字与错误图标都是红色。
    @ViewBuilder
    private var tracking: some View {
        if let missing = item.condition?.missingUpstream {
            Text(Self.shortName(missing))
                .foregroundStyle(Color(nsColor: .systemRed))
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
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// 超前 / 落后的读屏文字，一个提交时用单数。
    static func countsLabel(_ divergence: ReferenceDivergence) -> String {
        let ahead = divergence.ahead == 1
            ? AppLocalization.text("review.ahead.one")
            : AppLocalization.text("review.ahead", divergence.ahead)

        let behind = divergence.behind == 1
            ? AppLocalization.text("review.behind.one")
            : AppLocalization.text("review.behind", divergence.behind)

        return AppLocalization.text("review.counts", ahead, behind)
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

    /// 分支在托管服务上最近的请求：编号与状态色，提示里写出状态。
    private func pullRequestBadge(_ request: PullRequest) -> some View {
        let state: (key: String, color: Color) =
            switch request.state {
            case .open: ("pullRequests.state.open", Color(nsColor: .systemGreen))
            case .merged: ("pullRequests.state.merged", Color(nsColor: .systemPurple))
            case .closed: ("pullRequests.state.closed", Color(nsColor: .systemRed))
            }

        return Text(request.id.reference)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(state.color)
            .help(AppLocalization.text(state.key))
            .accessibilityLabel(request.id.reference + " " + AppLocalization.text(state.key))
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
