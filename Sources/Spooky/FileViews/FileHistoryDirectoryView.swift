import SpookyKit
import SwiftUI

// MARK: - FileHistoryDirectoryView

/// 目录历史按真实文件展示全部改动，每项使用自己的只读补丁来源。
struct FileHistoryDirectoryView: View {
    /// 动作与可用性所属的仓库会话。
    let session: RepositorySession

    /// 当前目录详情的读取状态。
    let state: FileHistoryDirectoryState

    /// 外层负责滚动，文件行出现时才开始读取。
    var body: some View {
        let identity = state.identity

        LazyVStack(spacing: 0) {
            if let commit = state.commit {
                ForEach(state.files) { file in
                    VStack(spacing: 0) {
                        CommitFileLabel(file: file)
                            .padding(.horizontal, 20)
                            .frame(height: 32)
                            .background(.bar)
                            .contextMenu {
                                ChangesetFileMenu(
                                    session: session,
                                    path: file.path,
                                    originalPath: file.originalPath,
                                    commit: commit,
                                    contentEnabled: session.canReadFileHistory(state.targets[file.path])
                                )
                            }

                        fileContent(file)
                    }
                    .onAppear { state.setVisible(file.path, visible: true, identity: identity) }
                    .onDisappear { state.setVisible(file.path, visible: false, identity: identity) }
                }
            }
        }
        .id(identity)
    }

    /// 单文件失败不隐藏其它结果，Show Diff 与 Retry 只替换这一项。
    @ViewBuilder
    private func fileContent(_ file: CommitFileChange) -> some View {
        if let failure = state.failures[file.path] {
            FailureDetailsView(failure: failure) { state.load(file.path, retry: true) }
                .padding(20)
        } else if let result = state.diffs[file.path], let source = state.source(for: file) {
            ReadOnlyFileDiffView(result: result, source: source) {
                state.load(file.path, showLarge: true)
            }
            .id(state.requests[file.path])
        } else {
            ProgressView(AppLocalization.text("working.loadingDiff"))
                .controlSize(.small)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
