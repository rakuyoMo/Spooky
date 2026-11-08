import SpookyKit
import SwiftUI

// MARK: - RepositoryOperationDialog

/// 参数 sheet 提交后立即关闭，Git 的进度与失败由仓库窗口承接。
struct RepositoryOperationDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 由入口确定的动作与预填项。
    let request: RepositoryActionRequest

    /// 取消只关闭表单。
    let cancel: () -> Void

    /// 提交交付操作名称、Activity 记录连接的对象、与撤销记录的关系和显式参数对应的业务操作；
    /// 返回 false 表示仓库暂不可写，表单保持打开。
    let submit:
        (
            String,
            ActivityTarget?,
            UndoRecording,
            @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void
        ) -> Bool

    /// 名称输入在确认前经过 Git 校验。
    @State
    private var name = ""

    /// 起点、合并目标或拉取来源的完整引用。
    @State
    private var source = ""

    /// 用户选定的远端。
    @State
    private var remote = ""

    /// 推送来源的本地分支短名。
    @State
    private var localBranch = ""

    /// 新建分支是否跟踪起点。
    @State
    private var track = false

    /// 新建分支是否置顶，只在本次表单生效。
    @State
    private var pin = false

    /// 新建分支的父分支完整引用名；空字符串表示不设置，起点是分支时默认是它。
    @State
    private var parent = ""

    /// 发布分支后跟踪推上去的远端分支，默认勾上；推送不设置上游。
    @State
    private var upstream = true

    /// 校验完成后才能创建引用。
    @State
    private var validName = false

    /// 校验和预加载错误只显示在表单内部。
    @State
    private var error = ""

    /// 推送时强推：只在远端分支仍是上次获取到的版本时覆盖，不记忆。
    @State
    private var forcePush = false

    /// 压缩合并与强制合并提交互斥。
    @State
    private var squash = false

    /// 跳过钩子只在本次表单生效。
    @State
    private var skipHooks = false

    /// 新建分支后是否检出，跨仓库保存；没有保存值时不勾。
    @AppStorage("checkoutCreatedBranch")
    private var checkout = false

    /// 跟踪远端分支后是否检出：每次打开默认勾选，不记忆，与新建分支的检出偏好分开。
    @State
    private var trackCheckout = true

    /// 输入时规范化名称的开关。
    @AppStorage("cleanRefNames")
    private var cleanNames = true

    /// 获取全部远端，跨仓库保存；没有保存值时不勾，入口预选的远端不改变它。
    @AppStorage("fetchAllRemotes")
    private var allRemotes = false

    /// 清理远端引用的偏好，跨仓库保存；没有保存值时勾选。
    @AppStorage("fetchPrune")
    private var savedPrune = true

    /// 本次获取是否清理：打开时取保存的偏好，Prune 入口打开时勾选；只有用户切换勾选框时写回偏好。
    @State
    private var prune = true

    /// 获取全部标签是 Fetch 的附带选项。
    @AppStorage("fetchAllTags")
    private var allTags = false

    /// 获取时同时获取已检出的子模块。
    @AppStorage("fetchSubmodules")
    private var fetchSubmodules = false

    /// 推送时另推全部标签。
    @AppStorage("pushAllTags")
    private var pushAllTags = false

    /// 推送时递归处理子模块。
    @AppStorage("pushRecurseSubmodules")
    private var pushSubmodules = false

    /// 递归处理子模块的方式。
    @AppStorage("pushSubmoduleMode")
    private var pushSubmoduleMode = SubmodulePushMode.onDemand.rawValue

    /// 拉取方式始终明确写入参数。
    @AppStorage("pullUseRebase")
    private var rebase = false

    /// 合并是否总是创建合并提交。
    @AppStorage("mergeAlwaysCreateCommit")
    private var alwaysCommit = false

    /// 非快进合并是否立即提交。
    @AppStorage("mergeAutoCommit")
    private var autoCommit = true

    /// 合并和拉取的签名验证偏好分别记忆。
    @AppStorage("mergeVerifySignatures")
    private var mergeVerify = false

    /// 拉取目标签名验证偏好。
    @AppStorage("pullVerifySignatures")
    private var pullVerify = false

    /// 对话框骨架：头部、表单、错误区、Options 与底栏；跟踪远端分支没有选项区。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text(request.kind.titleKey(pushesHead: pushesHead)),
            message: message,
            width: request.kind == .push ? 450 : 480,
            submitTitle: AppLocalization.text(request.kind.submitKey(pushesHead: pushesHead)),
            error: Self.emptyState(for: request, in: session) ?? error,
            isValid: canSubmit,
            cancel: cancel,
            submit: perform,
            options: request.kind == .track ? nil : { options }
        ) {
            rows
        }
        .onAppear(perform: prepare)
        .onChange(of: destinationIDs) { _, candidates in
            // Destination 所选的远端分支不在候选里了，按同一顺序重新预选
            if usesDestination, !candidates.contains(source) {
                source = Self.destinationPreselection(preselection: request.reference, in: session)
            }
        }
        .onChange(of: name) {
            name = Self.normalizedName(name, for: request.kind, cleaning: cleanNames)
        }
        .onChange(of: source) {
            if request.kind == .track {
                name = remoteBranchName(source)
            }

            if !canTrack {
                track = false
            }

            // 换了起点就按新起点重新取默认的父分支，不沿用上一个起点的选择
            if request.kind == .create {
                parent = parentCandidate?.id ?? ""
            }
        }
        .onChange(of: parentCandidate?.id) { _, candidate in
            // 候选消失或换成别的分支时，不留下已不在候选里的父分支
            if !parent.isEmpty, parent != candidate {
                parent = ""
            }
        }
        .onChange(of: localBranch) {
            if request.kind == .publish {
                name = localBranch
            }
        }
        .task(id: name + "\u{0}" + remote) { await validateName() }
    }

    /// 当前所有可见的分支，起点组合框仍可输入提交哈希。
    private var branches: [RepositoryReference] { session.history.branches }

    /// 起点必须是实际分支才允许勾选跟踪。
    private var canTrack: Bool { startBranch != nil }

    /// 起点对应的分支；起点是提交哈希、标签或其它写法时为 nil。
    private var startBranch: RepositoryReference? { branches.first { $0.id == source || $0.name == source } }

    /// 当前起点下可选的父分支；为 nil 时父分支固定为不设置。
    private var parentCandidate: RepositoryReference? { Self.parentCandidate(for: source, in: session) }

    /// 推送的本地分支是不是 HEAD 分支，决定推送对话框的标题与主按钮。
    private var pushesHead: Bool { localBranch == session.status?.branch.head }

    /// 推送 HEAD 分支时只有一个 Destination，见 ``usesDestination(_:in:)``。
    private var usesDestination: Bool { Self.usesDestination(request, in: session) }

    /// Push HEAD 的 Destination 候选的完整引用名，其余表单为空，供候选变化时重新预选。
    private var destinationIDs: [String] {
        usesDestination ? Self.pushDestinations(in: session).map(\.id) : []
    }

    /// 标题下的说明：Push HEAD 写出 HEAD 分支名，其余按动作取。
    private var message: String {
        usesDestination
            ? AppLocalization.text("sync.pushHead.help", localBranch)
            : AppLocalization.text(request.kind.rawValue + ".help")
    }

    /// 已配置的远端里有表单所选的远端。
    private var hasSelectedRemote: Bool {
        session.history.snapshot?.remotes.contains { $0.name == remote } ?? false
    }

    /// 表单校验在客户端及时反馈，执行时核心库仍重新核对；仓库是否可写由骨架判断。
    ///
    /// 所选的远端、来源或目标在对话框打开后被移除时不可提交。
    private var canSubmit: Bool {
        switch request.kind {
        case .create:
            validName && !source.isEmpty

        case .track:
            validName && branches.contains { $0.id == source && $0.isRemote }

        case .fetch:
            !(session.history.snapshot?.remotes.isEmpty ?? true) && (allRemotes || hasSelectedRemote)

        case .pull, .merge:
            Self.sourceCandidates(for: request.kind, in: session).contains { $0.id == source }
                && session.status?.branch.head != nil
                && session.context?.operation == nil

        case .push where usesDestination:
            !localBranch.isEmpty && Self.destinationTarget(source, in: session) != nil

        case .push, .publish:
            validName && hasSelectedRemote && branches.contains { $0.isLocal && $0.name == localBranch }
        }
    }
}

// MARK: - Layout

extension RepositoryOperationDialog {
    /// 内容区输入控件的宽度上限：拉取与合并 360，新建分支与发布 350，推送 320；跟踪与获取占满输入列。
    private var fieldWidth: CGFloat {
        switch request.kind {
        case .pull, .merge: 360
        case .create, .publish: 350
        case .push: 320
        case .track, .fetch: .infinity
        }
    }

    /// 按操作种类呈现各自的字段。
    @ViewBuilder
    private var rows: some View {
        switch request.kind {
        case .create:
            createRows

        case .track:
            trackRows

        case .fetch:
            fetchRows

        case .pull:
            pullRows

        case .merge:
            mergeRows

        case .push, .publish:
            pushRows
        }
    }

    /// 新建分支：名称、可输入也可从引用列表选的起点，以及跟踪起点、置顶与新建后检出的选项。
    @ViewBuilder
    private var createRows: some View {
        nameRow

        // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐
        GridRow(alignment: .center) {
            Text(AppLocalization.text("branch.start"))
                .gridColumnAlignment(.trailing)

            RevisionComboBox(
                text: $source,
                items: session.revisionReferences.map(\.name),
                label: AppLocalization.text("branch.start")
            )
            .dialogFieldWidth(fieldWidth)
        }

        // 起点是分支时标题写出它的名字
        option(
            "branch.trackStart",
            title: startBranch.map { AppLocalization.text("branch.trackStart.named", $0.name) },
            value: $track
        )
        .disabled(!canTrack)

        option("branch.pin", value: $pin)

        option("branch.checkoutCreated", value: $checkout)
    }

    /// 新建分支的选项区：父分支下拉只有当前起点下可选的父分支与不设置，没有可选的父分支时不可用；
    /// 说明在下拉下方，与下拉左对齐。
    @ViewBuilder
    private var parentRows: some View {
        RepositoryDialogRows.row(AppLocalization.text("branch.parentOption")) {
            Picker("", selection: $parent) {
                if let candidate = parentCandidate {
                    Text(candidate.name).tag(candidate.id)
                }

                Text(AppLocalization.text("branch.parentOption.none")).tag("")
            }
            .labelsHidden()
            .buttonSizing(.flexible)
            .disabled(parentCandidate == nil)
        }

        GridRow {
            Color.clear
                .frame(width: DialogMetrics.labelWidth, height: 0)
                .gridCellUnsizedAxes(.vertical)

            Text(AppLocalization.text("branch.parentOption.help"))
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 跟踪远端分支：远端分支、本地名称与新建后检出的选项。
    @ViewBuilder
    private var trackRows: some View {
        referencePicker(branches.filter(\.isRemote), label: "branch.remoteField")

        nameRow

        option(
            "branch.checkoutCreated",
            title: AppLocalization.text("branch.track.checkout"),
            value: $trackCheckout
        )
    }

    /// 获取：选择单个远端，或改为获取全部远端。
    @ViewBuilder
    private var fetchRows: some View {
        remotePicker

        DialogFormOption(title: AppLocalization.text("sync.allRemotes"), isOn: $allRemotes)
    }

    /// 拉取：远端分支、是否以变基方式拉取，以及合并可行性预览。
    @ViewBuilder
    private var pullRows: some View {
        referencePicker(Self.sourceCandidates(for: .pull, in: session), label: "sync.remoteBranch")

        option("sync.rebase", value: $rebase)

        MergeabilityPreview(session: session, revision: source)
    }

    /// 合并：目标（分支或标签），压缩、合并提交与自动提交的选项，以及只在有冲突时显示的合并可行性预览。
    @ViewBuilder
    private var mergeRows: some View {
        referencePicker(Self.sourceCandidates(for: .merge, in: session), label: "branch.target")

        option("merge.squash", value: $squash)
            .disabled(alwaysCommit)

        option("merge.alwaysCommit", value: $alwaysCommit)
            .disabled(squash)

        // 自动提交只在强制创建合并提交且不压缩时可改，其余情况固定显示为勾选
        option(
            "merge.autoCommit",
            value: Binding(
                get: { alwaysCommit && !squash ? autoCommit : true },
                set: { autoCommit = $0 }
            )
        )
        .disabled(!alwaysCommit || squash)

        MergeabilityPreview(session: session, revision: source, showsCleanResults: false)
    }

    /// 推送与发布：Push HEAD 只有 Destination 一行；Push Branch 与发布是本地分支、远端与远端分支名，
    /// 只有发布有跟踪新远端分支的选项。
    @ViewBuilder
    private var pushRows: some View {
        if usesDestination {
            referencePicker(Self.pushDestinations(in: session), label: "sync.destination")
        } else {
            branchPushRows
        }
    }

    /// Push Branch 与发布的本地分支、远端与远端分支名三行，以及发布的跟踪选项。
    @ViewBuilder
    private var branchPushRows: some View {
        RepositoryDialogRows.row(AppLocalization.text("branch.local")) {
            Picker("", selection: $localBranch) {
                ForEach(branches.filter(\.isLocal)) { Text($0.name).tag($0.name) }
            }
            .labelsHidden()
            .buttonSizing(.flexible)
            .dialogFieldWidth(fieldWidth)
        }

        remotePicker

        nameRow

        if request.kind == .publish {
            option("sync.setUpstream", value: $upstream)
        }
    }

    /// 名称字段：新建与跟踪是新本地分支的名称，推送与发布是远端分支名；输入时的规范化见 ``normalizedName(_:for:cleaning:)``。
    private var nameRow: some View {
        let label = [.create, .track].contains(request.kind) ? "reference.name" : "branch.name"

        return RepositoryDialogRows.row(AppLocalization.text(label)) {
            TextField("", text: $name)
                .accessibilityIdentifier("branch-name")
                .dialogFieldWidth(fieldWidth)
        }
    }

    /// 远端从配置快照中选择，不在 UI 接受未经验证的 URL；获取全部远端时不可用。
    private var remotePicker: some View {
        RepositoryDialogRows.row(AppLocalization.text("sync.remote")) {
            Picker("", selection: $remote) {
                ForEach(session.history.snapshot?.remotes ?? []) { Text($0.name).tag($0.name) }
            }
            .labelsHidden()
            .buttonSizing(.flexible)
            .dialogFieldWidth(fieldWidth)
            .disabled(request.kind == .fetch && allRemotes)
        }
    }

    /// 新建分支的父分支，以及获取、拉取、合并、推送与发布附带的选项，按各自行为过滤。
    @ViewBuilder
    private var options: some View {
        switch request.kind {
        case .create:
            parentRows

        case .fetch:
            option(
                "sync.prune",
                value: Binding {
                    prune
                } set: {
                    prune = $0
                    savedPrune = $0
                }
            )

            option("sync.fetchSubmodules", value: $fetchSubmodules)

            option("sync.allTags", value: $allTags)

        case .pull:
            option("merge.verify", value: $pullVerify)

            option("sync.skipHooks", value: $skipHooks)

        case .merge:
            option("merge.verify", value: $mergeVerify)
                .disabled(squash)

            option("sync.skipHooks", value: $skipHooks)

        case .push:
            option("sync.pushAllTags", value: $pushAllTags)

            option("sync.forcePush", value: $forcePush)

            SubmodulePushOption(enabled: $pushSubmodules, mode: $pushSubmoduleMode)

            option("sync.skipHooks", value: $skipHooks)

        case .publish:
            option("sync.skipHooks", spacing: 4, value: $skipHooks)

        case .track:
            EmptyView()
        }
    }

    /// 选择来源的下拉，列出引用的短名。
    ///
    /// - Parameters:
    ///   - references: 可选的引用。
    ///   - label: 标签的文案键。
    private func referencePicker(_ references: [RepositoryReference], label: String) -> some View {
        RepositoryDialogRows.row(AppLocalization.text(label)) {
            Picker("", selection: $source) {
                ForEach(references) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
            .buttonSizing(.flexible)
            .dialogFieldWidth(fieldWidth)
        }
    }

    /// 勾选框与下一行的说明，说明的资源键是勾选框的资源键加 `.help`。
    ///
    /// - Parameters:
    ///   - title: 随表单内容变化的标题；为 nil 时用资源键对应的标题。
    ///   - spacing: 勾选框到说明的间距。
    private func option(
        _ key: String,
        title: String? = nil,
        spacing: CGFloat = 8,
        value: Binding<Bool>
    ) -> DialogFormOption {
        DialogFormOption(
            title: title ?? AppLocalization.text(key),
            help: AppLocalization.text(key + ".help"),
            spacing: spacing,
            isOn: value
        )
    }
}

// MARK: - Actions

extension RepositoryOperationDialog {
    /// 表单默认值来自 HEAD 跟踪关系或入口指定对象。
    private func prepare() {
        let head = branches.first { $0.id == "refs/heads/" + (session.status?.branch.head ?? "") }
        remote = request.remote ?? head?.upstreamRemote ?? session.history.snapshot?.remotes.first?.name ?? ""
        localBranch =
            request.localBranch ?? session.status?.branch.head ?? branches.first(where: \.isLocal)?.name ?? ""

        switch request.kind {
        case .create:
            name = request.name ?? ""

            // 起点框显示引用的短名，没有指定时是当前分支；默认的父分支见 parentCandidate(for:in:)
            source = request.reference.map { reference in
                session.revisionReferences.first { $0.id == reference }?.name ?? reference
            } ?? head?.name ?? "HEAD"
            parent = parentCandidate?.id ?? ""

        case .track:
            source = Self.trackSource(preselection: request.reference, in: session)
            name = remoteBranchName(source)

        case .fetch:
            // 入口预选的远端与 Prune 意图只作用于本次打开，不写回偏好
            prune = request.prune || savedPrune

        case .merge, .pull:
            source = Self.sourcePreselection(for: request.kind, preselection: request.reference, in: session)

        case .push where usesDestination:
            source = Self.destinationPreselection(preselection: request.reference, in: session)

        case .push, .publish:
            let selected = branches.first { $0.isLocal && $0.name == localBranch }

            // 右键指定的源分支使用自己的上游，不能借用当前 HEAD 的推送目标。
            remote = request.remote ?? selected?.upstreamRemote
                ?? session.history.snapshot?.remotes.first?.name ?? ""
            if request.kind == .publish {
                name = localBranch
            } else {
                name = request.reference.map(remoteBranchName)
                    ?? selected?.upstreamBranch.map { String($0.dropFirst("refs/heads/".count)) }
                    ?? localBranch
            }
        }
    }

    /// 名称校验在输入停顿后进行，结果与说明见 ``nameValidation(_:for:remote:in:)``；输入变化后旧的结果作废。
    private func validateName() async {
        validName = false

        // Push HEAD 从已有的远端分支里选目标，没有名称框
        guard [.create, .track, .push, .publish].contains(request.kind), !usesDestination else {
            return
        }

        // 空名称不必等输入停顿，立即禁用主按钮并清掉旧的说明
        if !name.isEmpty {
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }
        }

        let result = await Self.nameValidation(name, for: request.kind, remote: remote, in: session)

        guard !Task.isCancelled else {
            return
        }

        validName = result.isValid
        error = result.error
    }

    /// 新建与跟踪分支的写入，捕获当前表单值：新建分支勾选检出时先建分支再检出，检出被拒绝时分支保留；
    /// 其余用一条命令建好，跟踪远端分支总是跟踪所选分支，并按它自己的勾选检出。
    ///
    /// - Parameter revision: 新分支的起点。
    private func branchCreation(startingAt revision: String) -> @Sendable (GitRunner) async throws -> Void {
        let name = name
        let creating = request.kind == .create
        let track = !creating || track
        let pinned = creating && pin

        // 提交时再核对一次，父分支必须仍是当前起点下的候选
        let parent =
            creating && !parent.isEmpty && parent == parentCandidate?.id
                ? parent
                : nil

        let checksOutAfterwards = creating && checkout
        let checkout = !creating && trackCheckout

        return { runner in
            let references = RepositoryReferences(runner: runner)

            // 分两步时检出失败的说明写明已创建、未检出
            if checksOutAfterwards {
                try await references.createThenCheckOut(
                    name: name,
                    startingAt: revision,
                    track: track,
                    pinned: pinned,
                    parent: parent
                )

                return
            }

            try await references.create(
                name: name,
                startingAt: revision,
                track: track,
                checkout: checkout,
                pinned: pinned,
                parent: parent
            )
        }
    }

    /// 推送与发布的目标远端、远端上的分支名与强推的期望值：Push HEAD 取 Destination 所选的远端分支；
    /// 其余取表单的远端与名称，期望值是表单所见的远端跟踪分支，没有跟踪分支时要求远端分支不存在。
    private func pushTarget() -> (remote: String, branch: String, lease: String) {
        if usesDestination {
            return Self.destinationTarget(source, in: session) ?? ("", "", "")
        }

        let tracking = branches.first { $0.id == "refs/remotes/" + remote + "/" + name }

        return (remote, name, tracking?.objectID ?? "")
    }

    /// 推送的选项与强推期望值：发布只带跳过钩子；推送时强推的期望值见 ``pushTarget()``。
    private func pushConfiguration() -> (options: PushOptions, lease: String?) {
        var options = PushOptions()
        options.skipHooks = skipHooks

        guard request.kind == .push else {
            return (options, nil)
        }

        options.allTags = pushAllTags

        if pushSubmodules {
            options.submodules = SubmodulePushMode(rawValue: pushSubmoduleMode) ?? .onDemand
        }

        return (options, forcePush ? pushTarget().lease : nil)
    }

    /// 合并的选项：压缩、总是新建合并提交、随即提交、签名校验与跳过钩子都照表单。
    private func mergeConfiguration() -> MergeOptions {
        var options = MergeOptions()
        options.squash = squash
        options.alwaysCreateCommit = alwaysCommit
        options.commit = alwaysCommit && !squash ? autoCommit : true
        options.verifySignatures = mergeVerify
        options.skipHooks = skipHooks
        return options
    }

    /// Activity 记录连接的对象：获取写所选的远端，获取全部远端时由获取逐个补上；拉取写远端分支；
    /// 推送与发布写传给 git 的 refspec；不连接远端的动作没有。
    ///
    /// - Parameters:
    ///   - pullRemote: 拉取来源所属的远端。
    ///   - pullBranch: 拉取来源在远端上的完整分支引用名。
    private func activityTarget(pullRemote: String?, pullBranch: String?) -> ActivityTarget? {
        let push = pushTarget()

        return request.kind.transfer.map { transfer in
            switch transfer {
            case .fetch:
                ActivityTarget(transfer: transfer, remote: allRemotes ? nil : remote, refspec: nil)

            case .pull:
                ActivityTarget(transfer: transfer, remote: pullRemote, refspec: pullBranch)

            case .push:
                ActivityTarget(
                    transfer: transfer,
                    remote: push.remote,
                    refspec: "refs/heads/" + localBranch + ":refs/heads/" + push.branch
                )
            }
        }
    }

    /// 与撤销记录的关系：新建分支与合并靠快照撤销，发布分支靠反向操作撤销，获取、拉取与推送不能撤销。
    private func undoRecording() -> UndoRecording {
        switch request.kind {
        case .create, .track, .merge: .reversible
        case .publish: .publishingBranch(localBranch, to: remote, as: name, setsUpstream: upstream)
        case .fetch, .pull, .push: .irreversible
        }
    }

    /// 远端分支短名按所属远端切除前缀，兼容远端名中的斜杠。
    private func remoteBranchName(_ reference: String) -> String {
        guard
            let ref = branches.first(where: { $0.id == reference }),
            let remote = session.history.snapshot?.remote(for: ref)
        else { return reference }
        return String(reference.dropFirst(("refs/remotes/" + remote.name + "/").count))
    }

    /// 捕获表单值后关闭 sheet，再运行核心库动作。
    private func perform() {
        let destination = pushTarget()

        // 不与属性 source 同名：闭包里引用同名属性会让 Swift 6.3 的类型推断失败
        let revision = session.revision(for: source)
        let remote = remote
        let localBranch = localBranch
        let upstream = upstream
        let allRemotes = allRemotes
        let prune = prune
        let allTags = allTags
        let submodules = fetchSubmodules
        let fetching = session.fetchingRemote()
        let rebase = rebase
        let verify = pullVerify
        let skipHooks = skipHooks
        let kind = request.kind
        let selected = branches.first { $0.id == revision }
        let pullRemote = selected.flatMap { session.history.snapshot?.remote(for: $0) }
        let pullBranch = selected.map { "refs/heads/" + remoteBranchName($0.id) }
        let push = pushConfiguration()
        let merge = session.mergeAction(revision, options: mergeConfiguration())
        let createBranch = branchCreation(startingAt: revision)

        /// 按动作种类调用核心库，只读取上面复制的表单值。
        @Sendable
        func run(
            _ runner: GitRunner,
            _ output: @escaping @Sendable (GitOutputEvent) -> Void
        ) async throws {
            switch kind {
            case .create, .track:
                try await createBranch(runner)

            case .fetch:
                _ = try await RepositorySync(runner: runner)
                    .fetch(
                        remote: allRemotes ? nil : remote,
                        prune: prune,
                        allTags: allTags,
                        submodules: submodules,
                        onRemote: fetching,
                        onOutput: output
                    )

            case .pull:
                try await RepositorySync(runner: runner)
                    .pull(
                        remote: pullRemote?.name,
                        branch: pullBranch,
                        rebase: rebase,
                        verifySignatures: verify,
                        skipHooks: skipHooks,
                        onOutput: output
                    )

            case .push, .publish:
                _ = try await RepositorySync(runner: runner)
                    .push(
                        branch: localBranch,
                        remote: destination.remote,
                        destination: destination.branch,
                        setUpstream: kind == .publish && upstream,
                        options: push.options,
                        lease: push.lease,
                        onOutput: output
                    )

            case .merge:
                try await merge(runner, output)
            }
        }

        let target = activityTarget(pullRemote: pullRemote?.name, pullBranch: pullBranch)

        // 仓库在点击瞬间变为不可写时表单不关闭，原因显示在表单内，已填写的参数原样保留。
        _ = submit(AppLocalization.text(kind.rawValue), target, undoRecording(), run)
    }
}
