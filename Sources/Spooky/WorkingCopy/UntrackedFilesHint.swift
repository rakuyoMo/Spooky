import SpookyKit
import SwiftUI

// MARK: - UntrackedFilesHint

/// 服务器仓库的未跟踪文件过多时，工作区文件列表上方的提示：建议补充忽略规则，并可以在确认后加快 B 上的状态读取。
///
/// 加快的办法都写进 B 上这个仓库的本地配置，只在用户确认后执行；关闭提示后这个仓库不再显示。
struct UntrackedFilesHint: View {
    /// 未跟踪文件达到这个数量时提示。
    static let threshold = 1000

    /// 关闭过提示的仓库位置的偏好键，值为带主机前缀的路径。
    static let dismissedKey = "dismissedUntrackedFilesHints"

    /// 工作区所在的会话。
    let session: RepositorySession

    /// 正在显示加快状态读取的确认对话框。
    @State
    private var isConfirming = false

    /// 关闭过提示的仓库，每次关闭后刷新。
    @State
    private var dismissed = Set(UserDefaults.standard.stringArray(forKey: dismissedKey) ?? [])

    /// 一行说明、加快按钮与关闭按钮；不满足条件时不占位置。
    var body: some View {
        if let repository = session.repository, isVisible(for: repository) {
            HStack(spacing: 8) {
                Image(systemName: "speedometer")
                    .accessibilityHidden(true)

                Text(AppLocalization.text("untracked.hint", untrackedCount))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button(AppLocalization.text("untracked.speedUp")) { isConfirming = true }
                    .controlSize(.small)
                    .disabled(!session.canWrite)

                Button {
                    dismiss(repository)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(AppLocalization.text("action.close"))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .sheet(isPresented: $isConfirming) {
                SpeedUpStatusDialog(host: repository.host ?? "", close: { isConfirming = false }) {
                    speedUp()
                }
            }

            Divider()
        }
    }
}

// MARK: - Private

extension UntrackedFilesHint {
    /// 当前状态里未跟踪文件的数量。
    private var untrackedCount: Int {
        session.status?.entries.filter { $0.kind == .untracked }.count ?? 0
    }

    /// 服务器仓库的未跟踪文件达到阈值，且这个仓库没有关闭过提示。
    private func isVisible(for repository: RepositoryLocation) -> Bool {
        repository.host != nil && untrackedCount >= Self.threshold && !dismissed.contains(repository.displayPath)
    }

    /// 记下关闭过提示的仓库。
    private func dismiss(_ repository: RepositoryLocation) {
        dismissed.insert(repository.displayPath)
        UserDefaults.standard.set(Array(dismissed).sorted(), forKey: Self.dismissedKey)
    }

    /// 在 B 上这个仓库的本地配置里打开未跟踪文件缓存与文件监听，写出 commit-graph 并在获取时更新。
    private func speedUp() {
        _ = session.performGit(
            { runner, _ in
                try await runner.setLocalConfig("core.untrackedCache", to: "true")
                try await runner.setLocalConfig("core.fsmonitor", to: "true")
                try await runner.setLocalConfig("fetch.writeCommitGraph", to: "true")
                _ = try await runner.execute(["commit-graph", "write", "--reachable"])
            },
            title: AppLocalization.text("untracked.speedUp.title")
        )
    }
}

// MARK: - SpeedUpStatusDialog

/// 加快状态读取前的确认：列出要写进 B 上仓库配置的三项与各自的作用。
private struct SpeedUpStatusDialog: View {
    /// 仓库所在的主机别名。
    let host: String

    /// 关闭对话框。
    let close: () -> Void

    /// 确认后执行。
    let submit: () -> Void

    /// 三项设置与说明。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("untracked.speedUp.title"),
            message: AppLocalization.text("untracked.speedUp.message", host),
            submitTitle: AppLocalization.text("untracked.speedUp.apply"),
            error: nil,
            canSubmit: true,
            cancel: close,
            submit: {
                close()
                submit()
            }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                item("core.untrackedCache", "untracked.speedUp.cache")
                item("core.fsmonitor", "untracked.speedUp.monitor")
                item("commit-graph", "untracked.speedUp.graph")
            }
            .padding(.leading, DialogMetrics.alignment)
            .padding(.trailing, 20)
            .padding(.vertical, 12)
        }
    }

    /// 一项设置：等宽的名称与一句说明。
    private func item(_ name: String, _ key: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: name)
                .font(.system(size: 12, design: .monospaced))

            Text(AppLocalization.text(key))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
