import SpookyKit
import SwiftUI

// MARK: - OperationBannerView

/// 提交区上方的进行中操作横幅：标题、冲突计数、当前阶段的提示、序列进度与备份文件，以及只看冲突、中止和跳过。
struct OperationBannerView: View {
    /// 当前阶段：决定提示文字与是否提供跳过。
    private enum Phase {
        /// 还有未解决的冲突。
        case conflicts

        /// 冲突都已解决，已跟踪的文件还有改动。
        case resolved

        /// 冲突都已解决，已跟踪的文件没有任何改动；跳过这一步不会丢掉工作区里的改动。
        case empty
    }

    /// 当前仓库会话。
    @Bindable
    var session: RepositorySession

    /// 只在有进行中的操作时显示。
    var body: some View {
        if let progress = session.context?.progress {
            banner(progress)
        }
    }
}

// MARK: - Private

extension OperationBannerView {
    /// 当前阶段，按冲突与已跟踪文件的改动判断；未跟踪的文件不影响跳过。
    private var phase: Phase {
        if session.conflictCount > 0 {
            return .conflicts
        }

        let changed = session.status?.entries.contains { $0.kind == .tracked } ?? false
        return changed ? .resolved : .empty
    }

    /// 未解决与已解决的冲突数；从没有出现过冲突时不显示。
    private var conflictSummary: String? {
        let unresolved = session.conflictCount
        let resolved = session.resolvedConflictCount

        let base: String? =
            switch unresolved {
            case 0: resolved > 0 ? AppLocalization.text("conflict.unresolved.none") : nil
            case 1: AppLocalization.text("conflict.unresolved.one")
            default: AppLocalization.text("working.conflicts", unresolved)
            }

        guard let base, resolved > 0 else {
            return base
        }

        return AppLocalization.text("conflict.resolvedSuffix", base, resolved)
    }

    /// 左侧是警示图标，右侧是文字列；底行的勾选框与文字列左对齐，按钮靠右。
    private func banner(_ progress: OperationProgress) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(session.operationBannerTitle ?? "")
                    .font(.system(size: 13, weight: .bold))

                if let summary = conflictSummary {
                    Text(summary)
                        .font(.system(size: 13))
                        .padding(.top, 4)
                }

                Text(hint(progress.state))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                stepProgress(progress)

                ConflictBackupsView(session: session)
                    .padding(.top, 12)

                actionRow(progress)
                    .padding(.top, 16)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.red.opacity(0.25)))
    }

    /// 序列进度：只在变基、摘取或反转多个提交时显示。
    @ViewBuilder
    private func stepProgress(_ progress: OperationProgress) -> some View {
        if let step = progress.step, let count = progress.stepCount, count > 1 {
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(min(step, count)), total: Double(count))

                Text(stepText(progress, step: step, count: count))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.top, 12)
        }
    }

    /// 只看冲突文件的勾选框，以及中止和跳过；跳过只在序列的这一步没有改动时提供。
    private func actionRow(_ progress: OperationProgress) -> some View {
        HStack(spacing: 8) {
            Toggle(AppLocalization.text("working.onlyConflicts"), isOn: $session.onlyConflicts)
                .toggleStyle(.checkbox)
                .disabled(session.conflictCount == 0)

            Spacer(minLength: 0)

            Button(AppLocalization.text("working.abort")) { session.finishOperation("abort") }
                .disabled(!session.canWrite)

            if progress.state != .merge, progress.state != .squash, phase == .empty {
                Button(AppLocalization.text("working.skip")) { session.finishOperation("skip") }
                    .disabled(!session.canWrite)
            }
        }
    }

    /// 按操作与阶段给出下一步提示；按钮名以粗体标出。
    private func hint(_ state: RepositoryOperationState) -> AttributedString {
        let key =
            switch (state, phase) {
            case (.merge, .conflicts), (.squash, .conflicts): "conflict.hint.merge.conflicts"
            case (.merge, .resolved), (.squash, .resolved): "conflict.hint.merge.resolved"
            case (.merge, .empty), (.squash, .empty): "conflict.hint.merge.empty"
            case (.rebase, .conflicts): "conflict.hint.rebase.conflicts"
            case (.rebase, .resolved): "conflict.hint.rebase.resolved"
            case (.rebase, .empty): "conflict.hint.rebase.empty"
            case (_, .conflicts): "conflict.hint.sequence.conflicts"
            case (_, .resolved): "conflict.hint.sequence.resolved"
            case (_, .empty): "conflict.hint.sequence.empty"
            }

        let text = AppLocalization.text(key)
        return (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    /// “第 N 步，共 M 步” 加上当前一步的动作与提交标题。
    private func stepText(_ progress: OperationProgress, step: Int, count: Int) -> String {
        guard let subject = progress.stepSubject else {
            return AppLocalization.text("conflict.step", step, count)
        }

        switch progress.stepKind ?? .applying {
        case .applying: return AppLocalization.text("conflict.step.applying", step, count, subject)
        case .editing: return AppLocalization.text("conflict.step.editing", step, count, subject)
        case .reverting: return AppLocalization.text("conflict.step.reverting", step, count, subject)
        }
    }
}
