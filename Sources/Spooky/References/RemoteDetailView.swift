import SpookyKit
import SwiftUI

// MARK: - RemoteDetailView

/// 远端视图：头部是图标、远端名与 General | Branches 分段，下面是设置表格或这个远端的分支。
struct RemoteDetailView: View {
    /// 两个分段。
    enum Page: Hashable {
        /// 名称、地址、选项与 refspec。
        case general

        /// 这个远端的远端分支。
        case branches
    }

    /// 所在窗口的会话。
    let session: RepositorySession

    /// 当前分段，不随仓库保存。
    @State
    private var page = Page.general

    /// 读出的远端设置；读取前与远端不存在时为 nil。
    @State
    private var configuration: RemoteConfiguration?

    /// 读取失败的说明。
    @State
    private var error = ""

    /// 头部固定 52 pt，内容区可滚动。
    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let configuration {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch page {
                        case .general:
                            RemoteGeneralSettings(session: session, configuration: configuration)

                        case .branches:
                            branchRows(of: configuration.name)
                        }
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                EmptyStateView(
                    title: AppLocalization.text("remote.missing"),
                    message: error,
                    symbol: "network.slash"
                )
            }
        }
        .frame(minWidth: 480, minHeight: 300)
        .task(id: reloadKey) { await load() }
    }
}

// MARK: - Layout

extension RemoteDetailView {
    /// 写入结束、引用变化与换远端时重新读取；服务器的定时轮询不会触发，免得每次轮询都多一次往返。
    private var reloadKey: ReloadKey {
        ReloadKey(remote: session.selectedRemote, isWriting: session.isWriting, snapshot: session.history.snapshot)
    }

    /// 32 pt 图标、远端名与右侧分段。
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 22))
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Text(session.selectedRemote ?? "")
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()

            Picker("", selection: $page) {
                Text(AppLocalization.text("remote.page.general")).tag(Page.general)
                Text(AppLocalization.text("remote.page.branches")).tag(Page.branches)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel(AppLocalization.text("remote.page"))
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    /// Branches 分段：分组标题与每个远端分支的名字和提交哈希，没有操作。
    @ViewBuilder
    private func branchRows(of remote: String) -> some View {
        let branches = session.history.branches.filter { session.remoteParts(of: $0)?.remote == remote }

        RemoteSettingsGroup(title: AppLocalization.text("remote.page.branches"))

        if branches.isEmpty {
            RemoteSettingRow(label: AppLocalization.text("branch.empty"), value: "")
        }

        ForEach(branches) { branch in
            RemoteSettingRow(
                label: session.remoteParts(of: branch)?.branch ?? branch.name,
                value: branch.objectID,
                small: true
            )
        }
    }

    /// 读出所选远端的设置；远端已不存在时显示空状态。
    private func load() async {
        guard let remote = session.selectedRemote, let runner = session.runner else {
            configuration = nil
            return
        }

        do {
            configuration = try await RepositoryRemotes(runner: runner).configurations().first { $0.name == remote }
            error = configuration == nil ? AppLocalization.text("remote.missing.message", remote) : ""
        } catch {
            if !Task.isCancelled {
                configuration = nil
                self.error = AppFailure(error: error, opening: false, location: session.repository).details
            }
        }
    }
}

// MARK: - ReloadKey

/// 远端视图重新读取设置的时机。
private struct ReloadKey: Equatable {
    /// 所选远端。
    let remote: String?

    /// 是否有写操作进行中；结束时重新读取。
    let isWriting: Bool

    /// 引用快照；远端增删改名后随之变化。
    let snapshot: ReferenceSnapshot?
}

// MARK: - RemoteGeneralSettings

/// General 分段：名称、获取与推送地址、自动获取排除项，以及 fetch 与 push 两组 refspec。
private struct RemoteGeneralSettings: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 远端设置。
    let configuration: RemoteConfiguration

    /// 各行依次排列，每行的操作按钮悬停时出现。
    var body: some View {
        let name = configuration.name

        RemoteSettingRow(
            label: AppLocalization.text("remote.field.name"),
            value: name,
            actions: [action("reference.rename") { session.requestReference(.renameRemote(name)) }]
        )

        RemoteSettingRow(
            label: AppLocalization.text("remote.field.fetchURL"),
            value: configuration.url ?? "",
            small: true,
            actions: [action("remote.action.edit") { session.requestReference(.editURL(remote: name, push: false)) }]
        )

        RemoteSettingRow(
            label: AppLocalization.text("remote.field.pushURL"),
            value: configuration.effectivePushURL ?? "",
            small: true,
            secondary: configuration.pushURLs.isEmpty,
            actions: pushURLActions
        )

        HStack(spacing: 0) {
            Text(AppLocalization.text("remote.field.options"))
                .foregroundStyle(.secondary)
                .frame(width: 240, alignment: .leading)

            Toggle(AppLocalization.text("remote.skipFetchAll"), isOn: skipsFetchAll)
                .disabled(!session.canWrite)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 20)
        .frame(minHeight: 30)

        refspecRows(configuration.fetchRefspecs, push: false)
        refspecRows(configuration.pushRefspecs, push: true)
    }

    /// 推送地址可以设置；单独设置过时还可以删除。
    private var pushURLActions: [RemoteSettingAction] {
        let name = configuration.name
        var actions = [action("remote.action.set") { session.requestReference(.editURL(remote: name, push: true)) }]

        if !configuration.pushURLs.isEmpty {
            actions.append(action("remote.action.unset") { session.confirmUnsetPushURL(of: name) })
        }

        return actions
    }

    /// 跳过自动获取的勾选框写回仓库配置。
    private var skipsFetchAll: Binding<Bool> {
        Binding(
            get: { configuration.skipsFetchAll },
            set: { session.setSkipsFetchAll($0, for: configuration.name) }
        )
    }

    /// 一组 refspec：分组标题带 “Add Refspec”，每条带 “Edit” 与 “Delete”。
    @ViewBuilder
    private func refspecRows(_ refspecs: [String], push: Bool) -> some View {
        let name = configuration.name

        RemoteSettingsGroup(
            title: AppLocalization.text(push ? "remote.group.push" : "remote.group.fetch"),
            actions: [
                action("remote.action.addRefspec") {
                    session.requestReference(.refspec(remote: name, push: push, original: nil))
                },
            ]
        )

        ForEach(Array(refspecs.enumerated()), id: \.offset) { index, refspec in
            RemoteSettingRow(
                label: index == 0 ? AppLocalization.text(push ? "remote.field.pushRefspecs" : "remote.field.fetchRefspecs") : "",
                value: refspec,
                small: true,
                actions: [
                    action("remote.action.edit") {
                        session.requestReference(.refspec(remote: name, push: push, original: refspec))
                    },
                    action("remote.action.delete") {
                        session.confirmRemoveRefspec(refspec, from: name, push: push)
                    },
                ]
            )
        }
    }

    /// 一个操作按钮；仓库不可写时禁用。
    private func action(_ key: String, perform: @escaping () -> Void) -> RemoteSettingAction {
        RemoteSettingAction(title: AppLocalization.text(key), isEnabled: session.canWrite, perform: perform)
    }
}
