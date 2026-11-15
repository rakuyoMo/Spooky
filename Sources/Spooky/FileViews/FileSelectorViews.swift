import SpookyKit
import SwiftUI

// MARK: - FileSelectorView

/// 文件选择器：上面是搜索框，打开时列表为空，输入后列出这个版本里路径匹配的文件。
///
/// 高亮默认是第一项；单击与 ↑ ↓ 只移动高亮，回车不换，双击一行才换到那个文件，Esc 关闭。
struct FileSelectorView: View {
    /// 列表最多显示的条数，过滤后仍然太多时请用户继续输入。
    private static let limit = 500

    /// 高亮行的文字使用系统的选中文字语义色。
    private static let highlightedText = Color(nsColor: .alternateSelectedControlTextColor)

    /// 当前仓库会话。
    let session: RepositorySession

    /// 列出这个版本里的文件。
    let revision: String?

    /// 双击选定一个文件。
    let select: (String) -> Void

    /// 关闭弹出框。
    @Environment(\.dismiss)
    private var dismiss

    /// 版本中的文件路径。
    @State
    private var paths: [String] = []

    /// 搜索框的内容。
    @State
    private var query = ""

    /// 单击或方向键移到的行；不在当前结果里时高亮第一项。
    @State
    private var highlighted: String?

    /// 是否正在读取。
    @State
    private var isLoading = true

    /// 读取失败的诊断。
    @State
    private var failure: AppFailure?

    /// 按搜索内容过滤后的路径；没有输入时为空，最多显示前面的一部分。
    private var filtered: [String] {
        let query = query.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            return []
        }

        return Array(paths.lazy.filter { $0.localizedCaseInsensitiveContains(query) }.prefix(Self.limit))
    }

    /// 与版本选择器同样大小：上面是搜索框，下面是文件列表。
    var body: some View {
        VStack(spacing: 8) {
            SelectorSearchField(
                onChange: { query = $0 },
                onMove: { moveHighlight(by: $0) },
                onCancel: { dismiss() }
            )
            .frame(height: 24)
            .padding([.top, .horizontal], 20)

            list
                .frame(height: 220)
        }
        .frame(width: 480, height: 272)
        .task { await load() }
    }

    /// 文件列表，顶上留 10 pt；读取失败时显示诊断与重试。高亮移动时滚到高亮的行。
    @ViewBuilder
    private var list: some View {
        if let failure {
            FailureDetailsView(failure: failure) { Task { await load() } }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            let rows = filtered
            let current = current(in: rows)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows, id: \.self) {
                            row($0, isHighlighted: $0 == current)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                }
                .onChange(of: highlighted) { _, path in
                    if let path {
                        proxy.scrollTo(path)
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    /// 一行：文件类型图标与路径；单击高亮，双击选定。
    private func row(_ path: String, isHighlighted: Bool) -> some View {
        HStack(spacing: 6) {
            Image(nsImage: WorkingCopyFileHeader.icon(path: path, isFolder: false))
                .resizable()
                .frame(width: 16, height: 16)

            Text(path)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .frame(height: 24)
        .padding(.horizontal, 10)
        .foregroundStyle(isHighlighted ? Self.highlightedText : .primary)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .selectedContentBackgroundColor))
            }
        }
        .id(path)
        .contentShape(Rectangle())
        .help(path)
        .onTapGesture(count: 2) { select(path) }
        .simultaneousGesture(TapGesture().onEnded { highlighted = path })
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    /// 当前结果里高亮的行：移到过的行还在结果里就是它，否则是第一项。
    private func current(in rows: [String]) -> String? {
        guard let highlighted, rows.contains(highlighted) else {
            return rows.first
        }

        return highlighted
    }

    /// 按 ↑ ↓ 在当前结果里移动高亮，停在首尾。
    private func moveHighlight(by offset: Int) {
        let rows = filtered

        guard let current = current(in: rows), let index = rows.firstIndex(of: current) else {
            return
        }

        highlighted = rows[min(max(index + offset, 0), rows.count - 1)]
    }

    /// 读取版本中的全部文件；子模块不是可查看的文件，不列出。
    private func load() async {
        failure = nil
        isLoading = true
        defer { isLoading = false }

        guard let runner = session.runner, let revision = revision ?? session.status?.branch.oid else {
            paths = []
            return
        }

        do {
            paths = try await RepositoryFileViews(runner: runner).files(in: revision)
                .filter { !$0.isSubmodule }
                .map(\.path)
        } catch {
            failure = AppFailure(error: error, opening: false, location: runner.location)
        }
    }
}
