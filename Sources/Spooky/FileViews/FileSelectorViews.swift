import SpookyKit
import SwiftUI

// MARK: - RevisionSelectorView

/// 版本选择器：HEAD 与修改过这个文件的提交，可按哈希、标题或作者过滤。
struct RevisionSelectorView: View {
    /// 代表 “跟随 HEAD” 的选择标识，不会与提交哈希相同。
    private static let head = "HEAD"

    /// 当前仓库会话。
    let session: RepositorySession

    /// 列出这个文件的历史。
    let path: String

    /// 选定一个版本；nil 表示跟随 HEAD。
    let select: (String?) -> Void

    /// 修改过这个文件的提交，第一页。
    @State
    private var commits: [HistoryCommit] = []

    /// 搜索框的内容。
    @State
    private var query = ""

    /// 列表中的选择。
    @State
    private var selection: String?

    /// 是否正在读取。
    @State
    private var isLoading = true

    /// 读取失败的诊断。
    @State
    private var failure: AppFailure?

    /// 按搜索内容过滤后的提交。
    private var filtered: [HistoryCommit] {
        let query = query.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            return commits
        }

        return commits.filter {
            $0.id.hasPrefix(query.lowercased())
                || $0.subject.localizedCaseInsensitiveContains(query)
                || $0.author.localizedCaseInsensitiveContains(query)
        }
    }

    /// 顶部搜索框，下面是 HEAD 与提交列表。
    var body: some View {
        VStack(spacing: 0) {
            TextField(AppLocalization.text("showFile.searchRevisions"), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(8)

            Divider()

            if let failure {
                FailureDetailsView(failure: failure) { Task { await load() } }
                    .padding(12)
            } else {
                List(selection: $selection) {
                    Text(Self.head)
                        .font(.system(size: 12, design: .monospaced))
                        .tag(Self.head)

                    ForEach(filtered) { commit in
                        row(commit).tag(commit.id)
                    }
                }
                .overlay {
                    if isLoading { ProgressView().controlSize(.small) }
                }
            }
        }
        .frame(width: 380, height: 320)
        .task { await load() }
        .onChange(of: selection) {
            guard let selection else { return }

            select(selection == Self.head ? nil : selection)
        }
    }

    /// 一个提交：短哈希、标题与日期。
    private func row(_ commit: HistoryCommit) -> some View {
        HStack(spacing: 8) {
            Text(commit.shortID)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(commit.subject)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            Text(commit.commitDate.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
    }

    /// 从当前 HEAD 读取修改过这个文件的第一页提交。
    private func load() async {
        failure = nil
        isLoading = true
        defer { isLoading = false }

        guard let runner = session.runner, let head = session.status?.branch.oid else {
            commits = []
            return
        }

        do {
            commits = try await RepositoryFileViews(runner: runner).page(of: path, from: head).commits
        } catch {
            failure = AppFailure(error: error, opening: false, location: runner.location)
        }
    }
}

// MARK: - FileSelectorView

/// 文件选择器：某个版本里的全部文件，按路径过滤。
struct FileSelectorView: View {
    /// 列表最多显示的条数，过滤后仍然太多时请用户继续输入。
    private static let limit = 500

    /// 当前仓库会话。
    let session: RepositorySession

    /// 列出这个版本里的文件。
    let revision: String?

    /// 选定一个文件。
    let select: (String) -> Void

    /// 版本中的文件路径。
    @State
    private var paths: [String] = []

    /// 搜索框的内容。
    @State
    private var query = ""

    /// 列表中的选择。
    @State
    private var selection: String?

    /// 是否正在读取。
    @State
    private var isLoading = true

    /// 读取失败的诊断。
    @State
    private var failure: AppFailure?

    /// 按搜索内容过滤后的路径，最多显示前面的一部分。
    private var filtered: [String] {
        let query = query.trimmingCharacters(in: .whitespaces)
        let matched = query.isEmpty ? paths : paths.filter { $0.localizedCaseInsensitiveContains(query) }

        return Array(matched.prefix(Self.limit))
    }

    /// 顶部搜索框，下面是文件列表。
    var body: some View {
        VStack(spacing: 0) {
            TextField(AppLocalization.text("showFile.searchFiles"), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(8)

            Divider()

            if let failure {
                FailureDetailsView(failure: failure) { Task { await load() } }
                    .padding(12)
            } else {
                List(filtered, id: \.self, selection: $selection) { path in
                    Label(path, systemImage: "doc")
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(path)
                }
                .overlay {
                    if isLoading { ProgressView().controlSize(.small) }
                }
            }
        }
        .frame(width: 380, height: 320)
        .task { await load() }
        .onChange(of: selection) {
            guard let selection else { return }

            select(selection)
        }
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
