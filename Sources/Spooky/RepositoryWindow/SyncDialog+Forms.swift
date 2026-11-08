import SpookyKit
import SwiftUI

// MARK: - Forms

extension SyncDialog {
    /// 本地与远端分支，供各下拉框选择。
    private var branches: [RepositoryReference] { session.history.branches }

    /// 远端跟踪分支，同步与强推的目标都从中选。
    private var remoteBranches: [RepositoryReference] { branches.filter(\.isRemote) }

    /// 按种类呈现字段；同步与变基最后是合并可行性预览，强推最后是远端分支的状态。
    @ViewBuilder
    var form: some View {
        switch kind {
        case .sync:
            // 拉取的来源与拉取对话框一样按公共顺序排列
            picker(
                "sync.remoteBranch",
                selection: $source,
                references: ReferenceOrder.sorted(remoteBranches, in: session.history.snapshot)
            )

            option("sync.rebase", value: $rebase)

            MergeabilityPreview(session: session, revision: source)

        case .rebase:
            let head = "refs/heads/" + (session.status?.branch.head ?? "")

            picker("branch.target", selection: $source, references: branches.filter { $0.id != head })

            MergeabilityPreview(session: session, revision: source)

        case .forcePush:
            leasePicker(
                "branch.target",
                selection: $source,
                references: branches.filter(\.isLocal),
                count: lease.map { Self.leaseCounts(of: $0).introduced }
            )

            leasePicker(
                "sync.destination",
                selection: $destination,
                references: remoteBranches,
                count: lease.map { Self.leaseCounts(of: $0).overwritten }
            )

            leaseStatus

        case .pushRevision:
            revisionRow

            remoteRow

            refSpecRow
        }
    }

    /// 各种类的附带选项；跳过钩子都有，同步另有拉取与推送的选项。
    @ViewBuilder
    var options: some View {
        if kind == .sync {
            option("merge.verify", value: $verify)

            option("sync.pushAllTags", value: $pushAllTags)

            SubmodulePushOption(enabled: $pushSubmodules, mode: $pushSubmoduleMode)
        }

        // 变基的 Skip Hooks 与说明相隔 8，其余三种相隔 4
        option("sync.skipHooks", spacing: kind == .rebase ? 8 : 4, value: $skipHooks)
    }

    /// 参数完整且仓库可写时才能执行；同步与推送版本的目标远端分支或远端还要仍然存在；
    /// 强推还要求核对完成且两侧不是同一个提交。
    var canSubmit: Bool {
        let snapshot = session.history.snapshot

        switch kind {
        case .sync:
            return session.canSync
                && remoteBranches.contains { $0.id == source && snapshot?.remote(for: $0) != nil }

        case .rebase:
            return session.canRebase && !source.isEmpty

        case .forcePush:
            return session.canPush && !checkingLease && (lease.map { $0.status != .sameRevision } ?? false)

        case .pushRevision:
            return session.canPushRevision
                && (snapshot?.remotes.contains { $0.name == remote } ?? false)
                && !source.trimmingCharacters(in: .whitespaces).isEmpty
                && !destination.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    /// 强推核对的进度，或远端分支相对改写前版本的状态，在上一行下方 20 pt；图标挂在输入列外侧，文字对齐输入列。
    private var leaseStatus: some View {
        DialogInputColumnReader { inputColumn in
            // 表单左边距 20，16 pt 的图标加 4 pt 间距挂在输入列左侧
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if checkingLease {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)

                    Text(AppLocalization.text("sync.lease.checking"))
                } else if let lease {
                    leaseStatusLine(lease.status)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.leading, inputColumn - 20 - 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 推送的版本：可输入，也可从本地分支与标签里补全。
    private var revisionRow: some View {
        let tags = session.history.snapshot?.references.filter { $0.id.hasPrefix("refs/tags/") } ?? []

        return RepositoryDialogRows.row(AppLocalization.text("sync.revision")) {
            TextField("", text: $source)
                .textInputSuggestions {
                    ForEach(branches.filter(\.isLocal) + tags) { reference in
                        Text(reference.name).textInputCompletion(reference.name)
                    }
                }
        }
    }

    /// 推送到的远端，从配置的远端里选。
    private var remoteRow: some View {
        RepositoryDialogRows.row(AppLocalization.text("sync.remote")) {
            Picker("", selection: $remote) {
                ForEach(session.history.snapshot?.remotes ?? []) { Text($0.name).tag($0.name) }
            }
            .labelsHidden()
            .buttonSizing(.flexible)
        }
    }

    /// 推送任意版本的目标引用：可输入，也可从所选远端的分支里补全。
    private var refSpecRow: some View {
        let owned = remoteBranches.filter { session.history.snapshot?.remote(for: $0)?.name == remote }

        return RepositoryDialogRows.row(AppLocalization.text("sync.refSpec")) {
            TextField("", text: $destination)
                .textInputSuggestions {
                    ForEach(owned) { reference in
                        let name = String(reference.id.dropFirst(("refs/remotes/" + remote + "/").count))
                        Text(name).textInputCompletion(name)
                    }
                }
        }
    }

    /// 强推下拉下方两行提交数的说明：推送后远端分支新增与被覆盖的提交数，零、一个与多个各用一条文案。
    ///
    /// - Parameter lease: 强推的核对结果。
    static func leaseCounts(of lease: ForcePushPreview) -> (introduced: String, overwritten: String) {
        let introduced =
            switch lease.introduced {
            case 0: AppLocalization.text("sync.lease.introduced.zero")
            case 1: AppLocalization.text("sync.lease.introduced.one")
            default: AppLocalization.text("sync.lease.introduced", lease.introduced)
            }

        let overwritten =
            switch lease.overwritten {
            case 0: AppLocalization.text("sync.lease.overwritten.zero")
            case 1: AppLocalization.text("sync.lease.overwritten.one")
            default: AppLocalization.text("sync.lease.overwritten", lease.overwritten)
            }

        return (introduced, overwritten)
    }

    /// 远端分支有本地从未见过的提交时的提醒，按一个与多个取文案；有这种提交时个数至少为 1。
    ///
    /// - Parameter count: 本地从未见过的提交数。
    static func newerCommits(_ count: Int) -> String {
        count == 1
            ? AppLocalization.text("sync.lease.newer.one")
            : AppLocalization.text("sync.lease.newer", count)
    }

    /// 标签加下拉框的一行，列出引用的短名。
    private func picker(
        _ label: String,
        selection: Binding<String>,
        references: [RepositoryReference]
    ) -> some View {
        RepositoryDialogRows.row(AppLocalization.text(label)) {
            referencePicker(label, selection: selection, references: references)
                .dialogFieldWidth(kind.pickerWidth)
        }
    }

    /// 强推的一行下拉：下方 4 pt 是 11 pt 次要色的提交数，与下拉同宽；与下一行相隔 20 pt。
    ///
    /// - Parameter count: 提交数的说明；核对完成前为 nil。
    private func leasePicker(
        _ label: String,
        selection: Binding<String>,
        references: [RepositoryReference],
        count: String?
    ) -> some View {
        RepositoryDialogRows.row(AppLocalization.text(label)) {
            // 表单的行距 8 再加 12，与下一行相隔 20
            VStack(alignment: .leading, spacing: 4) {
                referencePicker(label, selection: selection, references: references)

                if let count {
                    Text(count)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .dialogFieldWidth(kind.pickerWidth)
            .padding(.bottom, 12)
        }
    }

    /// 列出引用短名的下拉框，填满所在的宽度。
    private func referencePicker(
        _ label: String,
        selection: Binding<String>,
        references: [RepositoryReference]
    ) -> some View {
        Picker("", selection: selection) {
            ForEach(references) { Text($0.name).tag($0.id) }
        }
        .labelsHidden()
        .buttonSizing(.flexible)
        .accessibilityLabel(AppLocalization.text(label))
    }

    /// 强推状态的一行：16 pt 图标加 12 pt 说明；只落后的远端不需要说明。
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
                ("exclamationmark.triangle.fill", .yellow, Self.newerCommits(count))
            }

        if let line {
            Image(systemName: line.icon)
                .font(.system(size: 13))
                .foregroundStyle(line.color)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(line.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
