import AppKit
import SpookyKit
import SwiftUI

// MARK: - CommitSelectorView

/// 整页提交详情的版本选择器：上面是搜索框，下面是从 HEAD 起的提交列表。
///
/// 打开时高亮 HEAD；单击与 ↑ ↓ 只移动高亮，回车不换，双击一行才换到那个提交，Esc 关闭。
struct CommitSelectorView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 双击选定一个提交。
    let select: (HistoryCommit) -> Void

    /// 关闭弹出框。
    @Environment(\.dismiss)
    private var dismiss

    /// 提交列表的读取状态。
    @State
    private var state = CommitSelectorState()

    /// 480 × 272：距上、左、右 20 pt 的搜索框，下面 8 pt 是贴满宽度的列表。
    var body: some View {
        VStack(spacing: 8) {
            CommitSelectorSearchField(
                onChange: { state.search($0) },
                onMove: { state.moveHighlight(by: $0) },
                onCancel: { dismiss() }
            )
            .frame(height: 24)
            .padding([.top, .horizontal], 20)

            list
                .frame(height: 220)
        }
        .frame(width: 480, height: 272)
        .onAppear { state.open(runner: session.runner, head: session.status?.branch.oid) }
        .onDisappear { state.close() }
    }

    /// 提交列表；读取失败时显示诊断与重试。高亮移动时滚到高亮的行。
    @ViewBuilder
    private var list: some View {
        if let failure = state.failure {
            FailureDetailsView(failure: failure) { state.reload() }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(state.commits) { commit in
                            row(commit)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .onChange(of: state.highlightedID) { _, id in
                    if let id {
                        proxy.scrollTo(id)
                    }
                }
            }
            .overlay {
                if state.isLoading, state.commits.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    /// 一行提交：单击高亮，双击选定；显示到最后一行时续载。
    private func row(_ commit: HistoryCommit) -> some View {
        CommitSelectorRow(commit: commit, highlighted: commit.id == state.highlightedID)
            .id(commit.id)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { select(commit) }
            .simultaneousGesture(TapGesture().onEnded { state.highlightedID = commit.id })
            .onAppear { loadMoreIfLast(commit) }
    }

    /// 列表显示到最后一行时续载下一页。
    private func loadMoreIfLast(_ commit: HistoryCommit) {
        if commit.id == state.commits.last?.id {
            state.loadNextPage()
        }
    }
}

// MARK: - CommitSelectorRow

/// 版本选择器的一行：32 pt 头像，右边上行是作者与日期，下行是短哈希与标题。
///
/// 高亮行是左右各内缩 10 pt、圆角 6 pt 的强调色底，文字反白；焦点在搜索框里时同样如此。
private struct CommitSelectorRow: View {
    /// 高亮行的文字使用系统的选中文字语义色。
    private static let highlightedText = Color(nsColor: .alternateSelectedControlTextColor)

    /// 这一行的提交。
    let commit: HistoryCommit

    /// 是否是高亮的行。
    let highlighted: Bool

    /// 提交日期的显示格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 38 pt 高的两行布局，文字都是 11 pt。
    var body: some View {
        HStack(spacing: 6) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(commit.author)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(dateFormat.string(from: commit.commitDate))
                        .lineLimit(1)
                }
                .foregroundStyle(highlighted ? Self.highlightedText : .secondary)

                HStack(spacing: 4) {
                    Text(commit.shortID)
                        .font(.custom("Menlo", size: 11))
                        .foregroundStyle(highlighted ? Self.highlightedText : .secondary)

                    Text(commit.subject)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .font(.system(size: 11))
        }
        .frame(height: 38)
        .padding(.horizontal, 10)
        .foregroundStyle(highlighted ? Self.highlightedText : .primary)
        .background {
            if highlighted {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .selectedContentBackgroundColor))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(highlighted ? .isSelected : [])
    }
}

// MARK: - CommitSelectorSearchField

/// 版本选择器的系统搜索框：13 pt、不画焦点环，占位是系统的 “Search”，打开时取得焦点。
///
/// 每次输入与清除都写回；↑ ↓ 移动高亮，Esc 关闭选择器，回车什么都不做。
private struct CommitSelectorSearchField: NSViewRepresentable {
    /// 搜索框的协调者：接收输入与按键。
    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        /// 写回搜索内容。
        var onChange: (String) -> Void = { _ in }

        /// 移动高亮，参数是移动的行数。
        var onMove: (Int) -> Void = { _ in }

        /// 关闭选择器。
        var onCancel: () -> Void = { }

        /// 键入与点清除按钮都经动作写回。
        @objc
        func textChanged(_ sender: NSSearchField) {
            onChange(sender.stringValue)
        }

        /// ↑ ↓ 与 Esc 交给选择器；回车不换提交，吞掉；其余按键照常编辑。
        func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                onMove(-1)

            case #selector(NSResponder.moveDown(_:)):
                onMove(1)

            case #selector(NSResponder.cancelOperation(_:)):
                onCancel()

            case #selector(NSResponder.insertNewline(_:)):
                break

            default:
                return false
            }

            return true
        }
    }

    /// 搜索内容改变后写回。
    let onChange: (String) -> Void

    /// 按 ↑ ↓ 移动高亮。
    let onMove: (Int) -> Void

    /// 按 Esc 关闭选择器。
    let onCancel: () -> Void

    /// 建立协调者。
    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 每次输入都立即发出动作的搜索框；进入弹出框的窗口后取得焦点。
    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.font = .systemFont(ofSize: 13)
        field.focusRingType = .none
        field.sendsSearchStringImmediately = true
        field.target = context.coordinator
        field.action = #selector(Coordinator.textChanged(_:))
        field.delegate = context.coordinator

        // 视图这时还没有放进弹出框的窗口，等下一轮再取得焦点
        Task { @MainActor [weak field] in
            field?.window?.makeFirstResponder(field)
        }

        return field
    }

    /// 同步写回与按键的动作。
    func updateNSView(_: NSSearchField, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onMove = onMove
        context.coordinator.onCancel = onCancel
    }
}
