import AppKit
import SwiftUI

// MARK: - ActivityWindowController

/// Activity 保留所有窗口的同步记录与原始日志。
@MainActor
final class ActivityWindowController: NSWindowController {
    /// 551 × 299 pt 的初始窗口分为活动列表与日志两栏。
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 551, height: 299),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppLocalization.text("activity.title")
        window.contentViewController = NSHostingController(rootView: ActivityView())
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed

        // 装入内容会把窗口缩到 SwiftUI 的理想尺寸，先回到初始尺寸；有保存的位置与尺寸时沿用，否则居中。
        window.setContentSize(NSSize(width: 551, height: 299))

        if !window.setFrameUsingName("Spooky.Activity") {
            window.center()
        }

        window.setFrameAutosaveName("Spooky.Activity")
        super.init(window: window)
    }

    /// 活动窗口只由代码创建。
    required init?(coder _: NSCoder) { nil }
}

// MARK: - ActivityView

/// 列表包含进行中与已完成操作，日志可选择复制。
private struct ActivityView: View {
    /// 跨仓库活动数据。
    @Bindable
    private var activities = RepositoryActivities.shared

    /// 当前查看的活动。
    @State
    private var selected: UUID?

    /// 按仓库或日志筛选。
    @State
    private var query = ""

    /// 左列表与右日志保持独立滚动。
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(AppLocalization.text("activity.clear")) { activities.clearCompleted() }
                TextField(AppLocalization.text("activity.search"), text: $query)
            }
            .padding(8)
            Divider()
            HSplitView {
                activityList

                logPane
            }
        }
        .onChange(of: activities.items.count) {
            if selected == nil { selected = activities.items.first?.id }
        }
        .onAppear { selected = activities.items.first?.id }
    }

    /// 左栏活动列表，按仓库路径或日志内容筛选。
    private var activityList: some View {
        List(
            activities.items.filter {
                query.isEmpty || $0.repository.displayPath.localizedCaseInsensitiveContains(query)
                    || $0.log.localizedCaseInsensitiveContains(query)
            },
            selection: $selected
        ) { activity in
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
        if let activity = activities.items.first(where: { $0.id == selected }) {
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
