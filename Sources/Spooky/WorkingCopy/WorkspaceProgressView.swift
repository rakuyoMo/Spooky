import AppKit
import SwiftUI

// MARK: - WorkspaceProgress

/// 占用工作区的写操作执行期间，工作区显示的进度：标题与 Git 最新的一行输出。
struct WorkspaceProgress: Equatable {
    /// 已本地化的标题，写明操作与参数，如检出时写出检出的分支或版本。
    let title: String

    /// Git 输出的最后一个非空行；还没有输出时为 nil。
    var detail: String? = nil

    /// 最后一行里的百分比换算成的 0–1；没有百分比时为 nil，进度条用不确定样式。
    var fraction: Double? {
        guard
            let detail,
            let match = detail.firstMatch(of: /(\d+)%/),
            let percent = Double(match.1)
        else {
            return nil
        }

        return min(percent, 100) / 100
    }
}

// MARK: - WorkspaceProgressView

/// 工作区的整页进度：18 pt 标题，正中是 340 pt 宽的进度条与右边的停止按钮，下面一行是 11 pt 的进度文字。
///
/// 会话没有整页进度时什么都不画。
struct WorkspaceProgressView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 有整页进度时竖排标题、进度条与进度文字。
    var body: some View {
        if let progress = session.workspaceProgress {
            VStack(spacing: 8) {
                Text(progress.title)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // 停止按钮挂在进度条右边 8 pt 处，不参与排版，进度条保持水平居中
                bar(progress)
                    .frame(width: 340)
                    .overlay(alignment: .trailing) {
                        stopButton
                            .alignmentGuide(.trailing) { $0[.leading] - 8 }
                    }

                // 没有输出时同样占一行，输出出现时进度条不跳动
                Text(progress.detail ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: 14)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppPalette.color("general_background_color"))
        }
    }

    /// 停止写操作：取消写任务，Git 进程随之结束，服务器上的进程组一并结束。
    private var stopButton: some View {
        Button {
            session.writeTask?.cancel()
        } label: {
            Image(nsImage: NSImage(named: NSImage.stopProgressFreestandingTemplateName) ?? NSImage())
        }
        .buttonStyle(.borderless)
        .frame(width: 16, height: 22)
        .accessibilityLabel(AppLocalization.text("action.cancel"))
    }

    /// 进度条：Git 的最后一行带百分比时是确定进度，否则是不确定进度。
    @ViewBuilder
    private func bar(_ progress: WorkspaceProgress) -> some View {
        if let fraction = progress.fraction {
            ProgressView(value: fraction)
        } else {
            ProgressView()
                .progressViewStyle(.linear)
        }
    }
}
