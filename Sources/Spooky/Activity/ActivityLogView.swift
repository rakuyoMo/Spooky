import AppKit
import SwiftUI

// MARK: - ActivityLogView

/// 所选记录的原始日志：等宽 11 pt，四周留白 20，随内容一起滚动，可选择复制；没有输出时按状态写一行说明。
///
/// 新输出到来时滚到底；用户拖动或滚动后停止跟随，滚回底部后，下一次新输出时恢复。
/// 换一条记录时由调用方以记录的身份重建，回到顶部并重新开始跟随。
struct ActivityLogView: View {
    /// 日志所属的记录。
    let activity: RepositoryActivity

    /// 滚动位置，新建时在顶部。
    @State
    private var position = ScrollPosition(edge: .top)

    /// 新输出到来时是否滚到底。
    @State
    private var follows = true

    /// 滚动区停在底部。
    @State
    private var atBottom = true

    /// 用户正在拖动或滚动。
    @State
    private var interacting = false

    /// 显示的文字：有输出时是整段日志，没有输出时按状态写 Loading…、Finished、Error 或 Cancelled。
    var content: String {
        let log = activity.log

        guard log.isEmpty else {
            return log
        }

        switch activity.state {
        case "activity.finished": return AppLocalization.text("activity.finished")
        case "activity.failed": return AppLocalization.text("activity.log.error")
        case "activity.cancelled": return AppLocalization.text("activity.cancelled")
        default: return AppLocalization.text("activity.log.loading")
        }
    }

    /// 整块用文本背景色。
    var body: some View {
        let text = content

        ScrollView {
            Text(text)
                .font(font)
                .foregroundStyle(Color(nsColor: .controlTextColor))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .scrollPosition($position)
        .background(Color(nsColor: .textBackgroundColor))
        .onScrollPhaseChange { _, phase in
            interacting = phase == .interacting

            // 用户开始拖动或滚动时停止跟随；松手时已在底部就恢复
            if interacting {
                follows = false
            } else if atBottom {
                follows = true
            }
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.visibleRect.maxY >= geometry.contentSize.height - 1
        } action: { _, bottom in
            atBottom = bottom

            // 惯性滚动等松手之后回到底部的，同样恢复跟随
            if bottom, !interacting {
                follows = true
            }
        }
        .onChange(of: text) {
            if follows {
                position.scrollTo(edge: .bottom)
            }
        }
    }
}

// MARK: - Private

extension ActivityLogView {
    /// 日志的字体：用户设置的 11 pt 等宽字体，取不到时用系统等宽字体。
    private var font: Font {
        Font(NSFont.userFixedPitchFont(ofSize: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .regular))
    }
}
