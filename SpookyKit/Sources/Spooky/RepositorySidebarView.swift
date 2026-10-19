import SwiftUI

/// 仓库的两个主视图入口及工作区读取反馈。
struct RepositorySidebarView: View {
    /// 当前仓库会话。
    @Bindable var session: RepositorySession

    /// 切换主视图后由窗口替换右侧内容。
    let selectionChanged: () -> Void

    /// 仓库级系统动作和复制路径入口。
    let openTerminal: () -> Void

    /// Finder 动作只对本机启用。
    let revealFinder: () -> Void

    /// 复制可区分主机的仓库路径。
    let copyPath: () -> Void

    /// 系统侧边栏样式，保持随系统字号变化的行尺寸。
    var body: some View {
        List(selection: $session.activeView) {
            Section(AppLocalization.text("workspace.group")) {
                HStack {
                    Label(AppLocalization.text("workspace.title"), systemImage: "folder")
                    Spacer(minLength: 4)

                    if session.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel(AppLocalization.text("loading.status"))
                    } else if let status = session.status {
                        Text(status.entries.count.formatted())
                            .font(.system(size: 11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppPalette.color("sidebarBadgeBackgroundColor"), in: Capsule())
                            .accessibilityLabel(AppLocalization.text("workspace.changed", status.entries.count))
                    }
                }
                .tag(RepositoryView.workingCopy)
                .contextMenu {
                    Button(AppLocalization.text("action.openTerminal"), action: openTerminal)
                    Button(AppLocalization.text("action.revealFinder"), action: revealFinder)
                        .disabled(session.repository?.localURL == nil)
                    Button(AppLocalization.text("action.copyPath"), action: copyPath)
                }

                Label(AppLocalization.text("history.title"), systemImage: "clock")
                    .tag(RepositoryView.history)
            }
        }
        .listStyle(.sidebar)
        .onChange(of: session.activeView) { selectionChanged() }
        .overlay(alignment: .bottom) {
            if session.isOpening {
                ProgressView(AppLocalization.text("loading.open"))
                    .controlSize(.small)
                    .padding()
            }
        }
    }
}
