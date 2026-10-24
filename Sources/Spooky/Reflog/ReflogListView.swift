import SpookyKit
import SwiftUI

// MARK: - ReflogListView

/// Reflog 视图左栏：40 pt 的引用选择栏与分页的记录列表，支持右键菜单与拖动记录的提交。
struct ReflogListView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 从记录新建分支：窗口呈现新建分支对话框，起点是记录的提交。
    let createBranch: (String) -> Void

    /// 标题栏、列表与读取失败提示；仓库、引用与搜索变化时重新读取。
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(session: session)

            header
            Divider()

            content
        }
        .frame(minWidth: 300)
        .task(id: session.repository) {
            guard let runner = session.runner, let repository = session.repository else { return }

            session.reflog.load(runner: runner, location: repository)
        }
        .task(id: session.searchText) {
            // 输入停顿后再搜索，连续输入只读一次
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            session.reflog.search(session.searchText)
        }
        .onChange(of: session.history.snapshot) {
            followReferences()
        }
        .onChange(of: session.status?.branch.oid) {
            session.reflog.reload()
        }
    }

    /// 引用在界面上的名称：HEAD 原样，本地分支去掉 `refs/heads/`。
    static func name(of reference: String) -> String {
        reference.hasPrefix("refs/heads/") ? String(reference.dropFirst("refs/heads/".count)) : reference
    }
}

// MARK: - Layout

extension ReflogListView {
    /// “Ref:” 与引用菜单，读取中显示转圈。
    private var header: some View {
        HStack(spacing: 2) {
            Text(AppLocalization.text("reflog.ref"))
                .foregroundStyle(.secondary)

            Picker(
                AppLocalization.text("reflog.ref"),
                selection: Binding(
                    get: { session.reflog.reference },
                    set: { session.reflog.show(reference: $0) }
                )
            ) {
                Text("HEAD").tag("HEAD")
                Divider()

                ForEach(branches, id: \.self) { branch in
                    Text(Self.name(of: branch)).tag(branch)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()

            Spacer(minLength: 4)

            if session.reflog.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(AppLocalization.text("reflog.loading"))
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.bar)
    }

    /// 读取失败、首次读取、没有记录与列表各有明确状态。
    @ViewBuilder
    private var content: some View {
        let reflog = session.reflog

        if let failure = reflog.failure, reflog.entries.isEmpty {
            ScrollView {
                FailureDetailsView(failure: failure) { reflog.reload() }
                    .padding(12)
            }
        } else if !reflog.isLoaded {
            ProgressView(AppLocalization.text("reflog.loading"))
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if reflog.entries.isEmpty {
            EmptyStateView(title: AppLocalization.text("reflog.empty"), message: "", symbol: "clock.arrow.circlepath")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            list
        }
    }

    /// 单选列表；最后一行出现时续读下一页。
    private var list: some View {
        let reflog = session.reflog

        return List(selection: Bindable(reflog).selectedID) {
            ForEach(reflog.entries) { entry in
                ReflogRow(entry: entry)
                    .tag(entry.id)
                    .onDrag { dragProvider(entry) }
            }

            if reflog.hasMore {
                ProgressView(AppLocalization.text("reflog.loading"))
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .onAppear { reflog.loadNextPage() }
            }
        }
        .listStyle(.inset)
        .contextMenu(forSelectionType: Int.self) { ids in
            if let id = ids.first, let entry = reflog.entries.first(where: { $0.id == id }) {
                menu(entry)
            }
        }
    }
}

// MARK: - Actions

extension ReflogListView {
    /// 本地分支，当前分支在前，其余按名称排列。
    private var branches: [String] {
        let current = session.status?.branch.head.map { "refs/heads/" + $0 }
        let local = session.history.snapshot?.references.filter(\.isLocal).map(\.id).sorted() ?? []

        return local.filter { $0 == current } + local.filter { $0 != current }
    }

    /// 重置 HEAD；看分支时恢复这个分支；从记录新建分支与摘取；保存补丁。
    @ViewBuilder
    private func menu(_ entry: ReflogEntry) -> some View {
        let hash = entry.commit.shortID

        Button(AppLocalization.text("reflog.reset", hash)) {
            session.requestReset(to: entry.commit.id)
        }
        .disabled(!session.canRewrite)

        if let branch = session.reflogRestorableBranch {
            Button(AppLocalization.text("reflog.restore", branch.name, hash)) {
                session.requestRestore(entry)
            }
            .disabled(!session.canRestoreReflogBranch(to: entry))
        }

        Divider()

        Button(AppLocalization.text("reflog.createBranch", hash)) {
            createBranch(entry.commit.id)
        }
        .disabled(!session.canCreateBranchFromReference)

        Button(AppLocalization.text("reflog.cherryPick", hash)) {
            session.requestCherryPick([entry.commit.id])
        }
        .disabled(!session.canRewrite)

        Divider()

        Button(AppLocalization.text("patch.menu", hash)) {
            session.requestSavePatch([entry.commit], quick: false)
        }
    }

    /// 所看的分支已被删除时回到 HEAD，否则按新的引用重读。
    private func followReferences() {
        let reflog = session.reflog

        if reflog.reference != "HEAD", session.history.snapshot != nil, !branches.contains(reflog.reference) {
            reflog.show(reference: "HEAD")
        } else {
            reflog.reload()
        }
    }

    /// 拖动记录与拖动历史提交相同，载荷是记录的提交。
    private func dragProvider(_ entry: ReflogEntry) -> NSItemProvider {
        guard let repository = session.repository else {
            return NSItemProvider()
        }

        return RepositoryDragPayload(repository: repository, kind: .commit, reference: entry.commit.id).provider()
    }
}

// MARK: - ReflogRow

/// 69 pt 的记录行：上行是短哈希、动作标记与日期，下行是记录的说明，最多两行。
private struct ReflogRow: View {
    /// 当前记录。
    let entry: ReflogEntry

    /// 选中行在活跃的列表里铺强调色时，标记换用选中配色；文字的层级色由列表自动换成选中色。
    @Environment(\.backgroundProminence)
    private var prominence

    /// 选中行是否铺着强调色。
    private var selected: Bool {
        prominence == .increased
    }

    /// 日期按提交日期的显示格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 两行文字，标记只排一行。
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(entry.commit.shortID)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()

                badge
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 日期贴着行的右缘，始终完整显示
                Text(dateFormat.string(from: entry.date))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }

            Text(entry.message)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 35, alignment: .topLeading)
        }
        .font(.system(size: 12))
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(height: 69, alignment: .top)
        .help(entry.message)
    }

    /// 动作标记：11 pt 命令名、4 pt 圆角；合并类红、移动类灰、提交类黄，选中时换成选中配色。
    private var badge: some View {
        let palette =
            if selected {
                "selected"
            } else {
                switch entry.category {
                case .merge: "red"
                case .move: "gray"
                case .commit: "yellow"
                }
            }

        return Text(entry.command)
            .font(.system(size: 11))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .foregroundStyle(AppPalette.color(palette + "_badge_text_color"))
            .background(AppPalette.color(palette + "_badge_background_color"), in: RoundedRectangle(cornerRadius: 4))
    }
}
