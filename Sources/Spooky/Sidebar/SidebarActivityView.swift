import SpookyKit
import SwiftUI

// MARK: - SidebarActivityView

/// 侧边栏底部的活动区：本仓库本次运行里进行中与刚结束的远程操作，最新的在上；从本机读回的记录不列。
///
/// 有行时上方一条分隔线，区高随行数变化，超过三行时在区内滚动；没有底色，与侧边栏同色。
struct SidebarActivityView: View {
    /// 结束的行留在区里的秒数。
    static let lingering: TimeInterval = 4

    /// 一行的高度。
    static let rowHeight: CGFloat = 65

    /// 区里最多同时露出的行数。
    static let visibleRows = 3

    /// 展开、收起与区高变化的动画时长。
    private static let duration = 0.2

    /// 所在窗口的仓库会话。
    let session: RepositorySession

    /// 打开 Activity 窗口。
    let showActivity: () -> Void

    /// 筛选所用的当前时间，到了最早一行的移除时刻才更新；其间结束的行离结束都不到 `lingering` 秒，照样列出。
    @State
    private var now = Date()

    /// 区高；行数变化后在 `duration` 秒内变到 `height(rows:)`，侧边栏列表的高度随之一起变化。
    @State
    private var regionHeight: CGFloat = 0

    /// 记录增减或结束时重新筛选，另在最早一行的移除时刻更新 `now` 再筛选。
    var body: some View {
        let rows = Self.items(of: session.activities.items, in: session.repository, now: now)
        let removal = rows
            .compactMap { $0.ended?.addingTimeInterval(Self.lingering) }
            .min()

        region(rows)
            .onChange(of: Self.height(rows: rows.count), initial: true) { _, height in
                // 收起用 ease-in，展开与行数变化用 ease-out；在动画事务里改区高，列表的高度也一起动画
                let animation: Animation = height == 0
                    ? .easeIn(duration: Self.duration)
                    : .easeOut(duration: Self.duration)

                withAnimation(animation) {
                    regionHeight = height
                }
            }
            .task(id: removal) {
                guard let removal else {
                    return
                }

                // 视图消失或换了移除时刻时任务被取消，不更新
                do {
                    try await Task.sleep(for: .seconds(removal.timeIntervalSinceNow))
                } catch {
                    return
                }

                // 醒来的时刻按挂钟可能略早于移除时刻，取两者较晚的，这一行一定移除
                now = max(Date(), removal)
            }
    }

    /// 区里列出的记录：本仓库、本次运行里的 Remote 页记录，进行中的与结束不到 `lingering` 秒的；顺序同 `activities`。
    ///
    /// 没有结束时间的都算进行中，状态已换成结束、输出还没收完的也留着。
    ///
    /// - Parameters:
    ///   - activities: Activity 的全部记录，最新的在前。
    ///   - repository: 所在窗口的仓库；还没有打开仓库时为 nil。
    ///   - now: 当前时间。
    static func items(
        of activities: [RepositoryActivity],
        in repository: RepositoryLocation?,
        now: Date
    ) -> [RepositoryActivity] {
        activities.filter { activity in
            guard
                activity.kind == .remote,
                !activity.isRestored,
                activity.repository == repository
            else {
                return false
            }

            guard let ended = activity.ended else {
                return true
            }

            return now < ended.addingTimeInterval(lingering)
        }
    }

    /// 区高：每行 `rowHeight`，最多露出 `visibleRows` 行；没有行时为 0。
    ///
    /// - Parameter rows: 区里的行数。
    static func height(rows: Int) -> CGFloat {
        CGFloat(min(rows, visibleRows)) * rowHeight
    }

    /// 分隔线与可滚动的行；第一行出现时展开、内容淡入，最后一行移除后收起，行本身直接出现、消失。
    ///
    /// - Parameter rows: 区里列出的记录。
    private func region(_ rows: [RepositoryActivity]) -> some View {
        VStack(spacing: 0) {
            if !rows.isEmpty {
                Divider()
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(rows) { activity in
                        SidebarActivityRow(
                            activity: activity,
                            showsSeparator: activity.id != rows.first?.id,
                            showActivity: showActivity
                        )
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .opacity(regionHeight > 0 ? 1 : 0)
            .frame(height: regionHeight)
            .accessibilityHidden(rows.isEmpty)
        }
    }
}

// MARK: - SidebarActivityRow

/// 活动区的一行：图标与标题，进度条与停止按钮，进度摘要；进度条与摘要随记录实时更新，点停止按钮以外的地方打开 Activity 窗口。
struct SidebarActivityRow: View {
    /// 这一行的记录。
    let activity: RepositoryActivity

    /// 行顶画分隔线；第二行起才有。
    let showsSeparator: Bool

    /// 打开 Activity 窗口。
    let showActivity: () -> Void

    /// 进度条的值：完成与失败满格；进行中与取消取记录当时的进度，还没有进度时为 0。
    var progress: Double {
        switch activity.state {
        case "activity.finished", "activity.failed": 1
        default: activity.progress ?? 0
        }
    }

    /// 停止按钮可用：记录还在进行且有取消入口；结束后按钮仍在、不可用。
    var canCancel: Bool {
        !activity.isEnded && activity.cancel != nil
    }

    /// 行高固定，内容距上 8、左右 14；分隔线左右各缩进 14，不另占高度。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleLine

            progressLine

            summaryLine
        }
        .padding(.top, 8)
        .padding(.horizontal, 14)
        .frame(
            maxWidth: .infinity,
            minHeight: SidebarActivityView.rowHeight,
            maxHeight: SidebarActivityView.rowHeight,
            alignment: .topLeading
        )
        .overlay(alignment: .top) {
            if showsSeparator {
                Divider()
                    .padding(.horizontal, 14)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: showActivity)
    }

    /// 第一行：18 pt 宽的格子里按传输方向的图标，右边 6 pt 起是 11 pt 的标题，两者垂直居中。
    private var titleLine: some View {
        HStack(spacing: 6) {
            transferIcon
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(activity.displayTitle)
                .font(.system(size: 11))
                .lineLimit(1)
                .help(activity.displayTitle)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { showActivity() }
        }
    }

    /// 传输方向的自绘图标，缩放到 14 × 14，与 Activity 窗口里已结束的行一样大。
    private var transferIcon: some View {
        activity.transferIcon.image
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)
    }

    /// 第二行：进度条与右边 7 pt 处的停止按钮。
    private var progressLine: some View {
        HStack(spacing: 7) {
            ProgressView(value: progress)

            Button {
                activity.cancel?()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(!canCancel)
            .accessibilityLabel(AppLocalization.text("action.cancel"))
        }
        .frame(height: 20)
    }

    /// 第三行：11 pt 次级色的进度摘要，是 git 输出的最后一行；还没有输出时空着。
    private var summaryLine: some View {
        let summary = activity.lastLine ?? ""

        return Text(summary)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .help(summary)
    }
}
