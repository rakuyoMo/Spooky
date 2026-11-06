import AppKit
import SpookyKit
import SwiftUI

// MARK: - DiffHunkView

/// 一个块的行号与正文共用逻辑选区，单击、拖动与 ⇧ 范围选择使用同一模型。
///
/// 块头归分节管理，正文用同一个文本区保留块内跨行的字符选择。
struct DiffHunkView: View {
    /// 带原始字节的块。
    let hunk: DiffHunk

    /// 主题、Tab 宽度与不可见字符设置。
    let style: TextStyle

    /// 两侧全文的语法片段；没有着色时为空。
    var syntax: DiffSyntax?

    /// 各修改行的行内高亮范围，键是块内行序号；在视图外按块算好，排版时只取用。
    var highlights: [Int: [Range<Int>]] = [:]

    /// 暂存侧显示取消暂存按钮。
    let staged: Bool

    /// 写入或重载期间不可操作。
    let enabled: Bool

    /// 历史复用相同主题和行布局，只读补丁不出现工作区写按钮。
    var readOnly = false

    /// 是否显示块头；Themes 页的 Diff 预览只显示各行。
    var showsHeader = true

    /// 当前宿主是否拥有独立文件滚动区域。
    var presentation = DiffPresentation.embedded

    /// 当前文件里上一条内容是另一个块的正文。
    var hasPrecedingHunk = false

    /// 当前有效的 Diff 着色开关，与语法片段是否已经读完无关。
    var colorsSyntax = false

    /// 工作区由会话按块原文提供模型，滚动复用不丢失选择。
    var selection: DiffLineSelection? = nil

    /// 把选区交给会话，确认和命令均在视图外执行。
    let apply: (Set<Int>, Bool) -> Void

    /// 正文的自然位置越过视口顶部时，块头处于浮动或被后块推挤的状态。
    @State
    private var isPinned = false

    /// 未绑定会话时的块内状态，不跨视图生命周期保存。
    @State
    private var localSelection = DiffLineSelection()

    /// 行号、正文与块头始终共享当前绑定的模型。
    private var lineSelection: DiffLineSelection { selection ?? localSelection }

    /// 常驻块头按钮随选择数量更新文案。
    var body: some View {
        Section {
            if showsHeader, presentation == .standalone {
                text.onGeometryChange(for: Bool.self) {
                    $0.frame(in: .scrollView(axis: .vertical)).minY - DiffHeaderBackground.height < 0
                } action: {
                    isPinned = $0
                }
            } else {
                text
            }
        } header: {
            if showsHeader {
                header
            }
        }
    }

    /// 正文只在独立文件模式参与吸顶检测，预览与内嵌模式不增加几何观察。
    private var text: some View {
        DiffHunkTextView(
            hunk: hunk,
            style: style,
            syntax: syntax,
            highlights: highlights,
            enabled: enabled && lineSelection.isActive,
            readOnly: readOnly,
            selection: lineSelection,
            colorsSyntax: colorsSyntax
        )
    }

    /// 块头原文与写入按钮。
    private var header: some View {
        HStack(spacing: 8) {
            Text(hunk.header)
                .font(.custom("Menlo", size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if !readOnly, hunk.combinedRanges == nil {
                if !staged {
                    Button(actionTitle("discard")) { apply(lineSelection.selected, true) }
                }

                Button(actionTitle(staged ? "unstage" : "stage")) { apply(lineSelection.selected, false) }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!enabled || !lineSelection.isActive)
        .padding(.horizontal, 20)
        .frame(height: DiffHeaderBackground.height)
        .background(DiffHeaderBackground(showsTopBorder: hasPrecedingHunk && !isPinned))
    }

    /// 没有选行时处理整块，否则使用单行或多行文案。
    func actionTitle(_ action: String) -> String {
        let suffix = lineSelection.publishedCount == 0 ? "Chunk" : (lineSelection.publishedCount == 1 ? "Line" : "Lines")
        return AppLocalization.text("working." + action + suffix)
    }

}
