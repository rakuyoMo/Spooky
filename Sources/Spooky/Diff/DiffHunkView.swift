import AppKit
import SpookyKit
import SwiftUI

// MARK: - DiffHunkView

/// 一块文本独立保存行号选区，单击、拖动与 ⇧ 范围选择共用同一规则。
///
/// 块头是分节头，行直接放进分节内容，放在懒加载栈里时只排版可见的行，显示整个文件也能流畅滚动。
struct DiffHunkView: View {
    /// 行号拖选使用的坐标系，由外层的懒加载栈提供。
    nonisolated static let coordinateSpace = "diff-content"

    /// 带原始字节的块。
    let hunk: DiffHunk

    /// 主题、Tab 宽度与不可见字符设置。
    let style: TextStyle

    /// 按行取语法片段；没有着色时为空。
    var spans: (DiffLine) -> [SyntaxSpan]? = { _ in nil }

    /// 暂存侧显示取消暂存按钮。
    let staged: Bool

    /// 写入或重载期间不可操作。
    let enabled: Bool

    /// 历史复用相同主题和行布局，只读补丁不出现工作区写按钮。
    var readOnly = false

    /// 把选区交给会话，确认和命令均在视图外执行。
    let apply: (Set<Int>, Bool) -> Void

    /// 仅包含增删行序号的选区。
    @State
    private var selected: Set<Int> = []

    /// ⇧ 范围选择的锚点。
    @State
    private var anchor: Int?

    /// 拖动开始时固定为选中或取消，后续经过各行不反复切换。
    @State
    private var dragSelecting: Bool?

    /// 已排版行的行号区域，坐标属于外层懒加载栈。
    @State
    private var rowFrames: [Int: CGRect] = [:]

    /// 常驻块头按钮随选择数量更新文案。
    var body: some View {
        Section {
            ForEach(rows) { item in
                // 每行与它的无换行提示合成一个视图：懒加载栈里一个元素展开成多个视图时，分节的第一行不会显示
                VStack(alignment: .leading, spacing: 0) {
                    row(item.line)

                    if item.line.noNewline {
                        Text(AppLocalization.text("working.noNewline"))
                            .font(style.font)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 88)
                    }
                }
            }
        } header: {
            header
        }
    }

    /// 各行与它们在整个补丁里的身份。
    private var rows: [HunkRow] {
        hunk.lines.map { line in
            HunkRow(id: HunkRow.ID(oldStart: hunk.oldStart, newStart: hunk.newStart, index: line.id), line: line)
        }
    }

    /// 块头原文与写入按钮。
    private var header: some View {
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

    /// 一行：行号、正文、改动底色，以及连续改动首尾的描边。
    private func row(_ line: DiffLine) -> some View {
        HStack(alignment: .top, spacing: 0) {
            gutter(line)

            Text(
                TextLineRenderer.attributed(
                    String(decoding: line.content, as: UTF8.self),
                    spans: spans(line),
                    style: style
                )
            )
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
        }
        .font(style.font)
        .foregroundStyle(style.textColor)
        .frame(minHeight: 18)
        .background(changeColor(line).map { style.color($0) } ?? .clear)
        .overlay(alignment: .top) { edge(line, before: true) }
        .overlay(alignment: .bottom) { edge(line, before: false) }
    }

    /// 连续同类改动的首行顶边与末行底边，颜色是改动底色加深 0.25 的不透明度。
    @ViewBuilder
    private func edge(_ line: DiffLine, before: Bool) -> some View {
        let neighbor = hunk.lines.indices.contains(line.id + (before ? -1 : 1))
            ? hunk.lines[line.id + (before ? -1 : 1)].prefix
            : nil

        if let key = changeColor(line), neighbor != line.prefix, let color = style.theme.colors[key] {
            PaletteColor(hex: color.hex, alpha: min(1, color.alpha + 0.25)).color
                .frame(height: 1)
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
        .foregroundStyle(
            selected.contains(line.id)
                ? Color(nsColor: .alternateSelectedControlTextColor)
                : .secondary
        )
        .contentShape(Rectangle())
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.coordinateSpace))
        } action: { frame in
            rowFrames[line.id] = frame
        }
        .onTapGesture { select(line.id, range: NSEvent.modifierFlags.contains(.shift)) }
        .gesture(dragGesture(from: line))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text("working.selectLine", line.oldNumber ?? line.newNumber ?? 0))
        .accessibilityAddTraits(line.isChange && !readOnly ? .isButton : [])
        .accessibilityValue(selected.contains(line.id) ? AppLocalization.text("working.selected") : "")
        .accessibilityAction { select(line.id, range: false) }
        .focusable(line.isChange && !readOnly)
        .allowsHitTesting(!readOnly)
        .onKeyPress(.space) {
            select(line.id, range: false)
            return .handled
        }
    }

    /// 按下那一行决定一路选中还是一路取消，经过的改动行随之变化。
    private func dragGesture(from line: DiffLine) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.coordinateSpace))
            .onChanged { value in
                guard enabled, line.isChange else { return }

                if dragSelecting == nil {
                    dragSelecting = !selected.contains(line.id)
                    anchor = line.id
                }

                guard
                    let end = rowFrames.first(where: {
                        $0.value.minY <= value.location.y && $0.value.maxY >= value.location.y
                    })?.key
                else { return }

                let range = min(line.id, end) ... max(line.id, end)

                for item in hunk.lines where item.isChange && range.contains(item.id) {
                    if dragSelecting ?? false {
                        selected.insert(item.id)
                    } else {
                        selected.remove(item.id)
                    }
                }
            }
            .onEnded { _ in dragSelecting = nil }
    }

    /// 单击切换，⇧ 单击选中锚点与当前行之间的全部改动行。
    private func select(_ id: Int, range: Bool) {
        guard enabled, hunk.lines.contains(where: { $0.id == id && $0.isChange }) else { return }

        if range, let anchor {
            let lines = min(anchor, id) ... max(anchor, id)

            for line in hunk.lines where line.isChange && lines.contains(line.id) {
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
        let suffix = selected.isEmpty ? "Chunk" : (selected.count == 1 ? "Line" : "Lines")
        return AppLocalization.text("working." + action + suffix)
    }

    /// 改动行的主题颜色键，上下文行没有底色。
    private func changeColor(_ line: DiffLine) -> String? {
        switch line.prefix {
        case 43: "added"
        case 45: "deleted"
        default: nil
        }
    }
}

// MARK: - HunkRow

/// 块里的一行与它在整个补丁里的身份。
///
/// 懒加载栈把各块的行排在同一层，只用块内序号作身份时，后面的块里序号相同的行不会显示。
private struct HunkRow: Identifiable {
    /// 块两侧的起点加块内序号；同一补丁里不同块的两侧起点不会都相同。
    struct ID: Hashable {
        /// 块的旧版起点。
        let oldStart: Int

        /// 块的新版起点。
        let newStart: Int

        /// 块内序号。
        let index: Int
    }

    /// 补丁内唯一的身份。
    let id: ID

    /// 这一行。
    let line: DiffLine
}
