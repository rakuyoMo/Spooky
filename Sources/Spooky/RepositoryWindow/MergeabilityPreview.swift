import SpookyKit
import SwiftUI

// MARK: - MergeabilityPreview

/// 合并、拉取、变基与同步对话框里的合并可行性预览：所选版本并入 HEAD 时会不会冲突。
///
/// 放在对话框表单的最后，在上一行下方 20 pt；图标与文字这一组从输入列左侧 20 pt 开始，图标挂在输入列外侧。
/// 所选版本一变就取消上一次检查重新计算，服务器上的慢响应不会覆盖新的选择；无法检查时不当作可以干净合并。
/// 合并对话框只在有冲突时显示结果，已确认没有冲突时不占高度；检查中与无法检查在各对话框都照常显示。
struct MergeabilityPreview: View {
    /// 发起检查的窗口会话。
    let session: RepositorySession

    /// 要并入 HEAD 的版本；为空时不检查。
    let revision: String

    /// 是否显示已确认没有冲突的结果：干净、快进、已合并与选中 HEAD 自身；合并对话框不显示。
    var showsCleanResults = true

    /// 当前选择的检查结果。
    @State
    private var preview: MergePreview?

    /// 检查进行中时显示明确状态。
    @State
    private var checking = false

    /// 一行状态：18 pt 图标加 4 pt 间距再加 12 pt 说明文字，冲突的文件列在提示里。
    var body: some View {
        let message = preview.flatMap { result in
            Self.message(for: result, showsCleanResults: showsCleanResults, head: headName)
        }

        let visible = checking || message != nil

        DialogInputColumnReader { inputColumn in
            // 表单的行距 8 再加 12，与上一行相隔 20；表单左边距 20，这一组再从输入列往左 20
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if checking {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 18, height: 18)

                    Text(AppLocalization.text("merge.checking"))
                } else if let preview, let message {
                    status(of: preview, message: message)
                }
            }
            .padding(.top, visible ? 12 : 0)
            .padding(.leading, inputColumn - 20 - 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .task(id: revision) { await load() }
    }

    /// 冲突说明里写出的 HEAD 分支名；分离 HEAD 时写 HEAD。
    private var headName: String {
        session.status?.branch.head ?? "HEAD"
    }

    /// 检查结果在这个对话框里的说明：冲突写出文件数与 HEAD 分支，按单复数取文案；
    /// 已确认没有冲突、对话框又不显示这类结果时为 nil，无法检查时总有说明。
    ///
    /// - Parameters:
    ///   - preview: 检查结果。
    ///   - showsCleanResults: 对话框是否显示已确认没有冲突的结果。
    ///   - head: 当前 HEAD 分支的短名。
    static func message(for preview: MergePreview, showsCleanResults: Bool, head: String) -> String? {
        switch preview {
        case .clean:
            showsCleanResults ? AppLocalization.text("merge.clean") : nil

        case .unchanged:
            showsCleanResults ? AppLocalization.text("merge.unchanged") : nil

        case .conflicts(let paths):
            paths.count == 1
                ? AppLocalization.text("merge.conflicts.one", head)
                : AppLocalization.text("merge.conflicts", head, paths.count)

        case .unavailable:
            AppLocalization.text("merge.unavailable")
        }
    }

    /// 检查结果对应的图标与说明；冲突的文件与无法检查的原因放进提示。
    @ViewBuilder
    private func status(of preview: MergePreview, message: String) -> some View {
        switch preview {
        case .clean:
            icon("checkmark.circle.fill", color: .green)
            Text(message)

        case .unchanged:
            icon("equal.circle", color: .secondary)
            Text(message)

        case .conflicts(let paths):
            icon("exclamationmark.triangle.fill", color: .yellow)
            Text(message)
                .help(paths.joined(separator: "\n"))

        case .unavailable(let details):
            icon("questionmark.circle", color: .secondary)
            Text(message)
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
