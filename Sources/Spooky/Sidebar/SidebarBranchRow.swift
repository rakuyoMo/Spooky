import SpookyKit
import SwiftUI

// MARK: - SidebarBranchStatus

/// 按视图设置筛过的分支状态：侧边栏实际显示的完全合并、陈旧与跟踪错误。
struct SidebarBranchStatus: Equatable {
    /// 显示 Merged 徽标。
    var isFullyMerged = false

    /// 陈旧时距上次更新的时长。
    var staleDuration: String? = nil

    /// 已不存在的上游的完整引用名。
    var missingUpstream: String? = nil

    /// 已合并或陈旧的分支名称变灰。
    var isDimmed: Bool { isFullyMerged || staleDuration != nil }

    /// 由整理状态与视图设置得出；基准分支不显示已合并与陈旧，跟踪错误总是显示。
    ///
    /// - Parameters:
    ///   - condition: 分支的整理状态；还没读到时为 nil。
    ///   - showsMerged: 视图设置是否显示 Merged 徽标。
    ///   - staleMonths: 陈旧阈值的月数；视图设置不显示陈旧信息时为 nil。
    ///   - now: 判断陈旧的时刻。
    init(condition: BranchCondition?, showsMerged: Bool, staleMonths: Int?, now: Date = Date()) {
        guard let condition else {
            return
        }

        isFullyMerged = showsMerged && condition.isFullyMerged
        missingUpstream = condition.missingUpstream

        if
            let staleMonths,
            let lastUpdated = condition.lastUpdated,
            condition.isStale(months: staleMonths, now: now)
        {
            staleDuration = SidebarTooltip.duration(since: lastUpdated, now: now)
        }
    }
}

// MARK: - SidebarBadgeSegment

/// 分支行右侧胶囊徽标里的一段，按 HEAD、Merged、超前、落后的顺序排列。
enum SidebarBadgeSegment: Hashable {
    /// 当前分支。
    case head

    /// 已完全合并。
    case merged

    /// 本地独有的提交数。
    case ahead(Int)

    /// 上游独有的提交数。
    case behind(Int)

    /// 供 VoiceOver 朗读的说明，不读箭头符号。
    var accessibilityText: String {
        switch self {
        case .head: "HEAD"
        case .merged: AppLocalization.text("branch.merged")
        case .ahead(let count): AppLocalization.text("branch.ahead", count)
        case .behind(let count): AppLocalization.text("branch.behind", count)
        }
    }
}

// MARK: - SidebarBadge

/// 分支行的胶囊徽标：各段之间一条 10 pt 高的竖线，选中行换用更亮的分隔线。
struct SidebarBadge: View {
    /// 有内容的段，至少一段。
    let segments: [SidebarBadgeSegment]

    /// 所在行被选中时底色更突出。
    @Environment(\.backgroundProminence)
    private var prominence

    /// 段与段之间夹分隔线，整体裁成胶囊。
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.element) { index, segment in
                if index > 0 {
                    Rectangle()
                        .fill(separatorColor)
                        .frame(width: 1, height: 10)
                }

                content(segment)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Color(nsColor: .labelColor))
        .background(AppPalette.color("sidebarBadgeBackgroundColor"), in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(segments.map(\.accessibilityText).joined(separator: ", "))
    }

    /// 选中行与普通行的分隔线颜色。
    private var separatorColor: Color {
        AppPalette.color(
            prominence == .increased ? "highlightedSidebarBadgeSeparatorColor" : "sidebarBadgeSeparatorColor"
        )
    }

    /// 一段的内容：HEAD 与 Merged 是文字，超前落后是箭头加数字，两者之间不留空。
    @ViewBuilder
    private func content(_ segment: SidebarBadgeSegment) -> some View {
        switch segment {
        case .head:
            Text("HEAD").fontWeight(.semibold)

        case .merged:
            Text(AppLocalization.text("branch.merged"))

        case .ahead(let count):
            HStack(spacing: 0) {
                Image(systemName: "arrow.up").frame(width: 10, height: 10)
                Text(count.formatted())
            }

        case .behind(let count):
            HStack(spacing: 0) {
                Image(systemName: "arrow.down").frame(width: 10, height: 10)
                Text(count.formatted())
            }
        }
    }
}

// MARK: - SidebarBranchRow

/// 侧边栏的分支行：图标、名称、名称后的陈旧与跟踪错误注记、右侧胶囊徽标，宽度不够时先截名称。
struct SidebarBranchRow: View {
    /// 显示名。
    let name: String

    /// 图标的 SF Symbol 名。
    let symbol: String

    /// 胶囊徽标的各段；为空时不显示徽标。
    var badge: [SidebarBadgeSegment] = []

    /// 名称后的注记与名称颜色。
    var status = SidebarBranchStatus(condition: nil, showsMerged: false, staleMonths: nil)

    /// 远端的默认分支。
    var isDefault = false

    /// 悬停提示。
    let help: String

    /// 名称在前、注记紧随、徽标靠右。
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)

            Text(name)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(status.isDimmed ? .secondary : .primary)

            annotations

            Spacer(minLength: 4)

            if !badge.isEmpty {
                SidebarBadge(segments: badge)
            }

            if isDefault {
                Image(systemName: "house").help(AppLocalization.text("branch.default"))
            }
        }
        .help(help)
    }

    /// 名称后的注记：陈旧的时长与跟踪错误标记，11 pt。
    @ViewBuilder
    private var annotations: some View {
        if status.staleDuration != nil || status.missingUpstream != nil {
            HStack(spacing: 4) {
                if let staleDuration = status.staleDuration {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                        Text(staleDuration)
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(AppLocalization.text("branch.staleFor", staleDuration))
                }

                if status.missingUpstream != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color(nsColor: .systemRed))
                        .accessibilityLabel(AppLocalization.text("branch.trackingError"))
                }
            }
            .font(.system(size: 11))
            .lineLimit(1)
            .fixedSize()
        }
    }
}
