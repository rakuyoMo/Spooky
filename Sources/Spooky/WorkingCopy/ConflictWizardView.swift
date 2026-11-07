import AppKit
import SpookyKit
import SwiftUI

// MARK: - ConflictWizardView

/// 选中冲突文件时的右栏：上排我方、对方两张版本卡片，两条箭头汇入下方的结果框，结果框下是统一的动作按钮。
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

    /// 设置里的提交日期格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

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

    /// 交给合并工具的按钮；只有两侧都是普通文件的单个冲突可用。
    private var mergeToolButton: some View {
        Button(mergeToolTitle) { session.openMergeTool(entry) }
            .disabled(!session.canOpenMergeTool([entry]))
    }

    /// 两张卡片、汇入结果框的箭头、结果框与结果框下的动作。
    private func wizard(_ contents: ConflictContents) -> some View {
        let result = ConflictResult.of(selection: selection, contents: contents)

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                card(.ours, data: contents.ours, commit: commits.ours)
                card(.theirs, data: contents.theirs, commit: commits.theirs)
            }

            ConflictArrows(selection: selection)
                .frame(height: 32)

            resultBox(result)

            action(result)
                .padding(.top, 12)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
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
        .onTapGesture {
            selection = side.toggled(in: selection, adding: NSEvent.modifierFlags.contains(.command))
        }
        .accessibilityAddTraits(selection.contains(side) ? [.isButton, .isSelected] : .isButton)
    }

    /// 结果框：未选时提示选择，单选与当前文件等于某侧时显示该侧，两侧都选时是合并，手动合并过时是当前版本。
    private func resultBox(_ result: ConflictResult) -> some View {
        Group {
            switch result {
            case .unselected:
                Text(AppLocalization.text("conflict.selectVersion"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

            case .side(let side):
                let commit = side == .ours ? commits.ours : commits.theirs

                ConflictVersionSummary(
                    path: entry.path,
                    change: entry.conflict?.change(theirs: side == .theirs),
                    date: commit.map { dateFormat.string(from: $0.commitDate) }
                )

            case .both:
                resultTitle("conflict.resolveBoth", badge: .merge)

            case .current:
                resultTitle("conflict.result", badge: nil)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(ConflictTile(isSelected: false))
    }

    /// 结果框里两侧合并或手动合并的结果：标题在上，文件摘要在下。
    private func resultTitle(_ key: String, badge: ConflictBadge?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text(key))
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)

            ConflictVersionSummary(path: entry.path, change: nil, date: nil, badge: badge)
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

// MARK: - ConflictArrows

/// 两张卡片汇入结果框的箭头；对应的卡片选中时变蓝。
private struct ConflictArrows: View {
    /// 选中的卡片。
    let selection: Set<ConflictSide>

    /// 两条从卡片中线斜向结果框中央的箭头。
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                arrow(
                    from: CGPoint(x: size.width * 0.25, y: 4),
                    to: CGPoint(x: size.width / 2 - 8, y: size.height - 4),
                    isSelected: selection.contains(.ours)
                )

                arrow(
                    from: CGPoint(x: size.width * 0.75, y: 4),
                    to: CGPoint(x: size.width / 2 + 8, y: size.height - 4),
                    isSelected: selection.contains(.theirs)
                )
            }
        }
        .accessibilityHidden(true)
    }

    /// 一条带箭头的线：箭头两翼与线身各成 30°。
    private func arrow(from start: CGPoint, to end: CGPoint, isSelected: Bool) -> some View {
        let angle = atan2(end.y - start.y, end.x - start.x)

        /// 箭头一翼的端点。
        func wing(_ offset: CGFloat) -> CGPoint {
            CGPoint(
                x: end.x - 7 * cos(angle + offset),
                y: end.y - 7 * sin(angle + offset)
            )
        }

        return Path { path in
            path.move(to: start)
            path.addLine(to: end)
            path.move(to: wing(.pi / 6))
            path.addLine(to: end)
            path.addLine(to: wing(-.pi / 6))
        }
        .stroke(
            isSelected ? Color.accentColor : Color.secondary,
            style: StrokeStyle(lineWidth: isSelected ? 2 : 1, lineCap: .round, lineJoin: .round)
        )
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
