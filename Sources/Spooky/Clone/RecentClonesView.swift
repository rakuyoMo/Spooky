import AppKit
import SpookyKit
import SwiftUI

// MARK: - RecentClonesView

/// 工具栏 Clone 项弹出的最近克隆：标题与 Clear，下面每个克隆一行，按状态给出停止、重试、移除或在 Finder 中显示。
///
/// 双击已完成的一行打开仓库；右键菜单另有打开、Finder 或复制路径、终端、重试、取消与移除。
struct RecentClonesView: View {
    /// App 内最近的克隆。
    let clones: CloneActivities

    /// 在发起的窗口打开克隆好的仓库。
    let open: (RepositoryLocation) -> Void

    /// 在终端中打开克隆好的仓库。
    let openInTerminal: (RepositoryLocation) -> Void

    /// 标题栏与列表，480 × 400。
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(AppLocalization.text("clone.recent.title"))
                    .font(.system(size: 13))

                Spacer()

                Button(AppLocalization.text("clone.recent.clear"), action: clones.clear)
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
                    .disabled(!clones.items.contains { !$0.isRunning })
            }
            .padding(.horizontal, 12)
            .frame(height: 32)

            Divider()

            List(clones.items) { activity in
                RecentCloneRow(activity: activity, clones: clones)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if activity.isFinished {
                            open(activity.clone.destination)
                        }
                    }
                    .contextMenu { menu(for: activity) }
            }
            .listStyle(.plain)
        }
        .frame(width: 480, height: 400)
    }

    /// 一行的右键菜单。
    @ViewBuilder
    private func menu(for activity: CloneActivity) -> some View {
        let destination = activity.clone.destination

        Button(AppLocalization.text("action.open")) { open(destination) }
            .disabled(!activity.isFinished)

        if let url = destination.localURL {
            Button(AppLocalization.text("action.revealFinder")) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            .disabled(!activity.isFinished)
        } else {
            Button(AppLocalization.text("action.copyPath")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(destination.displayPath, forType: .string)
            }
        }

        Button(AppLocalization.text("action.openTerminal")) { openInTerminal(destination) }
            .disabled(!activity.isFinished)

        Divider()

        Button(AppLocalization.text("clone.retry")) { clones.restart(activity) }
            .disabled(activity.isRunning || activity.isFinished)

        Button(AppLocalization.text("clone.cancel"), action: activity.cancel)
            .disabled(!activity.isRunning)

        Button(AppLocalization.text("clone.remove")) { clones.remove(activity) }
    }
}

// MARK: - RecentCloneRow

/// 最近克隆的一行：图标、名称、进度或结果，以及按状态出现的按钮。
private struct RecentCloneRow: View {
    /// 这一行的克隆。
    let activity: CloneActivity

    /// 重试与移除经它执行。
    let clones: CloneActivities

    /// 32 pt 图标、名称与状态两行、右侧的按钮。
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if activity.isRunning {
                    CloneProgressBar(progress: activity.progress)
                        .controlSize(.small)
                }

                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            buttons
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// 克隆中与完成是仓库图标，失败时加上警告。
    private var icon: String {
        if case .failed = activity.state {
            return "exclamationmark.triangle"
        }

        return "externaldrive"
    }

    /// 状态说明：进度、已取消、错误标题或已完成。
    private var status: String {
        switch activity.state {
        case .running(let progress): CloneProgressBar.status(progress)
        case .cancelled: AppLocalization.text("clone.state.cancelled")
        case .failed(let failure): failure.title
        case .finished: AppLocalization.text("clone.state.finished")
        }
    }

    /// 进行中可以停止；取消与失败可以重试与移除；完成的本机仓库可以在 Finder 中显示。
    @ViewBuilder
    private var buttons: some View {
        switch activity.state {
        case .running:
            iconButton("xmark.circle.fill", label: "clone.cancel", action: activity.cancel)

        case .cancelled, .failed:
            iconButton("arrow.clockwise", label: "clone.retry") { clones.restart(activity) }
            iconButton("minus.circle", label: "clone.remove") { clones.remove(activity) }

        case .finished:
            if let url = activity.clone.destination.localURL {
                iconButton("magnifyingglass.circle", label: "action.revealFinder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        }
    }

    /// 15 pt 的无边框图标按钮。
    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 15, height: 15)
        }
        .buttonStyle(.borderless)
        .help(AppLocalization.text(label))
        .accessibilityLabel(AppLocalization.text(label))
    }
}
