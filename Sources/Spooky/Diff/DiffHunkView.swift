import AppKit
import SpookyKit
import SwiftUI

// MARK: - DiffHunkView

/// 一块文本独立保存行号选区，单击、拖动与 ⇧ 范围选择共用同一规则。
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

    /// 把选区交给会话，确认和命令均在视图外执行。
    let apply: (Set<Int>, Bool) -> Void

    /// 仅包含增删行序号的选区。
    @State
    private var selected: Set<Int> = []

    /// 常驻块头按钮随选择数量更新文案。
    var body: some View {
        Section {
            DiffHunkTextView(
                hunk: hunk,
                style: style,
                syntax: syntax,
                highlights: highlights,
                enabled: enabled,
                readOnly: readOnly,
                selected: $selected
            )
        } header: {
            if showsHeader {
                header
            }
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

    /// 没有选行时处理整块，否则使用单行或多行文案。
    private func actionTitle(_ action: String) -> String {
        let suffix = selected.isEmpty ? "Chunk" : (selected.count == 1 ? "Line" : "Lines")
        return AppLocalization.text("working." + action + suffix)
    }

}
