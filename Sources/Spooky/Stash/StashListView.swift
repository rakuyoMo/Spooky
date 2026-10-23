import SpookyKit
import SwiftUI

// MARK: - StashListView

/// 储藏视图左栏：标题栏与按说明过滤的储藏列表，支持多选、右键菜单、删除键与拖到工作区。
struct StashListView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 40 pt 标题栏、列表与加载失败提示。
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(session: session)

            header
            Divider()

            content
        }
        .frame(minWidth: 200)
    }
}

// MARK: - Layout

extension StashListView {
    /// 标题与读取中的转圈。
    private var header: some View {
        HStack(spacing: 8) {
            Text(AppLocalization.text("stash.title"))
                .lineLimit(1)

            Spacer(minLength: 4)

            if session.stashes.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(AppLocalization.text("stash.loading"))
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.bar)
    }

    /// 读取失败、首次读取、没有储藏、搜索无结果与列表各有明确状态。
    @ViewBuilder
    private var content: some View {
        let stashes = session.stashes
        let visible = stashes.filtered(by: session.searchText)

        if let failure = stashes.failure {
            ScrollView {
                FailureDetailsView(failure: failure) {
                    if let runner = session.runner { stashes.refresh(runner: runner) }
                }
                .padding(12)
            }
        } else if !stashes.isLoaded {
            ProgressView(AppLocalization.text("stash.loading"))
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if stashes.entries.isEmpty {
            EmptyStateView(title: AppLocalization.text("stash.empty"), message: "", symbol: "tray")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if visible.isEmpty {
            EmptyStateView(title: AppLocalization.text("stash.noMatches"), message: "", symbol: "magnifyingglass")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            list(visible)
        }
    }

    /// 原生选择、右键菜单与删除键作用于同一组选择。
    private func list(_ visible: [StashEntry]) -> some View {
        List(selection: Bindable(session.stashes).selectedIDs) {
            ForEach(visible) { stash in
                StashRow(stash: stash, selected: session.stashes.selectedIDs.contains(stash.id))
                    .tag(stash.id)
                    .onDrag { dragProvider(stash) }
            }
        }
        .listStyle(.inset)
        .contextMenu(forSelectionType: String.self) { ids in
            menu(ids)
        }
        .onDeleteCommand {
            session.deleteStashes(session.stashes.selectedStashes)
        }
    }

    /// 单选：应用与删除这个储藏；多选：删除全部所选储藏。
    @ViewBuilder
    private func menu(_ ids: Set<String>) -> some View {
        let selected = session.stashes.entries.filter { ids.contains($0.id) }

        if selected.count == 1, let stash = selected.first {
            Button(AppLocalization.text("stash.applyNamed", stash.title)) {
                session.requestApplyStash(stash)
            }
            .disabled(!session.canApply(stash))

            Button(AppLocalization.text("stash.deleteNamed", stash.title)) {
                session.deleteStashes([stash])
            }
            .disabled(!session.canDelete([stash]))
        } else if selected.count > 1 {
            Button(AppLocalization.text("stash.deleteMultiple", selected.count)) {
                session.deleteStashes(selected)
            }
            .disabled(!session.canDelete(selected))
        }
    }

    /// 拖动开始时仓库仍在显示才提供载荷。
    private func dragProvider(_ stash: StashEntry) -> NSItemProvider {
        guard let repository = session.repository else {
            return NSItemProvider()
        }

        return RepositoryDragPayload(repository: repository, kind: .stash, reference: stash.id).provider()
    }
}

// MARK: - StashRow

/// 52 pt 的储藏行：上行是 “Based on” 来源分支与日期，下行是说明。
private struct StashRow: View {
    /// 当前储藏。
    let stash: StashEntry

    /// 选中行的标记换用选中配色。
    let selected: Bool

    /// 两行文字，标记只排一行。
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(AppLocalization.text("stash.basedOn"))
                    .foregroundStyle(.secondary)

                if let branch = stash.branch {
                    badge(branch)
                }

                Text(stash.date.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(stash.title)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.system(size: 12))
        .padding(.vertical, 8)
        .frame(height: 52, alignment: .leading)
        .help(stash.title)
    }

    /// 来源分支标记使用 11 pt 文本、4 pt 圆角与灰色配色。
    private func badge(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .foregroundStyle(AppPalette.color((selected ? "selected" : "gray") + "_badge_text_color"))
            .background(
                AppPalette.color((selected ? "selected" : "gray") + "_badge_background_color"),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }
}
