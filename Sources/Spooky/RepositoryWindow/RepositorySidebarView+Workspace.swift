import SpookyKit
import SwiftUI

// MARK: - Workspace

extension RepositorySidebarView {
    /// Working Copy 行尾的标记：进行中的操作优先，其次是改动文件数；没有改动时不显示。
    enum WorkingCopyMarker: Equatable {
        /// 进行中操作的图标，合并与压缩合并、变基与摘取和反转各用一个。
        case operation(symbol: String)

        /// 改动文件数，不为零。
        case changes(Int)

        /// 按进行中的操作与工作区状态选择标记；状态还没有读到、没有操作也没有改动时为 nil。
        ///
        /// - Parameters:
        ///   - progress: 进行中的操作；没有时为 nil。
        ///   - status: 工作区状态；还没有读到时为 nil。
        static func current(progress: OperationProgress?, status: WorkingCopyStatus?) -> Self? {
            if let progress {
                return .operation(symbol: OperationBannerView.symbolName(progress.state))
            }

            guard let count = status?.entries.count, count > 0 else {
                return nil
            }

            return .changes(count)
        }
    }

    /// Workspace 分组：工作区、历史、储藏、请求、分支整理，视图设置打开 Show Reflog 时的 Reflog，以及仓库设置。
    var workspace: some View {
        Section(isExpanded: isExpanded(.workspace)) {
            workingCopy
                .tag("workingCopy")
                .modifier(
                    RepositoryDropTarget(session: session, destination: .head, request: request)
                )

            Label(AppLocalization.text("history.title"), systemImage: "clock").tag("history")

            // 工作区文件拖到这里保存部分储藏
            stashes
                .tag("stashes")
                .modifier(StashesDropTarget(session: session))

            // 选中远端对应 GitLab 时叫 Merge Requests
            Label(session.pullRequestText("title"), systemImage: "arrow.triangle.merge")
                .tag("pullRequests")

            Label(AppLocalization.text("review.title"), systemImage: "arrow.triangle.pull")
                .tag("branchesReview")

            // 视图设置打开 Show Reflog 时才显示
            if showsReflog {
                Label(AppLocalization.text("reflog.title"), systemImage: "clock.arrow.circlepath")
                    .tag("reflog")
            }

            Label(AppLocalization.text("repositorySettings.title"), systemImage: "gearshape")
                .tag("settings")
        } header: {
            Text(AppLocalization.text("workspace.group"))
        }
    }
}

// MARK: - Private

extension RepositorySidebarView {
    /// Working Copy 行：行尾是刷新进度或标记；悬停提示写出本地 HEAD 与未提交的文件数。
    private var workingCopy: some View {
        HStack {
            Label(AppLocalization.text("workspace.title"), systemImage: "folder")

            Spacer(minLength: 4)

            workingCopyAccessory
        }
        .help(SidebarTooltip.workingCopy(session.status, host: session.repository?.host))
        .contextMenu {
            WorkingCopyMenu(
                session: session,
                request: request,
                copyPath: copyPath,
                revealFinder: revealFinder,
                openTerminal: openTerminal
            )
        }
    }

    /// Working Copy 行尾：刷新中显示进度；否则有进行中的操作时显示 18 × 18 pt 的操作图标，没有时显示不为零的改动文件数。
    @ViewBuilder
    private var workingCopyAccessory: some View {
        if session.isRefreshing {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel(AppLocalization.text("loading.status"))
        } else {
            switch WorkingCopyMarker.current(progress: session.context?.progress, status: session.status) {
            case .operation(let symbol):
                // 图标是模板图，随行的选中状态变色；可访问性名称与操作横幅的标题相同
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .accessibilityLabel(session.operationBannerTitle ?? "")

            case .changes(let count):
                countBadge(count.formatted())
                    .accessibilityLabel(AppLocalization.text("workspace.changed", count))

            case nil:
                EmptyView()
            }
        }
    }

    /// 储藏入口；视图设置打开时带储藏个数，样式与工作区的改动数相同。
    private var stashes: some View {
        HStack {
            Label(AppLocalization.text("stash.title"), systemImage: "tray.full")
            Spacer(minLength: 4)

            if showsStashCount, session.stashes.isLoaded {
                countBadge(session.stashes.entries.count.formatted())
                    .accessibilityLabel(AppLocalization.text("stash.count", session.stashes.entries.count))
            }
        }
    }

    /// Workspace 行尾的胶囊计数。
    private func countBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppPalette.color("sidebarBadgeBackgroundColor"), in: Capsule())
    }
}
