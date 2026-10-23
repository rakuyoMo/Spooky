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
                    Image(systemName: "doc")
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

                    if entry.kind != .conflicted {
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
        } else {
            VStack(spacing: 16) {
                EmptyStateView(
                    title: AppLocalization.text(session.selectedIDs.count > 1 ? "working.multiple" : "detail.empty.title"),
                    message: "",
                    symbol: "doc"
                )

                if session.selectedIDs.count > 1 {
                    Button(AppLocalization.text("working.discard")) { session.discard(session.selectedEntries) }
                        .disabled(!session.canDiscard(session.selectedEntries))
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
