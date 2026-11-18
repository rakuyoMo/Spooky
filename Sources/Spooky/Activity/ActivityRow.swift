import AppKit
import SwiftUI

// MARK: - ActivityRow

/// 活动列表的一行：行首图标，仓库名与右上角的时间，标题，日志的最后一行；Remote 页进行中的行与各页等待中的行另有进度条与停止按钮。
struct ActivityRow: View {
    /// 三页共同的行高。
    static let height: CGFloat = 67

    /// 有进度条的行高，比共同的行高多出进度条一行。
    static let runningRemoteHeight: CGFloat = 89

    /// 这一行的记录。
    let activity: RepositoryActivity

    /// 这一行被选中；选中时不换灰底，露出列表的选中底色。
    var isSelected = false

    /// 最后一行文字：日志的最后一个非空行；没有日志时写状态，同步进行中是步骤名。Remote 页进行中的行把它当作进度摘要。
    var status: String {
        activity.lastLine ?? AppLocalization.text(activity.state)
    }

    /// 行首的图标：Remote 页按传输方向，失败、取消或已跳过的用警告图标；其余两页是文件夹与账号，失败的用警告图标。
    var leadingIcon: ActivityIcon {
        let warning = ActivityIcon.symbol("exclamationmark.triangle.fill")

        switch activity.kind {
        case .remote:
            return isUnsuccessful ? warning : activity.transferIcon

        case .repository:
            return activity.state == "activity.failed" ? warning : .symbol("folder")

        case .service:
            return activity.state == "activity.failed" ? warning : .symbol("person.crop.circle")
        }
    }

    /// 行高固定，行内边距四周 8 pt，内容靠上；Remote 页失败、取消或已跳过的行换用灰底。
    var body: some View {
        let height = showsProgress ? Self.runningRemoteHeight : Self.height

        Group {
            if activity.kind == .remote {
                remoteRow
            } else {
                localRow
            }
        }
        .padding(8)
        .frame(
            maxWidth: .infinity,
            minHeight: height,
            maxHeight: height,
            alignment: .topLeading
        )
        .listRowBackground(errorBackground)
    }

    /// 右上角的文字：Remote 页进行中写 In Progress…，已结束写开始的日期，今天与昨天写作 Today、Yesterday；
    /// 其余两页写耗时，两位小数、按系统地区的数字格式，进行中的算到 `now`。等待中的不计时，空着。
    ///
    /// - Parameter now: 当前时间。
    func corner(now: Date) -> String {
        guard !isWaiting else {
            return ""
        }

        if activity.kind == .remote {
            guard activity.isEnded else {
                return AppLocalization.text("activity.inProgress")
            }

            // 日期由系统按当前语言给出，如 “Today” “October 26, 2026”，不写时间
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            formatter.doesRelativeDateFormatting = true
            return formatter.string(from: activity.started)
        }

        let seconds = activity.elapsed ?? now.timeIntervalSince(activity.started)
        let number = seconds.formatted(.number.precision(.fractionLength(2)))

        return AppLocalization.text("activity.elapsed", number)
    }
}

// MARK: - Layout

extension ActivityRow {
    /// Remote 页进行中的记录：行里有进度条与停止按钮。
    private var isRunningRemote: Bool {
        activity.kind == .remote && !activity.isEnded
    }

    /// 排在写队列里等待的记录。
    private var isWaiting: Bool {
        activity.state == "activity.waiting"
    }

    /// 行里有进度条与停止按钮：Remote 页进行中的，以及各页等待中的。
    private var showsProgress: Bool {
        isRunningRemote || isWaiting
    }

    /// 失败、取消或已跳过的记录。
    private var isUnsuccessful: Bool {
        ["activity.failed", "activity.cancelled", "activity.skipped"].contains(activity.state)
    }

    /// Remote 页失败、取消或已跳过、没有选中的行换用灰底；其余的行用列表的背景。
    private var errorBackground: Color? {
        guard activity.kind == .remote, isUnsuccessful, !isSelected else {
            return nil
        }

        return AppPalette.color("general_secondary_background_color")
    }

    /// Remote 页的行：进行中的图标 18 × 18，下面多一行进度条与停止按钮，最后一行是进度摘要；已结束的图标 14 × 14。
    ///
    /// 图标与标题垂直居中，文字从图标右边 8 pt 起。
    private var remoteRow: some View {
        HStack(alignment: .titleCenter, spacing: 8) {
            icon(size: isRunningRemote ? 18 : 14)

            VStack(alignment: .leading, spacing: 4) {
                header(size: isRunningRemote ? 10 : 11)

                titleLine(offset: 0)

                if isRunningRemote {
                    progressLine
                }

                statusLine
            }
        }
    }

    /// Repository 与 Service 页的行：图标 17 × 17，标题的中心比图标中心低 1.5，文字从图标右边 5 pt 起。
    ///
    /// 进行中的行把图标换成在行内垂直居中的转圈，距左 9；等待中的行照常显示图标，标题下面多一行空的进度条与停止按钮。
    private var localRow: some View {
        HStack(alignment: .titleCenter, spacing: 5) {
            icon(size: 17)
                .opacity(activity.isEnded || isWaiting ? 1 : 0)

            VStack(alignment: .leading, spacing: 4) {
                header(size: 11)

                titleLine(offset: 1.5)

                if isWaiting {
                    progressLine
                }

                statusLine
            }
        }
        .overlay(alignment: .leading) {
            if !activity.isEnded, !isWaiting {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
                    .padding(.leading, 1)
            }
        }
    }

    /// 进度条与右边的停止按钮，两者垂直居中；等待中的进度条是空的。
    private var progressLine: some View {
        HStack(spacing: 8) {
            ProgressView(value: activity.progress ?? 0)

            Button {
                activity.cancel?()
            } label: {
                Image(nsImage: NSImage(named: NSImage.stopProgressFreestandingTemplateName) ?? NSImage())
            }
            .buttonStyle(.borderless)
            .frame(width: 17, height: 18)
            .disabled(activity.cancel == nil)
            .accessibilityLabel(AppLocalization.text("action.cancel"))
        }
    }

    /// 最后一行：11 pt 的日志末行或状态，等待中写 Waiting，超长时截断尾部；Remote 页进行中的进度摘要超长时直接截掉。
    @ViewBuilder
    private var statusLine: some View {
        let text = Text(status)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

        if isRunningRemote {
            clippedLine(text)
        } else {
            text.lineLimit(1)
        }
    }

    /// 第一行：左边 10 pt 的仓库名，超长时直接截掉；右边不超过 120 pt 的时间，两者基线对齐、至少相隔 8 pt。
    ///
    /// - Parameter size: 右上角文字的字号。
    private func header(size: CGFloat) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            clippedLine(Text(activity.repository?.name ?? "").font(.system(size: 10)))

            Text(corner(now: Date()))
                .font(.system(size: size))
                .lineLimit(1)
                .frame(maxWidth: 120)
                .fixedSize()
        }
        .foregroundStyle(.secondary)
    }

    /// 第二行：12 pt 粗体的标题。
    ///
    /// - Parameter offset: 标题的中心比图标中心低多少。
    private func titleLine(offset: CGFloat) -> some View {
        Text(activity.displayTitle)
            .font(.system(size: 12, weight: .bold))
            .lineLimit(1)
            .alignmentGuide(.titleCenter) { $0[VerticalAlignment.center] - offset }
    }

    /// 行首的模板图标，跟随文字色。
    ///
    /// - Parameter size: 图标的边长。
    private func icon(size: CGFloat) -> some View {
        leadingIcon.image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    /// 占满剩余宽度的一行文字，超出时直接截掉、不加省略号。
    ///
    /// - Parameter text: 已设好字体与颜色的文字。
    private func clippedLine(_ text: some View) -> some View {
        text
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .clipped()
    }
}

// MARK: - VerticalAlignment

extension VerticalAlignment {
    /// 行首图标与标题对齐的位置，默认是视图的垂直中心。
    private enum TitleCenter: AlignmentID {
        /// 没有另外指定时取垂直中心。
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    /// 行首图标与标题对齐的位置。
    fileprivate static let titleCenter = VerticalAlignment(TitleCenter.self)
}
