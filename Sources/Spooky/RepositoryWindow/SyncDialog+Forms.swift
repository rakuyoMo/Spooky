import SpookyKit
import SwiftUI

// MARK: - Forms

extension SyncDialog {
    /// 本地与远端分支，供各下拉框选择。
    private var branches: [RepositoryReference] { session.history.branches }

    /// 远端跟踪分支，同步与强推的目标都从中选。
    private var remoteBranches: [RepositoryReference] { branches.filter(\.isRemote) }

    /// 按种类呈现字段。
    @ViewBuilder
    var form: some View {
        switch kind {
        case .sync:
            picker("sync.remoteBranch", selection: $source, references: remoteBranches)

            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                option("sync.rebase", value: $rebase)
            }

        case .rebase:
            let head = "refs/heads/" + (session.status?.branch.head ?? "")
            picker("branch.target", selection: $source, references: branches.filter { $0.id != head })

        case .forcePush:
            picker("branch.target", selection: $source, references: branches.filter(\.isLocal))
            picker("sync.destination", selection: $destination, references: remoteBranches)

        case .pushRevision:
            revisionRows
        }
    }

    /// 各种类的附带选项；跳过钩子都有，同步另有拉取与推送的选项。
    @ViewBuilder
    var options: some View {
        VStack(alignment: .leading, spacing: 8) {
            if kind == .sync {
                option("merge.verify", value: $verify)
                option("sync.pushAllTags", value: $pushAllTags)

                SubmodulePushOption(enabled: $pushSubmodules, mode: $pushSubmoduleMode)
            }

            option("sync.skipHooks", value: $skipHooks)
        }
    }

    /// 强推会推上去与会覆盖的提交数，以及远端分支相对改写前版本的状态。
    @ViewBuilder
    var leaseStatus: some View {
        if checkingLease {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)

                Text(AppLocalization.text("sync.lease.checking"))
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        } else if let lease {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.text("sync.lease.introduced", lease.introduced))
                Text(AppLocalization.text("sync.lease.overwritten", lease.overwritten))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            leaseStatusLine(lease.status)
        }
    }

    /// 参数完整且仓库可写时才能执行；强推还要求核对完成且两侧不是同一个提交。
    var canSubmit: Bool {
        switch kind {
        case .sync:
            session.canSync && !source.isEmpty

        case .rebase:
            session.canRebase && !source.isEmpty

        case .forcePush:
            session.canPush && !checkingLease && (lease.map { $0.status != .sameRevision } ?? false)

        case .pushRevision:
            session.canPushRevision
                && !remote.isEmpty
                && !source.trimmingCharacters(in: .whitespaces).isEmpty
                && !destination.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    /// 推送任意版本：版本可输入或从分支与标签里选，远端从配置里选，目标引用可输入或从该远端的分支里选。
    @ViewBuilder
    private var revisionRows: some View {
        let tags = session.history.snapshot?.references.filter { $0.id.hasPrefix("refs/tags/") } ?? []
        let owned = remoteBranches.filter { session.history.snapshot?.remote(for: $0)?.name == remote }

        GridRow {
            Text(AppLocalization.text("sync.revision")).gridColumnAlignment(.trailing)

            TextField("", text: $source)
                .textInputSuggestions {
                    ForEach(branches.filter(\.isLocal) + tags) { reference in
                        Text(reference.name).textInputCompletion(reference.name)
                    }
                }
                .accessibilityLabel(AppLocalization.text("sync.revision"))
        }

        GridRow {
            Text(AppLocalization.text("sync.remote")).gridColumnAlignment(.trailing)

            Picker("", selection: $remote) {
                ForEach(session.history.snapshot?.remotes ?? []) { Text($0.name).tag($0.name) }
            }
            .labelsHidden()
            .accessibilityLabel(AppLocalization.text("sync.remote"))
        }

        GridRow {
            Text(AppLocalization.text("sync.refSpec")).gridColumnAlignment(.trailing)

            TextField("", text: $destination)
                .textInputSuggestions {
                    ForEach(owned) { reference in
                        let name = String(reference.id.dropFirst(("refs/remotes/" + remote + "/").count))
                        Text(name).textInputCompletion(name)
                    }
                }
                .accessibilityLabel(AppLocalization.text("sync.refSpec"))
        }
    }

    /// 标签加下拉框的一行，列出引用的短名。
    private func picker(
        _ label: String,
        selection: Binding<String>,
        references: [RepositoryReference]
    ) -> some View {
        GridRow {
            Text(AppLocalization.text(label)).gridColumnAlignment(.trailing)

            Picker("", selection: selection) {
                ForEach(references) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
            .accessibilityLabel(AppLocalization.text(label))
        }
    }

    /// 强推状态的一行：18 pt 图标加 12 pt 说明；只落后的远端不需要说明。
    @ViewBuilder
    private func leaseStatusLine(_ status: ForcePushPreview.Status) -> some View {
        let line: (icon: String, color: Color, text: String)? =
            switch status {
            case .fastForward:
                nil

            case .matchesLastKnown:
                ("checkmark.circle.fill", .green, AppLocalization.text("sync.lease.matches"))

            case .sameRevision:
                ("equal.circle", .secondary, AppLocalization.text("sync.lease.same"))

            case .differsFromLastKnown:
                ("exclamationmark.triangle.fill", .yellow, AppLocalization.text("sync.lease.differs"))

            case .newerOnRemote(let count):
                ("exclamationmark.triangle.fill", .yellow, AppLocalization.text("sync.lease.newer", count))
            }

        if let line {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: line.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(line.color)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)

                Text(line.text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        }
    }
}
