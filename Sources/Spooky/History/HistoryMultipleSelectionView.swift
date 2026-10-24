import AppKit
import SwiftUI

// MARK: - HistoryMultipleSelectionView

/// 历史里选中多个提交时的详情：“N commits selected”，下面在看 HEAD 分支时是 Revert，否则是 Cherry-Pick；
/// 恰好两个时再加 Compare 按钮，按住 ⌥ 时反向比较。
struct HistoryMultipleSelectionView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// ⌥ 是否按下。
    @State
    private var optionDown = false

    /// 修饰键的本地监听，视图消失时移除。
    @State
    private var monitor: Any? = nil

    /// 图标、选中数与比较按钮居中排列。
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Text(AppLocalization.text("history.multiple", session.history.selectedIDs.count))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                pickButton

                if let (newer, older) = session.comparedCommits {
                    Button(
                        optionDown
                            ? AppLocalization.text("compare.selected", newer.shortID, older.shortID)
                            : AppLocalization.text("compare.submit")
                    ) {
                        session.compareSelectedCommits(reversed: optionDown)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: startMonitoring)
        .onDisappear(perform: stopMonitoring)
    }

    /// 在看 HEAD 分支时反转所选提交，否则把它们摘取到 HEAD；按列表顺序传入。
    private var pickButton: some View {
        let history = session.history
        let ids = history.commits.filter { history.selectedIDs.contains($0.id) }.map(\.id)

        return Button(AppLocalization.text(session.isViewingHead ? "rewrite.revert.button" : "rewrite.cherryPick.button")) {
            if session.isViewingHead {
                session.requestRevert(ids)
            } else {
                session.requestCherryPick(ids)
            }
        }
        .disabled(!session.canRewrite || ids.isEmpty)
    }

    /// 监听修饰键变化；窗口失去焦点时按键状态以下一次事件为准。
    private func startMonitoring() {
        optionDown = NSEvent.modifierFlags.contains(.option)

        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            MainActor.assumeIsolated {
                optionDown = event.modifierFlags.contains(.option)
            }

            return event
        }
    }

    /// 移除监听。
    private func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        monitor = nil
    }
}
