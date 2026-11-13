import AppKit
import SpookyKit
import SwiftUI

// MARK: - FileViewAction

/// 文件视图的一个动作，动作条按钮、头部右键菜单与工作区文件列表的右键菜单共用。
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

    /// 文件头使用分段组，评论附件使用独立按钮。
    var segmented = true

    /// 原生分段组是否获得键盘焦点。
    @State
    private var segmentFocused = false

    /// 获得键盘焦点的按钮。
    @FocusState
    private var focused: String?

    /// 隐藏时保留占位与键盘入口，悬停或获得焦点时淡入。
    var body: some View {
        Group {
            if segmented {
                FileActionSegments(actions: actions) { segmentFocused = $0 }
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 2) {
                    ForEach(actions) { action in
                        Button(action.title, action: action.perform)
                            .disabled(!action.enabled)
                            .focused($focused, equals: action.id)
                    }
                }
                .buttonStyle(.accessoryBar)
                .controlSize(.regular)
            }
        }
        .frame(height: 25)
        .opacity(visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: visible)
    }

    /// 鼠标与键盘任一入口都能显示动作。
    private var visible: Bool { hovering || focused != nil || segmentFocused }
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

/// 执行文件视图动作的 AppKit 菜单项，工作区文件列表的右键菜单使用。
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

/// 提交变更集里文件的右键菜单：复制路径、查看这个版本、文件历史、比较工具、恢复到工作区与导出。
///
/// 作用于右键时实际作用的文件：点在选区里是整个选区，点在选区外只是被点的那一个。
struct ChangesetFileMenu: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 实际作用的文件，按变更集里的顺序。
    let files: [CommitFileChange]

    /// 文件所在的提交。
    let commit: HistoryCommit

    /// 目录对象与未解析的目标禁用内容读取，文件动作保持各自的能力。
    var contentEnabled = true

    /// 各组之间有分隔线。
    var body: some View {
        let groups = Self.groups(session: session, files: files, commit: commit, contentEnabled: contentEnabled)

        ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
            if index > 0 {
                Divider()
            }

            ForEach(group) { action in
                Button(action.title, action: action.perform)
                    .disabled(!action.enabled)
            }
        }
    }

    /// 菜单的各组动作。
    ///
    /// 单个文件时标题写仓库内的完整路径，有查看、Blame 与文件历史；多个文件时标题写数量，只有比较工具、恢复与导出。
    ///
    /// - Parameters:
    ///   - session: 当前仓库会话。
    ///   - files: 实际作用的文件。
    ///   - commit: 文件所在的提交。
    ///   - contentEnabled: 能否读取文件内容。
    static func groups(
        session: RepositorySession,
        files: [CommitFileChange],
        commit: HistoryCommit,
        contentEnabled: Bool
    ) -> [[FileViewAction]] {
        guard let file = files.first else {
            return []
        }

        let paths = files.map(\.path)
        let compared = files.map { ComparedFile(path: $0.path, originalPath: $0.originalPath) }
        let copy = copyActions(session: session, paths: paths)

        guard files.count == 1 else {
            return [
                copy,
                [
                    FileViewAction(title: AppLocalization.text("externalTool.openDiffItemsAt", files.count, commit.shortID)) {
                        session.openDiffTool(for: commit, files: compared)
                    },
                ],
                [
                    FileViewAction(
                        title: AppLocalization.text("tree.restoreItems", files.count, commit.shortID),
                        enabled: session.canWrite
                    ) {
                        session.restoreItems(paths, at: commit.id)
                    },
                    FileViewAction(
                        title: AppLocalization.text("tree.exportItems", files.count, commit.shortID),
                        enabled: contentEnabled
                    ) {
                        session.onRevisionRequest?(.export(revision: commit.id, paths: paths, archive: false))
                    },
                ],
            ]
        }

        let path = file.path

        return [
            copy,
            [
                FileViewAction(
                    title: AppLocalization.text("fileHistory.showAt", path, commit.shortID),
                    enabled: contentEnabled
                ) {
                    session.showFile(path, at: commit.id, mode: .raw)
                },
                FileViewAction(
                    title: AppLocalization.text("fileHistory.blameAt", path, commit.shortID),
                    enabled: contentEnabled
                ) {
                    session.showFile(path, at: commit.id, mode: .blame)
                },
                FileViewAction(title: AppLocalization.text("fileHistory.showHistoryOf", path)) {
                    session.showFileHistory(path)
                },
            ],

            // 与提交的第一个父提交比较
            [
                FileViewAction(title: AppLocalization.text("externalTool.openDiffAt", path, commit.shortID)) {
                    session.openDiffTool(for: commit, files: compared)
                },
            ],
            [
                FileViewAction(
                    title: AppLocalization.text("fileHistory.restoreInWorkingCopy", path, commit.shortID),
                    enabled: session.canWrite
                ) {
                    session.restoreFile(path, at: commit.id)
                },
                FileViewAction(
                    title: AppLocalization.text("fileHistory.exportAt", path, commit.shortID),
                    enabled: contentEnabled
                ) {
                    session.exportFile(path, at: commit.id)
                },
            ],
        ]
    }

    /// Copy File Path 与 Copy Relative File Path，比较视图的变更集菜单同样使用。
    ///
    /// - Parameters:
    ///   - session: 当前仓库会话。
    ///   - paths: 实际作用的文件。
    static func copyActions(session: RepositorySession, paths: [String]) -> [FileViewAction] {
        [
            FileViewAction(title: AppLocalization.text("workspace.copyPathMenu")) {
                session.copyPaths(paths, relative: false)
            },
            FileViewAction(title: AppLocalization.text("working.copyRelative")) {
                session.copyPaths(paths, relative: true)
            },
        ]
    }
}
