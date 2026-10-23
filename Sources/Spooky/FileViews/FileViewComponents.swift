import AppKit
import SpookyKit
import SwiftUI

// MARK: - FileViewAction

/// 文件视图的一个动作，动作条按钮、头部右键菜单与正文右键菜单共用。
struct FileViewAction: Identifiable {
    /// 已本地化的标题，同一组动作里各不相同。
    let title: String

    /// 当前是否可用。
    var enabled = true

    /// 执行动作。
    let perform: () -> Void

    /// 标题即身份。
    var id: String { title }
}

// MARK: - FileActionBar

/// 详情头部的动作条：鼠标移进头部或键盘焦点移到按钮上时出现，头部的右键菜单提供同样的动作。
struct FileActionBar: View {
    /// 依次排列的动作。
    let actions: [FileViewAction]

    /// 鼠标是否在头部上。
    let hovering: Bool

    /// 获得键盘焦点的按钮。
    @FocusState
    private var focused: String?

    /// 文字按钮靠右排列，隐藏时仍保留位置与键盘焦点。
    var body: some View {
        HStack(spacing: 2) {
            ForEach(actions) { action in
                Button(action.title, action: action.perform)
                    .disabled(!action.enabled)
                    .focused($focused, equals: action.id)
            }
        }
        .buttonStyle(.accessoryBar)
        .controlSize(.small)
        .frame(height: 25)
        .opacity(hovering || focused != nil ? 1 : 0)
    }
}

// MARK: - FileActionHeader

/// 给 40 pt 的详情头部加上悬停状态与右键菜单，动作条的按钮因此有鼠标以外的入口。
struct FileActionHeader: ViewModifier {
    /// 右键菜单列出的动作。
    let actions: [FileViewAction]

    /// 鼠标是否在头部上，交给动作条决定是否显示。
    @Binding
    var hovering: Bool

    /// 悬停与右键菜单作用于整个头部。
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .contextMenu {
                ForEach(actions) { action in
                    Button(action.title, action: action.perform)
                        .disabled(!action.enabled)
                }
            }
    }
}

// MARK: - FileNoticeView

/// 不能显示内容时的一行说明，如二进制文件或版本中没有这个文件。
struct FileNoticeView: View {
    /// 已本地化的说明。
    let message: String

    /// 说明居中显示。
    var body: some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - FileViewMenuItem

/// 执行文件视图动作的 AppKit 菜单项，工作区文件列表与正文的右键菜单使用。
final class FileViewMenuItem: NSMenuItem {
    /// 选中菜单项时执行的动作。
    private let handler: () -> Void

    /// 按动作的标题与可用性创建菜单项。
    init(_ action: FileViewAction) {
        handler = action.perform
        super.init(title: action.title, action: #selector(performAction), keyEquivalent: "")

        target = self
        isEnabled = action.enabled
    }

    /// 菜单项由代码创建。
    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("FileViewMenuItem 不从归档恢复")
    }

    /// 执行动作。
    @objc
    private func performAction() {
        handler()
    }
}

// MARK: - ChangesetFileMenu

/// 提交变更集里一个文件的右键菜单：查看这个版本、文件历史、恢复到工作区与导出。
struct ChangesetFileMenu: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 变更集里的文件路径，重命名时是新路径。
    let path: String

    /// 文件所在的提交。
    let commit: HistoryCommit

    /// 查看组与恢复、导出组之间有分隔线。
    var body: some View {
        let name = RepositorySession.fileName(path)

        Button(AppLocalization.text("fileHistory.showAt", name, commit.shortID)) {
            session.showFile(path, at: commit.id, mode: .raw)
        }

        Button(AppLocalization.text("fileHistory.blameAt", name, commit.shortID)) {
            session.showFile(path, at: commit.id, mode: .blame)
        }

        Button(AppLocalization.text("fileHistory.showHistoryOf", name)) {
            session.showFileHistory(path)
        }

        Divider()

        Button(AppLocalization.text("fileHistory.restoreInWorkingCopy", name, commit.shortID)) {
            session.restoreFile(path, at: commit.id)
        }
        .disabled(!session.canWrite)

        Button(AppLocalization.text("fileHistory.exportAt", name, commit.shortID)) {
            session.exportFile(path, at: commit.id)
        }
    }
}
