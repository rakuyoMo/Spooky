import AppKit
import SwiftUI

// MARK: - ActivityWindowController

/// Activity 保留所有窗口的操作记录与原始日志；工具栏切换 Remote、Repository、Service 三页，清除与搜索只作用于当前页。
@MainActor
final class ActivityWindowController: NSWindowController, NSToolbarDelegate {
    /// 窗口列出的记录。
    let activities: RepositoryActivities

    /// 当前页与搜索词，工具栏与内容共用。
    let state: ActivityWindowState

    /// 551 × 299 pt 的初始内容分为活动列表与日志两栏，清除、分页与搜索放在工具栏。
    ///
    /// - Parameter activities: 窗口列出的记录，默认是 App 内唯一的活动列表。
    init(activities: RepositoryActivities = .shared) {
        let state = ActivityWindowState()
        self.activities = activities
        self.state = state

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 551, height: 299),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppLocalization.text("activity.title")
        window.contentViewController = NSHostingController(rootView: ActivityView(activities: activities, state: state))
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed

        super.init(window: window)

        // 工具栏会改变窗口的外框，先装好再定尺寸与位置
        configureToolbar()

        // 装入内容会把窗口缩到 SwiftUI 的理想尺寸，先回到初始尺寸；有保存的位置与尺寸时沿用，否则居中。
        window.setContentSize(NSSize(width: 551, height: 299))

        if !window.setFrameUsingName("Spooky.Activity") {
            window.center()
        }

        window.setFrameAutosaveName("Spooky.Activity")
    }

    /// 活动窗口只由代码创建。
    required init?(coder _: NSCoder) { nil }
}

// MARK: - ActivityWindowState

/// Activity 窗口当前的页与搜索词：工具栏写入，列表据此过滤。
@MainActor
@Observable
final class ActivityWindowState {
    /// 当前页，第一次打开是 Remote。
    var kind = ActivityKind.remote

    /// 工具栏搜索框里的文字。
    var query = ""

    /// 当前页里仓库名或日志含有搜索词的记录，忽略大小写；搜索词为空时列出整页。
    ///
    /// - Parameter items: 全部记录，最新的在前。
    /// - Returns: 保持原有顺序的当前页记录。
    func visibleItems(in items: [RepositoryActivity]) -> [RepositoryActivity] {
        items.filter { activity in
            guard activity.kind == kind else {
                return false
            }

            guard !query.isEmpty else {
                return true
            }

            return activity.repository.name.localizedCaseInsensitiveContains(query)
                || activity.log.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - ActivityView

/// 当前页的记录列表与所选记录的日志，日志可选择复制。
private struct ActivityView: View {
    /// 跨仓库活动数据。
    let activities: RepositoryActivities

    /// 工具栏选的页与搜索词。
    let state: ActivityWindowState

    /// 当前查看的活动。
    @State
    private var selected: UUID?

    /// 当前页里符合搜索词的记录。
    private var visible: [RepositoryActivity] {
        state.visibleItems(in: activities.items)
    }

    /// 左列表与右日志保持独立滚动；换页、清除或搜索后，所选记录不在列表里时选中第一条。
    var body: some View {
        HSplitView {
            activityList

            logPane
        }
        .onChange(of: visible.map(\.id), initial: true) { _, ids in
            if let selected, ids.contains(selected) {
                return
            }

            selected = ids.first
        }
    }

    /// 左栏活动列表。
    private var activityList: some View {
        List(visible, selection: $selected) { activity in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.repository.name)
                    Spacer()
                    Text(activity.started, style: .time)
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

                Text(activity.title).font(.system(size: 12, weight: .semibold))

                HStack {
                    Text(AppLocalization.text(activity.state)).font(.system(size: 11))
                    Spacer()
                    if let cancel = activity.cancel {
                        Button(action: cancel) { Image(systemName: "stop.circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(AppLocalization.text("action.cancel"))
                    }
                }
            }
            .frame(minHeight: 59)
            .tag(activity.id)
        }
        .frame(minWidth: 200, idealWidth: 220)
    }

    /// 右栏显示所选活动的仓库路径与原始日志，未选时显示空状态。
    @ViewBuilder
    private var logPane: some View {
        if let activity = visible.first(where: { $0.id == selected }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(activity.repository.displayPath)
                    .font(.system(size: 11))
                    .textSelection(.enabled)

                ScrollView {
                    Text(activity.log)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .defaultScrollAnchor(.bottom)
            }
            .padding(20)
            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text(AppLocalization.text("activity.empty"))
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
