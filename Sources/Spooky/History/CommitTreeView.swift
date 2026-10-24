import AppKit
import SpookyKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - CommitTreeState

/// 提交详情 Tree 页的状态：提交的整棵树逐层展开，每层只在展开时读取。
@MainActor
@Observable
final class CommitTreeState {
    /// 列表里可见的一行。
    struct Row: Identifiable {
        /// 树中的条目。
        let entry: TreeEntry

        /// 目录层级，根目录下为 0。
        let depth: Int

        /// 仓库内的路径作为行身份。
        var id: String { entry.path }
    }

    /// 正在显示的提交。
    private(set) var commit: String? = nil

    /// 已读取的各层条目，键是目录路径，根目录为空字符串。
    private(set) var children: [String: [TreeEntry]] = [:]

    /// 展开的目录。
    private(set) var expanded = Set<String>()

    /// 选中的条目路径。
    var selection = Set<String>()

    /// 读取失败保留可复制的诊断。
    private(set) var failure: AppFailure? = nil

    /// 按展开状态排成的可见行。
    var rows: [Row] {
        var rows: [Row] = []
        append(children[""] ?? [], depth: 0, to: &rows)
        return rows
    }

    /// 换成另一个提交时清空状态并读取根目录。
    func open(_ commit: HistoryCommit, runner: GitRunner) async {
        guard self.commit != commit.id else {
            return
        }

        self.commit = commit.id
        children = [:]
        expanded = []
        selection = []
        failure = nil
        await load(tree: commit.tree, directory: "", runner: runner)
    }

    /// 展开或收起目录；第一次展开时读取它的条目。
    func toggle(_ entry: TreeEntry, runner: GitRunner) async {
        guard entry.isDirectory else {
            return
        }

        if expanded.contains(entry.path) {
            expanded.remove(entry.path)
            return
        }

        expanded.insert(entry.path)

        if children[entry.path] == nil {
            await load(tree: entry.objectID, directory: entry.path, runner: runner)
        }
    }

    /// 读取一层条目；提交已切换时丢弃结果。
    private func load(tree: String, directory: String, runner: GitRunner) async {
        let commit = commit

        do {
            let entries = try await RepositoryFileViews(runner: runner).entries(ofTree: tree, in: directory)

            guard self.commit == commit, !Task.isCancelled else {
                return
            }

            children[directory] = entries
        } catch {
            guard self.commit == commit, !Task.isCancelled else {
                return
            }

            failure = AppFailure(error: error, opening: false, location: runner.location)
        }
    }

    /// 递归追加展开目录下的行。
    private func append(_ entries: [TreeEntry], depth: Int, to rows: inout [Row]) {
        for entry in entries {
            rows.append(Row(entry: entry, depth: depth))

            if entry.isDirectory, expanded.contains(entry.path) {
                append(children[entry.path] ?? [], depth: depth + 1, to: &rows)
            }
        }
    }
}

// MARK: - CommitTreeView

/// 提交的文件树：单列文件名，22 pt 行高、16 pt 缩进；右键查看、恢复、导出与归档所选条目。
struct CommitTreeView: View {
    /// 树的读取状态。
    @Bindable
    var tree: CommitTreeState

    /// 当前仓库会话。
    let session: RepositorySession

    /// 树所属的提交。
    let commit: HistoryCommit

    /// 根目录读取前显示进度，失败时可重试。
    var body: some View {
        Group {
            if let failure = tree.failure {
                FailureDetailsView(failure: failure) { Task { await reload() } }
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                List(tree.rows, selection: $tree.selection) { row in
                    rowView(row)
                        .tag(row.id)
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 22)
                .contextMenu(forSelectionType: String.self) { paths in
                    CommitTreeMenu(session: session, commit: commit, entries: entries(paths))
                } primaryAction: { paths in
                    open(paths)
                }
            }
        }
        .task(id: commit.id) {
            guard let runner = session.runner else {
                return
            }

            await tree.open(commit, runner: runner)
        }
    }

    /// 目录用文件夹图标，子模块用仓库图标，文件按扩展名取系统图标。
    private static func icon(for entry: TreeEntry) -> NSImage {
        if entry.isDirectory {
            return NSWorkspace.shared.icon(for: .folder)
        }

        if entry.isSubmodule {
            return NSImage(systemSymbolName: "shippingbox", accessibilityDescription: nil) ?? NSImage()
        }

        let type = UTType(filenameExtension: URL(fileURLWithPath: entry.path).pathExtension) ?? .data
        return NSWorkspace.shared.icon(for: type)
    }

    /// 一行：缩进、目录的展开按钮、图标与名称。
    private func rowView(_ row: CommitTreeState.Row) -> some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: CGFloat(row.depth) * 16, height: 1)

            if row.entry.isDirectory {
                Button {
                    open([row.id])
                } label: {
                    Image(systemName: tree.isExpanded(row.entry) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 12)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(AppLocalization.text(tree.isExpanded(row.entry) ? "tree.collapse" : "tree.expand"))
            } else {
                Color.clear.frame(width: 12, height: 1)
            }

            Image(nsImage: Self.icon(for: row.entry))
                .resizable()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(RepositorySession.fileName(row.entry.path))
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .help(row.entry.path)
    }

    /// 双击或点展开按钮时切换目录；文件不做处理。
    private func open(_ paths: Set<String>) {
        guard
            paths.count == 1,
            let entry = entries(paths).first, entry.isDirectory,
            let runner = session.runner
        else { return }

        Task { await tree.toggle(entry, runner: runner) }
    }

    /// 按列表顺序取出所选的条目。
    private func entries(_ paths: Set<String>) -> [TreeEntry] {
        tree.rows.map(\.entry).filter { paths.contains($0.path) }
    }

    /// 重新读取根目录。
    private func reload() async {
        guard let runner = session.runner else {
            return
        }

        await tree.reopen(commit, runner: runner)
    }
}

// MARK: - CommitTreeState Helpers

extension CommitTreeState {
    /// 目录是否展开。
    func isExpanded(_ entry: TreeEntry) -> Bool {
        expanded.contains(entry.path)
    }

    /// 读取失败后重试：清空记录的提交再打开。
    func reopen(_ commit: HistoryCommit, runner: GitRunner) async {
        self.commit = nil
        await open(commit, runner: runner)
    }
}
