import SpookyKit
import SwiftUI

// MARK: - MergeabilityPreview

/// 合并、拉取、变基与同步对话框里的合并可行性预览：所选版本并入 HEAD 时会不会冲突。
///
/// 所选版本一变就取消上一次检查重新计算，服务器上的慢响应不会覆盖新的选择；无法检查时不当作可以干净合并。
struct MergeabilityPreview: View {
    /// 发起检查的窗口会话。
    let session: RepositorySession

    /// 要并入 HEAD 的版本；为空时不检查。
    let revision: String

    /// 当前选择的检查结果。
    @State
    private var preview: MergePreview?

    /// 检查进行中时显示明确状态。
    @State
    private var checking = false

    /// 一行状态：18 pt 图标加 12 pt 说明文字，冲突的文件列在提示里。
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if checking {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)

                Text(AppLocalization.text("merge.checking"))
            } else if let preview {
                status(of: preview)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .task(id: revision) { await load() }
    }

    /// 检查结果对应的图标与文字；无法检查时把原因放进提示。
    @ViewBuilder
    private func status(of preview: MergePreview) -> some View {
        switch preview {
        case .clean:
            icon("checkmark.circle.fill", color: .green)
            Text(AppLocalization.text("merge.clean"))

        case .unchanged:
            icon("equal.circle", color: .secondary)
            Text(AppLocalization.text("merge.unchanged"))

        case .conflicts(let paths):
            icon("exclamationmark.triangle.fill", color: .yellow)
            Text(AppLocalization.text("merge.conflicts", paths.count))
                .help(paths.joined(separator: "\n"))

        case .unavailable(let details):
            icon("questionmark.circle", color: .secondary)
            Text(AppLocalization.text("merge.unavailable"))
                .help(details)
        }
    }

    /// 18 × 18 的状态图标，不参与朗读。
    private func icon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 14))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }

    /// 去抖后检查；任务被新的选择取消时不写入结果。
    private func load() async {
        preview = nil

        guard !revision.isEmpty, let runner = session.runner else {
            checking = false
            return
        }

        checking = true

        do {
            try await Task.sleep(for: .milliseconds(150))
            let result = try await RepositorySync(runner: runner).previewMerge(revision)
            try Task.checkCancellation()
            preview = result
        } catch {
            if !Task.isCancelled {
                let failure = AppFailure(error: error, opening: false, location: session.repository)
                preview = .unavailable(failure.details)
            }
        }

        if !Task.isCancelled {
            checking = false
        }
    }
}
