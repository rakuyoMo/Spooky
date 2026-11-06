import AppKit
import SpookyKit
import SwiftUI

// MARK: - WorkingCopyDetailView

/// 单文件详情按暂存侧显示 Diff，冲突与多选使用独立内容状态。
struct WorkingCopyDetailView: View {
    /// 当前仓库的选择和补丁快照。
    @Bindable
    var session: RepositorySession

    /// 文件头、比较侧和可访问的内容状态。
    var body: some View {
        if let entry = session.selectedEntry {
            VStack(spacing: 0) {
                WorkingCopyFileHeader(
                    session: session,
                    path: entry.path,
                    entry: entry,
                    isDirectory: entry.path.hasSuffix("/")
                )

                content(entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onChange(of: session.diffSide) { session.diffSideChanged() }
            .reloadsOnDiffPreferenceChange { session.loadDiff() }
        } else if let directory = session.selectedDirectory {
            VStack(spacing: 0) {
                WorkingCopyFileHeader(session: session, path: directory, entry: nil, isDirectory: true)

                EmptyStateView(
                    title: AppLocalization.text(directoryMessage(directory)),
                    message: "",
                    symbol: "doc"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if session.selectedIDs.count > 1 {
            EmptyStateView(
                title: AppLocalization.text("working.multiple"),
                message: "",
                symbol: "doc"
            ) {
                EmptyStateButton(AppLocalization.text("working.discard")) {
                    session.discard(session.selectedEntries)
                }
                .disabled(!session.canDiscard(session.selectedEntries))

                // 直接移进废纸篓，服务器上没有可用的废纸篓时确认后永久删除
                EmptyStateButton(
                    AppLocalization.text(session.fileRemoval == .trash ? "files.trash" : "files.delete")
                ) {
                    session.delete(session.selectedEntries)
                }
                .disabled(!session.canDelete(session.selectedEntries))
            }
        } else {
            EmptyStateView(
                title: AppLocalization.text("detail.empty.title"),
                message: "",
                symbol: "doc"
            )
        }
    }

    /// 内容错误可复制，超限提示只为当前文件提供完整加载入口。
    @ViewBuilder
    private func content(_ entry: StatusEntry) -> some View {
        if entry.kind == .conflicted {
            // 换一个冲突文件时重建向导，上一个文件的内容与未保存的编辑不会带过来
            ConflictWizardView(session: session, entry: entry)
                .id(entry.path)
        } else if entry.path.hasSuffix("/"), entry.kind != .ignored {
            EmptyStateView(
                title: AppLocalization.text(directoryMessage(String(entry.path.dropLast()))),
                message: "",
                symbol: "doc"
            )
        } else if !entry.hasWorkingCopyDiff {
            EmptyStateView(
                title: AppLocalization.text(unchangedMessage(entry)),
                message: "",
                symbol: "doc"
            )
        } else if let failure = session.diffFailure {
            FailureDetailsView(failure: failure) { session.loadDiff() }
                .padding(20)
        } else if let snapshot = session.diffSnapshot {
            if let file = snapshot.diff?.files.first, ImageDiffView.isImage(file, path: entry.path) {
                // 图片换成两侧对照，内容随快照重新读取
                ImageDiffView(placement: .bottom, id: snapshot.fingerprint.base64EncodedString()) {
                    try await session.imageContents(of: snapshot, file: file)
                }
            } else if let diff = snapshot.diff {
                DiffContentView(session: session, snapshot: snapshot, diff: diff)
                    .id(snapshot.fingerprint)
            } else {
                // 超过大小上限的 Diff 换成没有图标的空状态，按 Show Diff 才读取
                EmptyStateView(
                    title: AppLocalization.text("working.largeDiff"),
                    message: "",
                    symbol: nil
                ) {
                    EmptyStateButton(AppLocalization.text("working.showDiff")) {
                        session.showsLargeDiff = true
                        session.loadDiff()
                    }
                    .disabled(session.isLoadingDiff)
                }
            }
        } else {
            Color.clear
        }
    }
}

// MARK: - Unchanged

extension WorkingCopyDetailView {
    /// 目录说明的资源键：目录下有改动的文件时说明这一点。
    private func directoryMessage(_ directory: String) -> String {
        let prefix = directory + "/"
        let modified = session.status?.entries.contains { $0.path.hasPrefix(prefix) } ?? false

        return modified ? "files.unchanged.directoryModified" : "files.unchanged.directory"
    }

    /// 文件说明的资源键：被忽略、assume-unchanged 与没有改动的文件各有说明。
    private func unchangedMessage(_ entry: StatusEntry) -> String {
        if entry.kind == .ignored {
            return entry.path.hasSuffix("/") ? "files.unchanged.ignoredDirectory" : "files.unchanged.ignored"
        }

        let marked = session.workingTreeFiles.assumeUnchanged.contains(entry.path)
        return marked ? "files.unchanged.assumeUnchanged" : "files.unchanged.file"
    }
}
