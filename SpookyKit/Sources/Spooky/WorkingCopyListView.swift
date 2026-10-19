import SpookyKit
import SwiftUI

/// 文件列表的一行，排序与标识不改变核心库的状态模型。
private struct StatusRow: Identifiable {
    /// Git 状态条目。
    let entry: StatusEntry

    /// 路径和类别共同标识一条记录。
    var id: StatusRowID { StatusRowID(path: entry.path, kind: entry.kind) }

    /// 路径列的排序值。
    var path: String { entry.path }

    /// 状态列的排序值。
    var sortKey: String {
        switch entry.kind {
        case .untracked: return "?"
        case .ignored: return "!"
        case .conflicted: return "U"
        case .tracked:
            return [entry.staged, entry.unstaged]
                .map { $0.map { String($0.rawValue) } ?? "." }
                .joined()
        }
    }
}

/// 工作区列表保留所有状态条目，刷新期间仍展示旧快照。
struct WorkingCopyListView: View {
    /// 当前仓库会话。
    @Bindable var session: RepositorySession

    /// 表头排序，默认按路径升序。
    @State private var sortOrder = [KeyPathComparator(\StatusRow.path)]

    /// 分支头、状态表与底部的读取反馈。
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(session: session)
            branchHeader

            Divider()

            Table(
                (session.status?.entries ?? []).map { StatusRow(entry: $0) }.sorted(using: sortOrder),
                selection: $session.selectedID,
                sortOrder: $sortOrder
            ) {
                TableColumn(AppLocalization.text("status.column"), value: \.sortKey) { row in
                    FileStatusView(entry: row.entry)
                }
                .width(68)

                TableColumn(AppLocalization.text("status.filename"), value: \.path) { row in
                    Label(row.path, systemImage: row.path.hasSuffix("/") ? "folder" : "doc")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(row.path)
                }
            }
            .tableStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(AppPalette.color("general_background_color"))
            .environment(\.defaultMinListRowHeight, 28)
            .accessibilityIdentifier("working-copy-status")

            Divider()

            HStack {
                if session.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                    Text(AppLocalization.text("loading.status"))
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

                HStack(spacing: 12) {
                    Text(AppLocalization.text("branch.ahead", branch.ahead))
                    Text(AppLocalization.text("branch.behind", branch.behind))
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            } else {
                Text(AppLocalization.text("workspace.title"))
                    .foregroundStyle(.secondary)
            }
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
