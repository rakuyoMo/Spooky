import SpookyKit
import SwiftUI

// MARK: - CloneProgressView

/// 克隆中的仓库：标题、340 pt 的进度条与停止按钮，下面一行是 Git 报告的阶段与进度。
///
/// 取消或失败后换成说明、原文与重试；完成后由所在窗口打开仓库。
struct CloneProgressView: View {
    /// 显示的克隆。
    let activity: CloneActivity

    /// 重试取消或失败的克隆。
    let retry: () -> Void

    /// 克隆完成。
    var finished: () -> Void = { }

    /// 标题与按状态变化的内容竖排居中。
    var body: some View {
        VStack(spacing: 12) {
            Text(AppLocalization.text("clone.progress.title", activity.name))
                .font(.system(size: 18))
                .foregroundStyle(.secondary)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.color("general_background_color"))
        .onChange(of: activity.isFinished) {
            if activity.isFinished {
                finished()
            }
        }
    }

    /// 进行中显示进度与停止按钮，结束后显示结果。
    @ViewBuilder
    private var content: some View {
        switch activity.state {
        case .running(let progress):
            HStack(spacing: 8) {
                CloneProgressBar(progress: progress)
                    .frame(width: 340)

                Button(action: activity.cancel) {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(AppLocalization.text("clone.cancel"))
            }

            Text(CloneProgressBar.status(progress))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

        case .cancelled:
            Text(AppLocalization.text("clone.state.cancelled"))
                .foregroundStyle(.secondary)

            Button(AppLocalization.text("clone.retry"), action: retry)

        case .failed(let failure):
            FailureDetailsView(failure: failure, retry: retry)
                .frame(maxWidth: 520)

        case .finished:
            Text(AppLocalization.text("clone.state.finished"))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - CloneProgressBar

/// 克隆的进度条：Git 报告百分比时是确定进度，之前是不确定进度。
struct CloneProgressBar: View {
    /// 最新的进度；还没有时为 nil。
    let progress: CloneProgress?

    /// 确定或不确定的线性进度条。
    var body: some View {
        if let fraction = progress?.fraction {
            ProgressView(value: fraction)
        } else {
            ProgressView()
                .progressViewStyle(.linear)
        }
    }

    /// 进度的文字：阶段、百分比与对象数；还没有进度时写正在开始。
    static func status(_ progress: CloneProgress?) -> String {
        guard let progress else {
            return AppLocalization.text("clone.status.starting")
        }

        let phase = AppLocalization.text("clone.phase." + progress.phase.key)

        guard let percent = progress.percent, let total = progress.total else {
            return AppLocalization.text("clone.status.count", phase, progress.completed)
        }

        return AppLocalization.text("clone.status.percent", phase, percent, progress.completed, total)
    }
}

// MARK: - CloneProgress.Phase

extension CloneProgress.Phase {
    /// 资源键里的阶段名。
    var key: String {
        switch self {
        case .enumerating: "enumerating"
        case .counting: "counting"
        case .compressing: "compressing"
        case .receiving: "receiving"
        case .resolving: "resolving"
        case .checkingOut: "checkingOut"
        case .filtering: "filtering"
        }
    }
}

// MARK: - CloneActivity

extension CloneActivity {
    /// 是否已完成。
    var isFinished: Bool {
        if case .finished = state { true } else { false }
    }
}
