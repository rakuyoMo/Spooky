import AppKit
import SpookyKit
import SwiftUI

// MARK: - ConflictWizardView

/// 选中冲突文件时的右栏：上排我方、对方两张版本卡片，两条弯箭头汇入下方的结果框，结果框下是统一的动作按钮；
/// 整块内容在右栏里竖直居中，右栏的最小宽度由窗口控制器在向导出现时放宽。
///
/// 单击卡片选中这一侧，⌘ 单击另一张可以两侧都选，再单击已选的卡片取消；选择只是视图状态，不改工作区或索引。
struct ConflictWizardView: View {
    /// 触发载入的请求：文件的三方版本变化或需要重新读取时重新载入。
    private struct LoadRequest: Equatable {
        /// 选中的冲突文件，包含三方 stage 的哈希。
        let entry: StatusEntry

        /// 重新载入的请求序号。
        let reloads: Int
    }

    /// 当前仓库会话。
    @Bindable
    var session: RepositorySession

    /// 选中的冲突文件。
    let entry: StatusEntry

    /// 最近一次载入的三方内容；重新载入期间继续显示上一份。
    @State
    private var contents: ConflictContents?

    /// 两侧版本所在的提交，随内容一起载入。
    @State
    private var commits: (ours: HistoryCommit?, theirs: HistoryCommit?) = (nil, nil)

    /// 载入失败的原因，保留可复制的原文。
    @State
    private var failure: AppFailure?

    /// 重新载入的请求序号。
    @State
    private var reloads = 0

    /// 选中的版本卡片。
    @State
    private var selection: Set<ConflictSide> = []

    /// 设置里选的合并工具，决定合并按钮的标题。
    @AppStorage(ExternalTool.mergeToolKey)
    private var mergeTool = ""

    /// 载入中、失败或向导内容。
    ///
    /// 写入结束、重新连上服务器与切回本程序时自动重新载入：文件可能已在外部编辑器里改过。换了文件时清空选择。
    var body: some View {
        Group {
            if let failure {
                FailureDetailsView(failure: failure) { reloads += 1 }
                    .padding(20)
            } else if let contents {
                wizard(contents)
            } else {
                ProgressView(AppLocalization.text("conflict.loading"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: LoadRequest(entry: entry, reloads: reloads)) { await load() }
        .onChange(of: entry.path) { selection = [] }
        .onChange(of: session.isWriting) {
            if !session.isWriting { reloads += 1 }
        }
        .onChange(of: session.connectionState) {
            if session.connectionState == .connected { reloads += 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            reloads += 1
        }
    }
}

// MARK: - Private

extension ConflictWizardView {
    /// 合并按钮：选过合并工具时写出它的名字，还没有选时先选工具。
    private var mergeToolTitle: String {
        guard let tool = ExternalTool(rawValue: mergeTool), tool.supportsMerge else {
            return AppLocalization.text("externalTool.chooseMergeTool")
        }

        return AppLocalization.text("externalTool.mergeIn", tool.displayName)
    }

    /// 还没有选版本时的结果框：空文件的轮廓与提示。
    private var unselectedResult: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.tertiary)
                .frame(width: 47, height: 62)

            Text(AppLocalization.text("conflict.selectVersion"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 138)
    }

    /// 交给合并工具的按钮；只有两侧都是普通文件的单个冲突可用。
    private var mergeToolButton: some View {
        Button(mergeToolTitle) { session.openMergeTool(entry) }
            .disabled(!session.canOpenMergeTool([entry]))
    }

    /// 两张卡片、汇入结果框的箭头、结果框与结果框下的动作。
    ///
    /// 卡片各 198 pt、间距 22 pt，结果框 348 × 138 pt；右栏比内容窄时内容不撑开右栏。
    private func wizard(_ contents: ConflictContents) -> some View {
        let result = ConflictResult.of(selection: selection, contents: contents)

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 22) {
                card(.ours, data: contents.ours, commit: commits.ours)
                card(.theirs, data: contents.theirs, commit: commits.theirs)
            }

            ConflictArrows(selection: selection)
                .frame(width: 418, height: 120)

            resultBox(result, contents: contents)
                .frame(width: 348)

            action(result)
                .padding(.top, 16)
        }
        .padding(20)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    /// 一张版本卡片；单击选中或取消，按住 ⌘ 时加入已有的选择。
    private func card(_ side: ConflictSide, data: Data?, commit: HistoryCommit?) -> some View {
        ConflictVersionCard(
            session: session,
            entry: entry,
            side: side,
            data: data,
            commit: commit,
            isSelected: selection.contains(side)
        )
        .frame(width: 198)
        .onTapGesture {
            selection = side.toggled(in: selection, adding: NSEvent.modifierFlags.contains(.command))
        }
        .accessibilityAddTraits(selection.contains(side) ? [.isButton, .isSelected] : .isButton)
    }

    /// 结果框，与版本卡片同一种样子：未选时是空文件轮廓与提示；选了一侧时是这一侧的标题与摘要；
    /// 两侧都选时是两份叠放的缩略图与 MERGE 徽标；手动编辑过时是当前文件、EDITED 徽标与它的修改时间。
    private func resultBox(_ result: ConflictResult, contents: ConflictContents) -> some View {
        VStack(spacing: 0) {
            switch result {
            case .unselected:
                unselectedResult

            case .side(let side):
                resultSummary(
                    ConflictVersionCard.title(of: side, in: session),
                    contents: [side == .ours ? contents.ours : contents.theirs],
                    badge: entry.conflict.map { ConflictBadge(change: $0.change(theirs: side == .theirs)) },
                    date: (side == .ours ? commits.ours : commits.theirs)?.commitDate
                )

            case .both:
                resultSummary(
                    AppLocalization.text("conflict.resolveBoth"),
                    contents: [contents.ours, contents.theirs],
                    badge: .merge,
                    date: nil
                )

            case .current:
                resultSummary(
                    AppLocalization.text("conflict.result"),
                    contents: [contents.worktree],
                    badge: .edited,
                    date: contents.worktreeModified
                )
            }
        }
        .modifier(ConflictTile(isSelected: false))
    }

    /// 结果框里的标题栏与摘要。
    ///
    /// - Parameters:
    ///   - title: 标题栏的文字。
    ///   - contents: 缩略图显示的原文。
    ///   - badge: 改动徽标。
    ///   - date: 摘要里的时间。
    private func resultSummary(_ title: String, contents: [Data?], badge: ConflictBadge?, date: Date?) -> some View {
        VStack(spacing: 0) {
            ConflictTileTitle(title: title)

            Divider()

            ConflictVersionSummary(path: entry.path, contents: contents, badge: badge, date: date)
        }
    }

    /// 结果框下的动作：内容冲突与双方新增未选时交给合并工具，其余冲突未选时 Resolve 不可用。
    @ViewBuilder
    private func action(_ result: ConflictResult) -> some View {
        switch result {
        case .unselected:
            if entry.conflict?.hasRegularFilesOnBothSides ?? false {
                mergeToolButton
            } else {
                Button(AppLocalization.text("conflict.resolve")) { }
                    .disabled(true)
            }

        case .side(let side):
            Button(resolveTitle(side)) { session.resolve([entry], theirs: side == .theirs) }
                .disabled(!session.canResolve([entry]))

        case .both:
            mergeToolButton

        case .current:
            Button(AppLocalization.text("conflict.resolveCurrent")) { session.stage([entry], staged: true) }
                .disabled(!session.canResolve([entry]))
        }
    }

    /// 采用一侧的按钮标题：应用补丁或储藏的一侧是状态描述，不加引用名的引号。
    private func resolveTitle(_ side: ConflictSide) -> String {
        guard side == .theirs, session.context?.progress == nil else {
            return AppLocalization.text("conflict.resolveUsing", ConflictVersionCard.name(of: side, in: session))
        }

        return AppLocalization.text("conflict.resolveUsing.applied")
    }

    /// 读取三方内容与两侧的提交；被新的请求取代的结果直接丢弃。
    private func load() async {
        do {
            let loaded = try await session.conflictContents(of: entry)
            let sources = await session.conflictCommits()

            guard !Task.isCancelled else { return }

            contents = loaded
            commits = sources
            failure = nil
        } catch {
            guard !Task.isCancelled else { return }

            failure = AppFailure(error: error, opening: false, location: session.repository)
        }
    }
}

// MARK: - ConflictKind

extension ConflictKind {
    /// 冲突类型的本地化名称，用于文件行的悬停提示。
    var title: String {
        switch self {
        case .bothModified: AppLocalization.text("conflict.kind.bothModified")
        case .bothAdded: AppLocalization.text("conflict.kind.bothAdded")
        case .bothDeleted: AppLocalization.text("conflict.kind.bothDeleted")
        case .addedByUs: AppLocalization.text("conflict.kind.addedByUs")
        case .addedByThem: AppLocalization.text("conflict.kind.addedByThem")
        case .deletedByUs: AppLocalization.text("conflict.kind.deletedByUs")
        case .deletedByThem: AppLocalization.text("conflict.kind.deletedByThem")
        }
    }
}
