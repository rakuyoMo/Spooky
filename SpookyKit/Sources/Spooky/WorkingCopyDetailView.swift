import AppKit
import SpookyKit
import SwiftUI

/// 单文件详情按暂存侧显示 Diff，冲突与多选使用独立内容状态。
struct WorkingCopyDetailView: View {
    /// 当前仓库的选择和补丁快照。
    @Bindable var session: RepositorySession

    /// 文件头、比较侧和可访问的内容状态。
    var body: some View {
        if let entry = session.selectedEntry {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                        .font(.system(size: 24))
                        .accessibilityHidden(true)
                    Text(entry.path)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(entry.path)
                    Spacer(minLength: 0)

                    if entry.kind != .conflicted {
                        DiffSidePicker(
                            side: $session.diffSide,
                            staged: entry.hasStagedChanges,
                            unstaged: entry.hasUnstagedChanges
                        )
                        .frame(width: 170)
                    }
                }
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(AppPalette.color("general_header_background_color"))
                Divider()

                content(entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onChange(of: session.diffSide) { session.loadDiff() }
        } else {
            VStack(spacing: 16) {
                EmptyStateView(
                    title: AppLocalization.text(session.selectedIDs.count > 1 ? "working.multiple" : "detail.empty.title"),
                    message: "",
                    symbol: "doc"
                )

                if session.selectedIDs.count > 1 {
                    Button(AppLocalization.text("working.discard")) { session.discard(session.selectedEntries) }
                        .disabled(!session.canWrite)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 内容错误可复制，超限提示只为当前文件提供完整加载入口。
    @ViewBuilder
    private func content(_ entry: StatusEntry) -> some View {
        if entry.kind == .conflicted {
            VStack(spacing: 16) {
                Label(AppLocalization.text("status.conflicted"), systemImage: "exclamationmark.triangle")
                Button(AppLocalization.text("working.ours")) { session.resolve([entry], theirs: false) }
                Button(AppLocalization.text("working.theirs")) { session.resolve([entry], theirs: true) }
                Button(AppLocalization.text("working.resolved")) { session.stage([entry], staged: true) }
            }
            .disabled(!session.canWrite)
        } else if let failure = session.diffFailure {
            VStack(spacing: 12) {
                Text(failure.title).font(.headline)
                Text(failure.message)
                ScrollView { Text(failure.details).textSelection(.enabled).font(.system(size: 11, design: .monospaced)) }
                Button(AppLocalization.text("action.refresh")) { session.loadDiff() }
            }
            .padding(20)
        } else if let snapshot = session.diffSnapshot {
            if let diff = snapshot.diff {
                DiffContentView(session: session, snapshot: snapshot, diff: diff)
                    .id(snapshot.fingerprint)
            } else {
                VStack(spacing: 16) {
                    Text(AppLocalization.text("working.largeDiff", snapshot.byteCount / 1000))
                    Button(AppLocalization.text("working.showDiff")) {
                        session.showsLargeDiff = true
                        session.loadDiff()
                    }
                    .disabled(session.isLoadingDiff)
                }
            }
        } else if session.isLoadingDiff {
            ProgressView(AppLocalization.text("working.loadingDiff"))
        } else {
            Text(AppLocalization.text("working.noDiff"))
                .foregroundStyle(.secondary)
        }
    }
}

/// AppKit 分段控件可以分别禁用没有改动的一侧。
private struct DiffSidePicker: NSViewRepresentable {
    /// 当前暂存侧。
    @Binding var side: DiffSide

    /// 暂存侧是否可用。
    let staged: Bool

    /// 工作区侧是否可用。
    let unstaged: Bool

    /// 分段动作桥接。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 保持 Staged、Unstaged 的固定顺序。
    func makeNSView(context: Context) -> NSSegmentedControl {
        NSSegmentedControl(
            labels: [AppLocalization.text("working.staged"), AppLocalization.text("working.unstaged")],
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.changed(_:))
        )
    }

    /// 刷新后没有内容的一侧立即禁用。
    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        control.selectedSegment = side == .staged ? 0 : 1
        control.setEnabled(staged, forSegment: 0)
        control.setEnabled(unstaged, forSegment: 1)
        control.setAccessibilityLabel(AppLocalization.text("working.diffSide"))
    }

    /// 分段选择只更新模型，由详情发起异步读取。
    @MainActor
    final class Coordinator: NSObject {
        /// 最新绑定。
        var parent: DiffSidePicker

        /// 保存初始绑定。
        init(_ parent: DiffSidePicker) { self.parent = parent }

        /// 原生选择转换为比较方向。
        @objc func changed(_ sender: NSSegmentedControl) {
            parent.side = sender.selectedSegment == 0 ? .staged : .unstaged
        }
    }
}

/// 单列表 Diff 以吸顶块头和可换行正文展示，底栏显示增删统计。
private struct DiffContentView: View {
    /// 写操作使用所属会话。
    let session: RepositorySession

    /// 当前可写快照。
    let snapshot: DiffSnapshot

    /// 已解析的文件段。
    let diff: RepositoryDiff

    /// 内置主题随系统外观切换。
    @Environment(\.colorScheme) private var colorScheme

    /// 文本区与摘要共享同一组块数据。
    var body: some View {
        let theme = BuiltinTheme.current(dark: colorScheme == .dark)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(diff.files) { file in
                    Text(file.headers.joined(separator: "\n"))
                        .font(.custom(theme.fontName, size: theme.fontSize))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                    if file.isBinary {
                        Text(AppLocalization.text("working.binary"))
                            .padding(20)
                    } else if file.hunks.isEmpty {
                        Text(AppLocalization.text("working.noDiff"))
                            .padding(20)
                    }

                    ForEach(file.hunks) { hunk in
                        DiffHunkView(
                            hunk: hunk,
                            theme: theme,
                            staged: snapshot.side == .staged,
                            enabled: session.canWrite && !session.isLoadingDiff && diff.files.count == 1
                        ) { lines, discard in
                            session.apply(file: file.id, hunk: hunk.id, lines: lines, discard: discard)
                        }
                    }
                }
            }
        }
        .background(theme.colors["background"]!.color)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            let lines = diff.files.flatMap(\.hunks).flatMap(\.lines)
            HStack {
                if session.isLoadingDiff { ProgressView().controlSize(.mini) }
                Text(AppLocalization.text(
                    "working.diffSummary",
                    diff.files.flatMap(\.hunks).count,
                    lines.filter { $0.prefix == 43 }.count,
                    lines.filter { $0.prefix == 45 }.count
                ))
                Spacer(minLength: 0)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(.bar)
        }
    }
}

/// 一块文本独立保存行号选区，单击、拖动与 ⇧ 范围选择共用同一规则。
struct DiffHunkView: View {
    /// 带原始字节的块。
    let hunk: DiffHunk

    /// 当前内置主题。
    let theme: BuiltinTheme

    /// 暂存侧显示取消暂存按钮。
    let staged: Bool

    /// 写入或重载期间不可操作。
    let enabled: Bool

    /// 历史复用相同主题和行布局，只读补丁不出现工作区写按钮。
    var readOnly = false

    /// 把选区交给会话，确认和命令均在视图外执行。
    let apply: (Set<Int>, Bool) -> Void

    /// 仅包含增删行序号的选区。
    @State private var selected: Set<Int> = []

    /// ⇧ 范围选择的锚点。
    @State private var anchor: Int?

    /// 拖动开始时固定为选中或取消，后续经过各行不反复切换。
    @State private var dragSelecting: Bool?

    /// 行号区域在块坐标系中的位置。
    @State private var rowFrames: [Int: CGRect] = [:]

    /// 每块独立的手势坐标系。
    @State private var coordinateID = UUID()

    /// 常驻块头按钮随选择数量更新文案。
    var body: some View {
        Section {
            VStack(spacing: 0) {
                ForEach(hunk.lines) { line in
                    HStack(alignment: .top, spacing: 0) {
                        gutter(line)
                        Text(String(decoding: line.content, as: UTF8.self))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                    }
                    .font(.custom(theme.fontName, size: theme.fontSize))
                    .foregroundStyle(theme.colors["text"]!.color)
                    .frame(minHeight: 18)
                    .background(
                        line.prefix == 43
                            ? theme.colors["added"]!.color
                            : (line.prefix == 45 ? theme.colors["deleted"]!.color : .clear)
                    )

                    if line.noNewline {
                        Text(AppLocalization.text("working.noNewline"))
                            .font(.custom(theme.fontName, size: theme.fontSize))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 88)
                    }
                }
            }
            .coordinateSpace(name: coordinateID)
            .onPreferenceChange(DiffRowFrames.self) { rowFrames = $0 }
        } header: {
            HStack(spacing: 8) {
                Text(hunk.header)
                    .font(.custom("Menlo", size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if !readOnly {
                    if !staged {
                        Button(actionTitle("discard")) { apply(selected, true) }
                    }
                    Button(actionTitle(staged ? "unstage" : "stage")) { apply(selected, false) }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!enabled)
            .padding(.horizontal, 20)
            .frame(height: 32)
            .background(.bar)
        }
    }

    /// 行号独立接管鼠标，正文仍可选择复制而不改变补丁选区。
    private func gutter(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            Text(line.oldNumber.map(String.init) ?? "").frame(width: 38, alignment: .trailing)
            Text(line.newNumber.map(String.init) ?? "").frame(width: 38, alignment: .trailing)
        }
        .padding(.trailing, 4)
        .frame(minHeight: 18)
        .background(selected.contains(line.id) ? Color.accentColor : .clear)
        .foregroundStyle(selected.contains(line.id) ? .white : .secondary)
        .contentShape(Rectangle())
        .background(GeometryReader { proxy in
            Color.clear.preference(key: DiffRowFrames.self, value: [line.id: proxy.frame(in: .named(coordinateID))])
        })
        .onTapGesture { select(line.id, range: NSEvent.modifierFlags.contains(.shift)) }
        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named(coordinateID))
            .onChanged { value in
                guard enabled, line.isChange else { return }
                if dragSelecting == nil { dragSelecting = !selected.contains(line.id); anchor = line.id }
                guard let end = rowFrames.first(where: {
                    $0.value.minY <= value.location.y && $0.value.maxY >= value.location.y
                })?.key else { return }
                for item in hunk.lines where item.isChange && (min(line.id, end)...max(line.id, end)).contains(item.id) {
                    if dragSelecting == true { selected.insert(item.id) }
                    else { selected.remove(item.id) }
                }
            }
            .onEnded { _ in dragSelecting = nil })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text("working.selectLine", line.oldNumber ?? line.newNumber ?? 0))
        .accessibilityAddTraits(line.isChange && !readOnly ? .isButton : [])
        .accessibilityValue(selected.contains(line.id) ? AppLocalization.text("working.selected") : "")
        .accessibilityAction { select(line.id, range: false) }
        .focusable(line.isChange && !readOnly)
        .allowsHitTesting(!readOnly)
        .onKeyPress(.space) { select(line.id, range: false); return .handled }
    }

    /// 单击切换，⇧ 单击选中锚点与当前行之间的全部改动行。
    private func select(_ id: Int, range: Bool) {
        guard enabled, hunk.lines.contains(where: { $0.id == id && $0.isChange }) else { return }
        if range, let anchor {
            for line in hunk.lines where line.isChange && (min(anchor, id)...max(anchor, id)).contains(line.id) {
                selected.insert(line.id)
            }
        } else if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
        anchor = id
    }

    /// 没有选行时处理整块，否则使用单行或多行文案。
    private func actionTitle(_ action: String) -> String {
        AppLocalization.text("working." + action + (selected.isEmpty ? "Chunk" : (selected.count == 1 ? "Line" : "Lines")))
    }
}

/// 逐行几何信息仅用于行号拖选。
private struct DiffRowFrames: PreferenceKey {
    /// 块首次布局前没有行坐标。
    static let defaultValue: [Int: CGRect] = [:]

    /// 合并当前块内所有可见行的矩形。
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
