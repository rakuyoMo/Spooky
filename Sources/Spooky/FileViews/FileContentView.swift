import AppKit
import SpookyKit
import SwiftUI

// MARK: - FileContentView

/// 文件原文与 Blame 共用的整页视图：头部是 “版本 › 文件” 导航与 Raw / Blame 切换，第二行是贡献者数。
struct FileContentView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 原文、追溯与贡献者的读取状态。
    @Bindable
    var state: FileContentState

    /// 鼠标是否在头部上，决定动作条是否显示。
    @State
    private var hovering = false

    /// 版本选择器是否打开。
    @State
    private var choosingRevision = false

    /// 文件选择器是否打开。
    @State
    private var choosingFile = false

    /// 内置主题随系统外观切换。
    @Environment(\.colorScheme)
    private var colorScheme

    /// 连接横幅、两行头部与内容。
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(session: session)

            header
            contributorsRow
            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 版本按钮 › 文件按钮，右侧是悬停出现的动作条与 Raw / Blame 分段控件。
    private var header: some View {
        HStack(spacing: 8) {
            revisionButton

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Image(systemName: "doc")
                .font(.system(size: 18))
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            fileButton

            Spacer(minLength: 8)

            FileActionBar(actions: navigationActions, hovering: hovering)

            Picker("", selection: $state.mode) {
                Text(AppLocalization.text("showFile.raw")).tag(FileContentMode.raw)
                Text(AppLocalization.text("blame.title")).tag(FileContentMode.blame)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 112)
        }
        .buttonStyle(.accessoryBar)
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(AppPalette.color("general_header_background_color"))
        .modifier(FileActionHeader(actions: headerActions, hovering: $hovering))
    }

    /// 版本按钮：显示短哈希或 HEAD，点开版本选择器。
    private var revisionButton: some View {
        Button(state.revision.map { String($0.prefix(8)) } ?? "HEAD") {
            choosingRevision = true
        }
        .font(.system(size: 13, design: .monospaced))
        .accessibilityLabel(AppLocalization.text("showFile.revision"))
        .popover(isPresented: $choosingRevision, arrowEdge: .bottom) {
            RevisionSelectorView(session: session, path: state.path ?? "") {
                state.select(revision: $0)
                choosingRevision = false
            }
        }
    }

    /// 文件按钮：显示路径，点开同一版本的文件选择器。
    private var fileButton: some View {
        Button(state.path ?? "") {
            choosingFile = true
        }
        .lineLimit(1)
        .truncationMode(.middle)
        .help(state.path ?? "")
        .accessibilityLabel(AppLocalization.text("showFile.file"))
        .popover(isPresented: $choosingFile, arrowEdge: .bottom) {
            FileSelectorView(session: session, revision: state.resolvedRevision) {
                state.select(path: $0)
                choosingFile = false
            }
        }
        .layoutPriority(-1)
    }

    /// 修改过这个文件的作者数。
    private var contributorsRow: some View {
        HStack {
            Text(contributorsText)
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: .disabledControlTextColor))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
    }

    /// 贡献者数的文案，读取完成前为空。
    private var contributorsText: String {
        switch state.contributors?.count {
        case nil: ""
        case 0: AppLocalization.text("showFile.noContributors")
        case 1: AppLocalization.text("showFile.oneContributor")
        case let count?: AppLocalization.text("showFile.contributors", count)
        }
    }

    /// 动作条上的动作：文件历史与回到当前版本的提交。
    private var navigationActions: [FileViewAction] {
        let path = state.path ?? ""
        let revision = state.resolvedRevision

        return [
            FileViewAction(title: AppLocalization.text("fileHistory.title")) {
                session.showFileHistory(path)
            },
            FileViewAction(title: AppLocalization.text("fileHistory.showCommit"), enabled: revision != nil) {
                if let revision { session.showCommit(id: revision) }
            },
        ]
    }

    /// 头部右键菜单的动作：动作条上的动作，再加复制、导出与用默认程序打开。
    private var headerActions: [FileViewAction] {
        let revision = state.resolvedRevision
        let available = revision != nil && state.content?.data != nil

        return navigationActions
            + contentActions(path: state.path ?? "", revision: revision, available: available)
    }

    /// 读取完成后才显示的内容：失败、不能显示的说明、原文或逐行追溯。
    @ViewBuilder
    private var content: some View {
        if let failure = state.failure {
            FailureDetailsView(failure: failure) { state.load() }
                .padding(20)
        } else if state.mode == .blame, state.resolvedRevision == nil {
            FileNoticeView(message: AppLocalization.text("blame.noRevision"))
        } else if let content = state.content {
            if let reason = content.unavailable {
                FileNoticeView(message: Self.notice(for: reason, mode: state.mode))
            } else {
                text(content)
            }
        } else {
            ProgressView(AppLocalization.text(state.mode == .blame ? "blame.loading" : "showFile.loading"))
                .controlSize(.small)
        }
    }

    /// 不能显示的原因对应的说明。
    private static func notice(for reason: FileUnavailableReason, mode: FileContentMode) -> String {
        switch (reason, mode) {
        case (.missing, .raw): AppLocalization.text("showFile.untracked")
        case (.binary, .raw): AppLocalization.text("showFile.binary")
        case (.submodule, .raw): AppLocalization.text("showFile.submodule")
        case (.missing, .blame): AppLocalization.text("blame.untracked")
        case (.binary, .blame): AppLocalization.text("blame.binary")
        case (.submodule, .blame): AppLocalization.text("blame.submodule")
        }
    }

    /// 复制、导出与用默认程序打开，二进制文件只能导出或打开。
    private func contentActions(path: String, revision: String?, available: Bool) -> [FileViewAction] {
        let text = available && state.content?.unavailable == nil

        return [
            FileViewAction(title: AppLocalization.text("showFile.copy"), enabled: text) {
                if let revision { session.copyFile(path, at: revision) }
            },
            FileViewAction(title: AppLocalization.text("showFile.export"), enabled: available) {
                if let revision { session.exportFile(path, at: revision) }
            },
            FileViewAction(title: AppLocalization.text("showFile.open"), enabled: available) {
                if let revision { session.openFile(path, at: revision) }
            },
        ]
    }

    /// 原文或逐行追溯的正文；逐行追溯读取完成前显示进度。
    @ViewBuilder
    private func text(_ content: FileRevisionContent) -> some View {
        let theme = BuiltinTheme.current(dark: colorScheme == .dark)
        let identity = content.path + "@" + (state.resolvedRevision ?? "")
        let menu = contentActions(path: content.path, revision: state.resolvedRevision, available: true)

        if state.mode == .raw {
            FileTextView(contentID: identity + "/raw", lines: content.lines, theme: theme, menuActions: menu)
        } else if let blame = state.blame {
            FileTextView(
                contentID: identity + "/blame",
                lines: state.blameLines,
                theme: theme,
                annotations: FileTextAnnotations(
                    groups: blame.groups,
                    commits: blame.commits,
                    highlightedCommit: state.highlightedCommit
                ),
                menuActions: menu,
                highlight: { state.highlightedCommit = $0 },
                openCommit: { session.showCommit(id: $0) }
            )
        } else {
            ProgressView(AppLocalization.text("blame.loading"))
                .controlSize(.small)
        }
    }
}
