import SpookyKit
import SwiftUI

// MARK: - RepositorySettingsView

/// 仓库设置：头部是齿轮图标、仓库名与 General | Git LFS | Ignores | Excludes 分段，下面是设置表格。
///
/// 设置在仓库所在的机器上读写：配置只写仓库本地配置，规则文件经编辑器打开，服务器仓库经临时副本写回。
struct RepositorySettingsView: View {
    /// 四个分段。
    enum Page: CaseIterable, Hashable {
        /// 描述、Issue 追踪、提交人身份、折行与签名。
        case general

        /// `.gitattributes` 里交给 Git LFS 的规则。
        case lfs

        /// `.gitignore` 的规则。
        case ignores

        /// `info/exclude` 的规则。
        case excludes

        /// 分段里的标题。
        var title: String {
            switch self {
            case .general: AppLocalization.text("repositorySettings.general")
            case .lfs: AppLocalization.text("repositorySettings.lfs")
            case .ignores: AppLocalization.text("repositorySettings.ignores")
            case .excludes: AppLocalization.text("repositorySettings.excludes")
            }
        }
    }

    /// 所在窗口的会话。
    let session: RepositorySession

    /// 当前分段，不随仓库保存。
    @State
    private var page = Page.general

    /// 读出的本地配置与规则文件；读取前为 nil。
    @State
    private var settings: RepositorySettings?

    /// 读出的描述与提交人身份；读取前为 nil。
    @State
    private var summary: RepositorySummary?

    /// 仓库所在机器上 Git LFS 的版本与仓库是否启用了它；读取前为 nil。
    @State
    private var lfs: LFSStatus?

    /// 读取失败的说明与原文。
    @State
    private var failure: AppFailure?

    /// 头部固定 52 pt，内容区可滚动。
    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let failure {
                        FailureDetailsView(failure: failure)
                            .padding(20)
                    } else if let settings, let summary, let lfs {
                        content(settings, summary: summary, lfs: lfs)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 480, minHeight: 300)
        .task(id: ReloadKey(repository: session.repository, isWriting: session.isWriting)) { await load() }
    }
}

// MARK: - Layout

extension RepositorySettingsView {
    /// 写入结束与换仓库时重新读取。
    private struct ReloadKey: Equatable {
        /// 显示的仓库。
        let repository: RepositoryLocation?

        /// 是否有写操作在进行。
        let isWriting: Bool
    }

    /// 32 pt 齿轮图标、仓库名与右侧分段。
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape")
                .font(.system(size: 22))
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Text(session.repository?.name ?? "")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Picker("", selection: $page) {
                ForEach(Page.allCases, id: \.self) { page in
                    Text(page.title).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel(AppLocalization.text("repositorySettings.title"))
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    /// 当前分段的内容。
    @ViewBuilder
    private func content(_ settings: RepositorySettings, summary: RepositorySummary, lfs: LFSStatus) -> some View {
        switch page {
        case .general:
            RepositoryGeneralSettings(session: session, settings: settings, summary: summary)

        case .lfs:
            RepositoryLFSSettings(session: session, file: settings.lfs, status: lfs)

        case .ignores:
            RepositoryRuleList(session: session, title: "repositorySettings.ignores.patterns", file: settings.ignore)

        case .excludes:
            RepositoryRuleList(session: session, title: "repositorySettings.excludes.patterns", file: settings.exclude)
        }
    }

    /// 读取本地配置、规则文件、概况与 Git LFS 的情况；写入进行中时等它结束后再读。
    private func load() async {
        guard let runner = session.runner, !session.isWriting else {
            return
        }

        do {
            async let settings = runner.repositorySettings()
            async let summary = runner.repositorySummary()
            async let lfs = RepositoryLFS(runner: runner).status()
            let loaded = try await (settings, summary, lfs)

            try Task.checkCancellation()
            (self.settings, self.summary, self.lfs) = loaded
            failure = nil
        } catch {
            guard !Task.isCancelled else { return }
            failure = AppFailure(error: error, opening: false, location: session.repository)
        }
    }
}

// MARK: - RepositoryRuleList

/// Ignores 与 Excludes 两段：分组标题带 “Open in Editor”，下面每条规则一行，用等宽字体。
private struct RepositoryRuleList: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 分组标题的资源键。
    let title: String

    /// 规则文件。
    let file: RuleFile

    /// 分组标题、规则行与没有规则时的说明。
    var body: some View {
        RemoteSettingsGroup(
            title: AppLocalization.text(title),
            actions: [
                RemoteSettingAction(
                    title: AppLocalization.text("repositorySettings.openInEditor"),
                    isEnabled: session.repository != nil,
                    perform: { session.edit(file) }
                ),
            ]
        )

        if file.patterns.isEmpty {
            RemoteSettingRow(label: AppLocalization.text("repositorySettings.noPatterns"), value: "")
        }

        ForEach(Array(file.patterns.enumerated()), id: \.offset) { _, pattern in
            RemoteSettingRow(label: "", value: pattern)
                .monospaced()
        }
    }
}
