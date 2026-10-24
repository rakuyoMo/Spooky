import AppKit
import SpookyKit
import SwiftUI

// MARK: - OperationBannerView

/// 提交区上方的进行中操作横幅：标题、冲突计数、当前阶段的提示与序列进度，以及只看冲突、中止和跳过。
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

    /// 左侧是操作类型的图标，右侧是文字列；底行的勾选框与文字列左对齐，按钮靠右。
    private func banner(_ progress: OperationProgress) -> some View {
        #warning("TODO: 核对横幅着色所用的命名色，目前取系统红色；只影响进行中操作横幅的底色与描边")

        return HStack(alignment: .top, spacing: 8) {
            icon(progress.state)

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
                    .padding(.top, 12)

                stepProgress(progress)

                actionRow(progress)
                    .padding(.top, 16)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // 着色铺在最下层，上面盖一层半透明的标题栏材质
            ZStack {
                Color.red.opacity(0.15)

                BannerMaterialView()
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.red.opacity(0.25), lineWidth: 1))
    }

    /// 合并与压缩合并用合并的图标，变基、摘取与反转用分支的图标；系统黄色，略微透明。
    private func icon(_ state: RepositoryOperationState) -> some View {
        let merging = state == .merge || state == .squash

        return Image(systemName: merging ? "arrow.triangle.merge" : "arrow.triangle.branch")
            .font(.system(size: 36))
            .foregroundStyle(Color(nsColor: .systemYellow).opacity(0.9))
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)
    }

    /// 序列进度：变基多个提交时显示第几步与进度条；摘取与反转不记录已完成的步数，只说明正在处理的提交。
    @ViewBuilder
    private func stepProgress(_ progress: OperationProgress) -> some View {
        if [.cherryPick, .revert].contains(progress.state), let subject = progress.stepSubject {
            Text(AppLocalization.text(
                progress.stepKind == .reverting ? "conflict.sequence.reverting" : "conflict.sequence.applying",
                subject
            ))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .padding(.top, 12)
        } else if let step = progress.step, let count = progress.stepCount, count > 1 {
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

    /// 变基的 “第 N 步，共 M 步” 加上当前一步的动作与提交标题。
    private func stepText(_ progress: OperationProgress, step: Int, count: Int) -> String {
        guard let subject = progress.stepSubject else {
            return AppLocalization.text("conflict.step", step, count)
        }

        let key = progress.stepKind == .editing ? "conflict.step.editing" : "conflict.step.applying"
        return AppLocalization.text(key, step, count, subject)
    }
}

// MARK: - BannerMaterialView

/// 横幅底色上半透明的标题栏材质，让着色随窗口背景略微变化。
private struct BannerMaterialView: NSViewRepresentable {
    /// 标题栏材质、在窗口内混合、强调样式，整体半透明。
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .headerView
        view.blendingMode = .withinWindow
        view.isEmphasized = true
        view.alphaValue = 0.5
        return view
    }

    /// 材质参数固定，无需更新。
    func updateNSView(_: NSVisualEffectView, context _: Context) { }
}
