import AppKit
import SpookyKit
import SwiftUI

// MARK: - WorkingCopyDetailView

/// 单文件详情按暂存侧显示 Diff，冲突与多选使用独立内容状态。
struct WorkingCopyDetailView: View {
    /// 当前仓库的选择和补丁快照。
    @Bindable
    var session: RepositorySession

    /// 鼠标是否在文件头部上，决定 Blame 与文件历史的动作条是否显示。
    @State
    private var hoveringHeader = false

    /// 文件头、比较侧和可访问的内容状态。
    var body: some View {
        if let entry = session.selectedEntry {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: entry.path.hasSuffix("/") ? "folder" : "doc")
                        .font(.system(size: 24))
                        .accessibilityHidden(true)
                    Text(entry.path)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(entry.path)
                    Spacer(minLength: 0)

                    // 悬停时出现的 Blame 与文件历史，头部右键菜单提供同样的入口
                    FileActionBar(actions: session.workingCopyFileActions(entry.path), hovering: hoveringHeader)

                    if entry.hasWorkingCopyDiff {
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
                .modifier(
                    FileActionHeader(actions: session.workingCopyFileActions(entry.path), hovering: $hoveringHeader)
                )
                Divider()

                content(entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onChange(of: session.diffSide) { session.loadDiff() }
            .reloadsOnDiffPreferenceChange { session.loadDiff() }
        } else if let directory = session.selectedDirectory {
            unchangedView(AppLocalization.text(directoryMessage(directory)), symbol: "folder")
        } else {
            VStack(spacing: 16) {
                EmptyStateView(
                    title: AppLocalization.text(session.selectedIDs.count > 1 ? "working.multiple" : "detail.empty.title"),
                    message: "",
                    symbol: "doc"
                )

                if session.selectedIDs.count > 1 {
                    HStack(spacing: 8) {
                        Button(AppLocalization.text("working.discard")) { session.discard(session.selectedEntries) }
                            .disabled(!session.canDiscard(session.selectedEntries))

                        // 本机移到废纸篓，服务器上永久删除，执行前都会确认
                        Button(AppLocalization.text(session.repository?.host == nil ? "files.trash" : "files.delete")) {
                            session.delete(session.selectedEntries)
                        }
                        .disabled(!session.canDelete(session.selectedEntries))
                    }
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
            // 换一个冲突文件时重建向导，上一个文件的内容与未保存的编辑不会带过来
            ConflictWizardView(session: session, entry: entry)
                .id(entry.path)
        } else if !entry.hasWorkingCopyDiff {
            unchangedView(AppLocalization.text(unchangedMessage(entry)), symbol: "doc")
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

// MARK: - Unchanged

extension WorkingCopyDetailView {
    /// 未改动视图：没有可显示的 Diff 时说明文件或目录的状态。
    private func unchangedView(_ text: String, symbol: String) -> some View {
        EmptyStateView(title: text, message: "", symbol: symbol)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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
