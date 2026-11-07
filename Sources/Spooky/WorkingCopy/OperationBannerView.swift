import AppKit
import SpookyKit
import SwiftUI

// MARK: - OperationBannerView

/// 提交区上方的进行中操作横幅：标题、冲突计数、当前阶段的提示与序列进度，以及只看冲突、中止、结束编辑和跳过。
struct OperationBannerView: View {
    /// 当前阶段：决定提示文字。
    enum Phase {
        /// 还有未解决的冲突。
        case conflicts

        /// 冲突都已解决，工作区还有改动。
        case resolved

        /// 冲突都已解决，工作区没有任何改动。
        case empty
    }

    /// 当前仓库会话。
    let session: RepositorySession

    /// 是否只显示冲突文件，全局偏好。
    @AppStorage(WorkingCopyPreferences.showOnlyConflicts)
    private var onlyConflicts = false

    /// 只在有进行中的操作时显示；左、右、上留 12 pt，下方接提交区时不留，提交区隐藏时留 12 pt。
    var body: some View {
        if let progress = session.context?.progress {
            banner(progress)
                .padding([.horizontal, .top], 12)
                .padding(.bottom, session.showsCommitArea ? 0 : 12)
        }
    }
}

// MARK: - Texts

extension OperationBannerView {
    /// 冲突计数：总写未解决的数量；这次操作出现过冲突时，后面接已解决的数量，从 0 起。
    ///
    /// - Parameters:
    ///   - unresolved: 当前未解决的冲突数。
    ///   - resolved: 这次操作中已经解决的冲突数。
    static func conflictSummary(unresolved: Int, resolved: Int) -> String {
        let base =
            switch unresolved {
            case 0: AppLocalization.text("conflict.unresolved.none")
            case 1: AppLocalization.text("conflict.unresolved.one")
            default: AppLocalization.text("working.conflicts", unresolved)
            }

        // 从没有出现过冲突的操作（如 merge --no-commit）不带括号
        guard unresolved > 0 || resolved > 0 else {
            return base
        }

        return AppLocalization.text("conflict.resolvedSuffix", base, resolved)
    }

    /// 按操作与阶段选择提示的资源键。
    ///
    /// edit 步与尚未开始的交互式变基各有说明；合并、压缩合并与单个提交的摘取、反转以提交收尾，序列与变基以继续收尾。
    static func hintKey(_ progress: OperationProgress, phase: Phase) -> String {
        switch (progress.state, phase) {
        case (_, _) where progress.stopsForEdit: "conflict.hint.rebase.edit"
        case (_, _) where progress.isPendingInteractive: "conflict.hint.rebase.pending"
        case (_, .conflicts) where !progress.isSequence: "conflict.hint.merge.conflicts"
        case (_, .resolved) where !progress.isSequence: "conflict.hint.merge.resolved"
        case (_, .empty) where !progress.isSequence: "conflict.hint.merge.empty"
        case (.rebase, .conflicts): "conflict.hint.rebase.conflicts"
        case (.rebase, .resolved): "conflict.hint.rebase.resolved"
        case (.rebase, .empty): "conflict.hint.rebase.empty"
        case (_, .conflicts): "conflict.hint.sequence.conflicts"
        case (_, .resolved): "conflict.hint.sequence.resolved"
        case (_, .empty): "conflict.hint.sequence.empty"
        }
    }
}

// MARK: - Private

extension OperationBannerView {
    /// 当前阶段，按冲突与整份工作区的改动判断；未跟踪的文件也算改动。
    private var phase: Phase {
        if session.conflictCount > 0 {
            return .conflicts
        }

        return session.isWorkingCopyClean ? .empty : .resolved
    }

    /// 左侧是操作类型的图标，右侧是文字列；底行的勾选框与文字列左对齐，按钮靠右。
    private func banner(_ progress: OperationProgress) -> some View {
        let summary = Self.conflictSummary(
            unresolved: session.conflictCount,
            resolved: session.resolvedConflictCount
        )

        return HStack(alignment: .top, spacing: 8) {
            icon(progress.state)

            VStack(alignment: .leading, spacing: 0) {
                Text(session.operationBannerTitle ?? "")
                    .font(.system(size: 13, weight: .bold))

                Text(summary)
                    .font(.system(size: 13))
                    .padding(.top, 4)

                Text(hint(progress))
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
            // 警告底色铺在最下层，上面盖一层半透明的标题栏材质；命名色两种外观各有取值
            ZStack {
                AppPalette.color("general_warning_bg_color")

                BannerMaterialView()
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .systemYellow).opacity(0.25), lineWidth: 1)
        }
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

    /// 序列进度：变基、摘取与反转的序列显示进度条与第几步，一项也显示；单个提交的操作没有进度。
    @ViewBuilder
    private func stepProgress(_ progress: OperationProgress) -> some View {
        if
            let text = session.operationStepText,
            let step = progress.step,
            let count = progress.stepCount
        {
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(min(step, count)), total: Double(count))

                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.top, 12)
        }
    }

    /// 只看冲突文件的勾选框，以及中止、结束编辑和跳过。
    private func actionRow(_ progress: OperationProgress) -> some View {
        HStack(spacing: 8) {
            // 全部解决后仍可切换，直到操作结束
            Toggle(AppLocalization.text("working.onlyConflicts"), isOn: $onlyConflicts)
                .toggleStyle(.checkbox)
                .disabled(session.conflictPaths == nil)

            Spacer(minLength: 0)

            Button(AppLocalization.text("working.abort")) { session.finishOperation("abort") }
                .disabled(!session.canWrite)

            // 工作区还有改动或未跟踪文件时照样可以结束编辑，Git 拒绝时报告它的错误
            if progress.stopsForEdit {
                Button(AppLocalization.text("working.endEditing")) { session.finishOperation("continue") }
                    .disabled(!session.canWrite)
            } else if session.offersSkip {
                Button(AppLocalization.text("working.skip")) { session.finishOperation("skip") }
                    .disabled(!session.canWrite)
            }
        }
    }

    /// 当前阶段的下一步提示，按钮名以粗体标出。
    private func hint(_ progress: OperationProgress) -> AttributedString {
        let text = AppLocalization.text(Self.hintKey(progress, phase: phase))
        return (try? AttributedString(markdown: text)) ?? AttributedString(text)
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
