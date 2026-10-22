import SpookyKit
import SwiftUI

/// 工作区列表保留所有状态条目，刷新期间仍展示旧快照。
struct WorkingCopyListView: View {
    /// 当前仓库会话。
    @Bindable var session: RepositorySession

    /// 平铺为固定默认值，选择立即保存到全局偏好。
    @AppStorage("workingCopyViewMode") private var mode = 0

    /// 分支头、状态表与底部的读取反馈。
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(session: session)
            branchHeader

            Divider()

            WorkingCopyCommitView(session: session)

            Divider()

            WorkingCopyFileList(session: session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    // 干净的工作区用文字说明，不只留下空白列表。
                    if session.status?.entries.isEmpty == true {
                        Text(AppLocalization.text("working.clean"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

            Divider()

            HStack {
                if session.isWriting || session.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                    Text(AppLocalization.text(session.isWriting ? "working.writing" : "loading.status"))
                } else if session.failure != nil, session.connectionState == nil || session.connectionState == .connected {
                    // 刷新失败后列表仍是上一次的结果，底栏持续说明这一点；断线由连接横幅说明。
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppPalette.color("warning_tint_color"))
                        .accessibilityHidden(true)
                    Text(AppLocalization.text("working.refreshFailed"))
                } else if let status = session.status {
                    Text(AppLocalization.text("workspace.changed", status.entries.count))
                }

                Spacer(minLength: 0)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .frame(height: 28)
        }
    }

    /// 当前分支、跟踪关系与领先落后数量；没有上游时明确显示没有上游。
    private var branchHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                if let branch = session.status?.branch {
                    HStack(spacing: 4) {
                        Text(branchTitle(branch))
                            .foregroundStyle(.secondary)

                        if branch.head != nil {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .accessibilityHidden(true)
                            Text(branch.upstream ?? AppLocalization.text("branch.noTracking"))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .help(branchTitle(branch))

                    HStack(spacing: 8) {
                        Text(AppLocalization.text("branch.ahead", branch.ahead))
                        Text(AppLocalization.text("branch.behind", branch.behind))
                        Text(AppLocalization.text("workspace.changed", session.status?.entries.count ?? 0))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                } else {
                    Text(AppLocalization.text("workspace.title"))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Menu {
                Picker(AppLocalization.text("working.viewMode"), selection: $mode) {
                    Text(AppLocalization.text("working.list")).tag(0)
                    Text(AppLocalization.text("working.tree")).tag(1)
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
            .accessibilityLabel(AppLocalization.text("working.viewMode"))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40)
        .background(AppPalette.color("general_header_background_color"))
    }

    /// 分离 HEAD 使用已有哈希的短显示，未出生分支保留其名称。
    private func branchTitle(_ branch: BranchStatus) -> String {
        if let head = branch.head {
            return branch.oid == nil ? AppLocalization.text("branch.unborn", head) : head
        }

        if let oid = branch.oid {
            return AppLocalization.text("branch.detached", String(oid.prefix(12)))
        }

        return AppLocalization.text("branch.noHead")
    }
}
