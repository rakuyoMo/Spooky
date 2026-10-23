import AppKit
import SpookyKit
import SwiftUI

// MARK: - RepositorySidebarView

/// Workspace、Branches、Remotes 与活动区共用仓库窗口侧边栏。
struct RepositorySidebarView: View {
    /// 当前窗口会话。
    @Bindable
    var session: RepositorySession

    /// 主视图切换后替换右侧分栏。
    let selectionChanged: () -> Void

    /// 终端入口。
    let openTerminal: () -> Void

    /// 本机 Finder 入口。
    let revealFinder: () -> Void

    /// 复制带主机前缀的路径。
    let copyPath: () -> Void

    /// 多个入口共享同一操作对话框。
    let request: (RepositoryActionRequest) -> Void

    /// 打开全局活动窗口。
    let showActivity: () -> Void

    /// 系统列表和菜单导航使用同一组选择身份。
    private var selectedItems: Set<String> {
        if session.activeView == .workingCopy { return ["workingCopy"] }
        return session.history.selectedReferences.isEmpty ? ["history"] : session.history.selectedReferences
    }

    /// 选择存入会话，快捷键与点击保持一致。
    private var selection: Binding<Set<String>> {
        Binding(
            get: { selectedItems },
            set: { value in
                guard !value.isEmpty else { return }
                let added = value.subtracting(selectedItems)
                session.history.showsCommitPage = false
                if added.contains("workingCopy") || value == ["workingCopy"] {
                    session.activeView = .workingCopy
                } else {
                    session.activeView = .history
                    session.history.selectedReferences =
                        added.contains("history") || value == ["history"]
                            ? []
                            : value.subtracting(["workingCopy", "history"])
                }
                selectionChanged()
            }
        )
    }

    /// 空分组保留标题和提示，远端按名称分组。
    var body: some View {
        VStack(spacing: 0) {
            List(selection: selection) {
                Section(AppLocalization.text("workspace.group")) {
                    workingCopy
                        .tag("workingCopy")
                        .modifier(
                            RepositoryDropTarget(session: session, destination: .head, request: request)
                        )
                    Label(AppLocalization.text("history.title"), systemImage: "clock").tag("history")
                }
                localBranches
                remoteBranches
            }
            .listStyle(.sidebar)

            activityRows
            Divider()
            bottomBar
        }
    }

    /// 未出生和分离 HEAD 仍有稳定的当前分支行。
    private var localBranches: some View {
        Section {
            let locals = session.history.branches.filter(\.isLocal)
            if locals.isEmpty { Text(AppLocalization.text("branch.empty")).foregroundStyle(.secondary) }
            if session.status?.branch.head == nil || session.status?.branch.oid == nil {
                Text(session.status?.branch.head ?? AppLocalization.text("branch.detachedShort")).tag("HEAD")
            }
            ForEach(locals) { ref in
                branchRow(ref)
                    .tag(ref.id)
                    .onTapGesture(count: 2) { checkout(ref) }
                    .onDrag { dragProvider(kind: .local, reference: ref.id) }
                    .contextMenu { branchMenu(ref) }
                    .modifier(
                        RepositoryDropTarget(
                            session: session,
                            destination: ref.name == session.status?.branch.head ? .head : .localBranch,
                            request: request
                        )
                    )
            }
        } header: {
            Text(AppLocalization.text("branch.group"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(RepositoryDropTarget(session: session, destination: .branches, request: request))
        }
    }

    /// 每个配置远端都有分组，符号 HEAD 作为默认分支标记。
    private var remoteBranches: some View {
        Section(AppLocalization.text("remote.group")) {
            if session.history.snapshot?.remotes.isEmpty != false {
                Text(AppLocalization.text("sync.noRemotes")).foregroundStyle(.secondary)
            }
            ForEach(session.history.snapshot?.remotes ?? []) { remote in
                DisclosureGroup {
                    remoteBranchRows(remote)
                } label: {
                    remoteLabel(remote)
                }
            }
        }
    }

    /// 工作区保留改动数及已有文件操作入口。
    private var workingCopy: some View {
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
        .contextMenu {
            Button(AppLocalization.text("sync.pull")) { request(RepositoryActionRequest(kind: .pull)) }
                .disabled(!session.canPull)
            Button(AppLocalization.text("sync.push")) { request(RepositoryActionRequest(kind: .push)) }
                .disabled(!session.canPush)
            Button(AppLocalization.text("sync.publish")) { request(RepositoryActionRequest(kind: .publish)) }
                .disabled(!session.canPublish)
            Button(AppLocalization.text("sync.merge")) { request(RepositoryActionRequest(kind: .merge)) }
                .disabled(!session.canMerge)
            Divider()
            Button(AppLocalization.text("working.discardAll")) {
                session.discard(session.status?.entries ?? [])
            }
            .disabled(!session.canDiscard(session.status?.entries ?? []))
            Divider()
            Button(AppLocalization.text("action.openTerminal"), action: openTerminal)
            Button(AppLocalization.text("action.revealFinder"), action: revealFinder)
                .disabled(session.repository?.localURL == nil)
            Button(AppLocalization.text("action.copyPath"), action: copyPath)
        }
    }

    /// 最近三个活动显示持续进度和取消，点击打开完整日志。
    private var activityRows: some View {
        let items = RepositoryActivities.shared.items.filter { $0.repository == session.repository }
        return VStack(spacing: 0) {
            ForEach(Array(items.prefix(3))) { activity in
                HStack {
                    Button(action: showActivity) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.title).font(.system(size: 11, weight: .semibold))
                            Text(AppLocalization.text(activity.state)).font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            if activity.cancel != nil { ProgressView().controlSize(.mini) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    if let cancel = activity.cancel {
                        Button(action: cancel) { Image(systemName: "stop.circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(AppLocalization.text("action.cancel"))
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 65)
                Divider()
            }
        }
    }

    /// 侧边栏底部的新建分支菜单。
    private var bottomBar: some View {
        HStack {
            Menu {
                Button(AppLocalization.text("branch.create")) {
                    request(RepositoryActionRequest(kind: .create))
                }
                .disabled(!session.canCreateBranch)
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel(AppLocalization.text("branch.create"))

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
    }
}

// MARK: - Rows

extension RepositorySidebarView {
    /// 一个远端下的远端分支行：双击检出，接受本地分支拖入以推送。
    @ViewBuilder
    private func remoteBranchRows(_ remote: RepositoryRemote) -> some View {
        // 按最长前缀判断归属，远端名带斜杠时也不会混入其它远端的分支。
        let refs = session.history.branches.filter {
            $0.isRemote && session.history.snapshot?.remote(for: $0)?.name == remote.name
        }

        if refs.isEmpty {
            Text(AppLocalization.text("branch.empty")).foregroundStyle(.secondary)
        }

        ForEach(refs) { ref in
            branchRow(ref)
                .tag(ref.id)
                .onTapGesture(count: 2) {
                    checkoutRemote(ref)
                }
                .onDrag { dragProvider(kind: .remote, reference: ref.id) }
                .contextMenu { branchMenu(ref) }
                .modifier(
                    RepositoryDropTarget(
                        session: session,
                        destination: .remoteBranch(remote.name, ref.id),
                        request: request
                    )
                )
        }
    }

    /// 远端名称行：右键获取或清理，接受本地分支拖入以发布。
    private func remoteLabel(_ remote: RepositoryRemote) -> some View {
        Label(remote.name, systemImage: "network")
            .contextMenu {
                Button(AppLocalization.text("sync.fetch")) {
                    request(RepositoryActionRequest(kind: .fetch, remote: remote.name))
                }
                .disabled(!session.canFetch)

                Button(AppLocalization.text("sync.prune")) {
                    request(
                        RepositoryActionRequest(kind: .fetch, remote: remote.name, prune: true)
                    )
                }
                .disabled(!session.canFetch)
            }
            .modifier(
                RepositoryDropTarget(
                    session: session,
                    destination: .remote(remote.name),
                    request: request
                )
            )
    }

    /// HEAD 和双向数量组成胶囊徽标，服务器主机写入辅助说明。
    private func branchRow(_ ref: RepositoryReference) -> some View {
        HStack(spacing: 4) {
            Image(systemName: ref.isLocal ? "arrow.triangle.branch" : "network")
            Text(ref.name).lineLimit(1)
            Spacer(minLength: 4)
            if
                ref.isLocal && ref.name == session.status?.branch.head
                || session.history.divergence[ref.id] != nil
            {
                HStack(spacing: 4) {
                    if ref.isLocal, ref.name == session.status?.branch.head {
                        Text("HEAD").fontWeight(.semibold)
                    }
                    if let counts = session.history.divergence[ref.id] {
                        if counts.ahead > 0 { Text("↑ \(counts.ahead)") }
                        if counts.behind > 0 { Text("↓ \(counts.behind)") }
                    }
                }
                .font(.system(size: 12))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(AppPalette.color("sidebarBadgeBackgroundColor"), in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(badgeDescription(ref))
            }
            if
                let remote = session.history.snapshot?.remote(for: ref),
                session.history.snapshot?.defaultBranch(for: remote) == ref.id
            {
                Image(systemName: "house").help(AppLocalization.text("branch.default"))
            }
        }
        .help(
            (session.repository?.host.map { $0 + ": " } ?? "") + ref.name
                + (ref.upstream.map { " → " + $0 } ?? "")
        )
    }

    /// 分支菜单只包含已经实现的动作。
    @ViewBuilder
    private func branchMenu(_ ref: RepositoryReference) -> some View {
        let selected = session.history.branches.filter { session.history.selectedReferences.contains($0.id) }
        if selected.count > 1, selected.contains(where: { $0.id == ref.id }), selected.allSatisfy(\.isLocal) {
            Button(AppLocalization.text("branch.deleteMultiple")) { delete(selected) }
                .disabled(!session.canDelete(selected))
        } else {
            if ref.isLocal {
                Button(AppLocalization.text("branch.checkout")) { checkout(ref) }
                    .disabled(!session.canCheckout(ref))
                Button(AppLocalization.text("sync.publish")) {
                    request(RepositoryActionRequest(kind: .publish, localBranch: ref.name))
                }
                .disabled(!session.canPush(ref))
                Button(AppLocalization.text("sync.push")) {
                    request(RepositoryActionRequest(kind: .push, localBranch: ref.name))
                }
                .disabled(!session.canPush(ref))
            } else {
                Button(AppLocalization.text("branch.track")) {
                    request(RepositoryActionRequest(kind: .track, reference: ref.id))
                }
                .disabled(!session.canTrack(ref))
                Button(AppLocalization.text("sync.pull")) {
                    request(RepositoryActionRequest(kind: .pull, reference: ref.id))
                }
                .disabled(!session.canPull(from: ref))
            }
            Button(AppLocalization.text("branch.create")) {
                request(RepositoryActionRequest(kind: .create, reference: ref.id))
            }
            .disabled(!session.canCreateBranchFromReference)
            Button(AppLocalization.text("sync.merge")) {
                request(RepositoryActionRequest(kind: .merge, reference: ref.id))
            }
            .disabled(!session.canMerge(ref))
            if ref.isLocal {
                Divider()
                Button(AppLocalization.text("branch.delete")) { delete([ref]) }
                    .disabled(!session.canDelete([ref]))
            }
            Divider()
            Button(AppLocalization.text("branch.copyName")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(ref.name, forType: .string)
            }
        }
    }

    /// 拖动开始时仓库仍在显示才提供载荷；仓库刚关闭时返回空的拖动内容。
    private func dragProvider(kind: RepositoryDragPayload.Kind, reference: String) -> NSItemProvider {
        guard let repository = session.repository else {
            return NSItemProvider()
        }

        return RepositoryDragPayload(repository: repository, kind: kind, reference: reference).provider()
    }

    /// HEAD 与双向数量的辅助说明，VoiceOver 不朗读箭头符号。
    private func badgeDescription(_ ref: RepositoryReference) -> String {
        var parts: [String] = []

        if ref.isLocal, ref.name == session.status?.branch.head {
            parts.append("HEAD")
        }

        if let counts = session.history.divergence[ref.id] {
            if counts.ahead > 0 { parts.append(AppLocalization.text("branch.ahead", counts.ahead)) }
            if counts.behind > 0 { parts.append(AppLocalization.text("branch.behind", counts.behind)) }
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Actions

extension RepositorySidebarView {
    /// 双击检出保留 Git 对本地修改的覆盖保护。
    private func checkout(_ ref: RepositoryReference) {
        guard session.canCheckout(ref) else { return }
        session.performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).checkout(ref.id)
            },
            title: AppLocalization.text("branch.checkout")
        )
    }

    /// 双击远端分支检出已有跟踪分支，或原子创建并检出同名跟踪分支。
    private func checkoutRemote(_ ref: RepositoryReference) {
        guard
            session.canCheckout(ref), let snapshot = session.history.snapshot,
            let remote = snapshot.remote(for: ref)
        else { return }
        if let existing = snapshot.references.first(where: { $0.isLocal && $0.upstream == ref.id }) {
            checkout(existing)
            return
        }
        let name = String(ref.id.dropFirst(("refs/remotes/" + remote.name + "/").count))

        // 同名本地分支可能有不同含义，保留它并让用户在跟踪表单中指定名称。
        if snapshot.references.contains(where: { $0.id == "refs/heads/" + name }) {
            request(RepositoryActionRequest(kind: .track, reference: ref.id))
            return
        }
        session.performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner)
                    .create(
                        name: name,
                        startingAt: ref.id,
                        track: true,
                        checkout: true
                    )
            },
            title: AppLocalization.text("branch.checkout")
        )
    }

    /// 删除始终确认，普通删除失败不转为强制删除。
    private func delete(_ references: [RepositoryReference]) {
        let repository = session.repository
        let names = references.map(\.name).joined(separator: ", ")
        session.onConfirm?(
            AppLocalization.text(references.count == 1 ? "branch.delete" : "branch.deleteMultiple"),
            AppLocalization.text("branch.delete.confirm", names, repository?.displayPath ?? ""),
            {
                guard session.repository == repository else { return }
                session.performGit(
                    { runner, _ in
                        try await RepositoryReferences(runner: runner).delete(references.map(\.id))
                    },
                    title: AppLocalization.text("branch.delete")
                )
            },
            nil
        )
    }
}
