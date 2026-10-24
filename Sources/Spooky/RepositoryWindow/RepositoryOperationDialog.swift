import SpookyKit
import SwiftUI

// MARK: - RepositoryActionRequest

/// 同一个 Git 动作的菜单、工具栏、右键和拖放共享参数入口。
struct RepositoryActionRequest {
    /// 本里程碑有实际行为的操作种类。
    enum Kind: String {
        /// 新建本地分支。
        case create = "branch.create"

        /// 新建跟踪远端的本地分支。
        case track = "branch.track"

        /// 获取一个或全部远端。
        case fetch = "sync.fetch"

        /// 显式合并或变基拉取。
        case pull = "sync.pull"

        /// 推送本地分支。
        case push = "sync.push"

        /// 首次发布分支。
        case publish = "sync.publish"

        /// 合并到当前分支。
        case merge = "sync.merge"
    }

    /// 对话框类型。
    let kind: Kind

    /// 已选的起点或目标引用。
    var reference: String? = nil

    /// 拖放或远端右键指定的远端。
    var remote: String? = nil

    /// 推送拖放指定的本地源分支。
    var localBranch: String? = nil

    /// 清理右键预设的选项。
    var prune = false
}

// MARK: - RepositoryOperationDialog

/// 参数 sheet 提交后立即关闭，Git 的进度与失败由仓库窗口承接。
struct RepositoryOperationDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 由入口确定的动作与预填项。
    let request: RepositoryActionRequest

    /// 取消只关闭表单。
    let cancel: () -> Void

    /// 提交交付显式参数对应的业务操作；返回 false 表示仓库暂不可写，表单保持打开。
    let submit:
        (
            String,
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

    /// 发布后设置 upstream。
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

    /// 选项展开状态不持久化。
    @State
    private var optionsExpanded = false

    /// 压缩合并与强制合并提交互斥。
    @State
    private var squash = false

    /// 跳过钩子只在本次表单生效。
    @State
    private var skipHooks = false

    /// 新建后检出偏好跨仓库保存。
    @AppStorage("checkoutCreatedBranch")
    private var checkout = true

    /// 输入时规范化名称的开关。
    @AppStorage("cleanRefNames")
    private var cleanNames = true

    /// 获取全部远端的默认选择。
    @AppStorage("fetchAllRemotes")
    private var allRemotes = true

    /// 清理远端引用的默认选择。
    @AppStorage("fetchPrune")
    private var prune = false

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

    /// 原生 sheet 骨架保持头部、内容、校验、折叠选项和底栏顺序。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            form
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            if !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            // 断线或其它写操作进行中时主按钮禁用，说明原因并保留已填写的参数。
            if !session.canWrite {
                Label(AppLocalization.text("dialog.blocked"), systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            if [.merge, .pull].contains(request.kind) { preview }

            if [.fetch, .merge, .pull, .push, .publish].contains(request.kind) {
                DisclosureGroup(AppLocalization.text("dialog.options"), isExpanded: $optionsExpanded) {
                    options.padding(.vertical, 12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppPalette.color("general_secondary_background_color"))
            }

            footer
        }
        .frame(width: 540)
        .onAppear(perform: prepare)
        .onChange(of: name) { if cleanNames { name = RepositoryReferences.normalizedName(name) } }
        .onChange(of: source) {
            if request.kind == .track { name = remoteBranchName(source) }
            if !canTrack { track = false }
        }
        .onChange(of: localBranch) { if request.kind == .publish { name = localBranch } }
        .task(id: name + "\u{0}" + remote) { await validateName() }
    }

    /// 当前所有可见的分支，起点组合框仍可输入提交哈希。
    private var branches: [RepositoryReference] { session.history.branches }

    /// 起点必须是实际分支才允许勾选跟踪。
    private var canTrack: Bool { branches.contains { $0.id == source || $0.name == source } }

    /// 表单校验在客户端及时反馈，执行时核心库仍重新核对。
    private var canSubmit: Bool {
        guard session.canWrite else { return false }
        switch request.kind {
        case .create: return validName && !source.isEmpty
        case .track: return validName && branches.contains { $0.id == source && $0.isRemote }
        case .fetch:
            return !(session.history.snapshot?.remotes.isEmpty ?? true) && (allRemotes || !remote.isEmpty)
        case .pull, .merge:
            return !source.isEmpty && session.status?.branch.head != nil && session.context?.operation == nil
        case .push, .publish:
            return validName && !remote.isEmpty && !localBranch.isEmpty
        }
    }
}

// MARK: - Layout

extension RepositoryOperationDialog {
    /// 头部：图标、动作名、仓库路径与动作说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text(request.kind.rawValue))
                    .font(.system(size: 14, weight: .bold))

                Text(session.repository?.displayPath ?? "")
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Text(AppLocalization.text(request.kind.rawValue + ".help"))
                    .font(.system(size: 13))
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 按功能呈现实际可用字段，不加入后续里程碑的选项。
    @ViewBuilder
    private var form: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 10) {
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
        .font(.system(size: 13))
    }

    /// 新建分支：名称、起点，以及跟踪起点与新建后检出的选项。
    @ViewBuilder
    private var createRows: some View {
        nameRow

        GridRow {
            Text(AppLocalization.text("branch.start")).gridColumnAlignment(.trailing)
            TextField("", text: $source)
                .textInputSuggestions {
                    ForEach(branches) { Text($0.name).textInputCompletion($0.id) }
                }
                .accessibilityLabel(AppLocalization.text("branch.start"))
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            VStack(alignment: .leading, spacing: 8) {
                option("branch.trackStart", value: $track).disabled(!canTrack)
                option("branch.checkoutCreated", value: $checkout)
            }
        }
    }

    /// 跟踪远端分支：远端分支、本地名称与新建后检出的选项。
    @ViewBuilder
    private var trackRows: some View {
        branchPicker(local: false)
        nameRow

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            option("branch.checkoutCreated", value: $checkout)
        }
    }

    /// 获取：选择单个远端，或改为获取全部远端。
    @ViewBuilder
    private var fetchRows: some View {
        remotePicker.disabled(allRemotes)

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            Toggle(AppLocalization.text("sync.allRemotes"), isOn: $allRemotes)
        }
    }

    /// 拉取：远端分支与是否以变基方式拉取。
    @ViewBuilder
    private var pullRows: some View {
        branchPicker(local: false)

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            option("sync.rebase", value: $rebase)
        }
    }

    /// 合并：目标分支，以及压缩、合并提交与自动提交的选项。
    @ViewBuilder
    private var mergeRows: some View {
        branchPicker(local: nil)

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            VStack(alignment: .leading, spacing: 8) {
                option("merge.squash", value: $squash).disabled(alwaysCommit)
                option("merge.alwaysCommit", value: $alwaysCommit).disabled(squash)

                // 自动提交只在强制创建合并提交且不压缩时可改，其余情况固定显示为勾选。
                option(
                    "merge.autoCommit",
                    value: Binding(
                        get: { alwaysCommit && !squash ? autoCommit : true },
                        set: { autoCommit = $0 }
                    )
                )
                .disabled(!alwaysCommit || squash)
            }
        }
    }

    /// 推送与发布：本地分支、远端、远端分支名与设置 upstream 的选项。
    @ViewBuilder
    private var pushRows: some View {
        GridRow {
            Text(AppLocalization.text("branch.local")).gridColumnAlignment(.trailing)
            Picker("", selection: $localBranch) {
                ForEach(branches.filter(\.isLocal)) { Text($0.name).tag($0.name) }
            }
            .labelsHidden()
            .accessibilityLabel(AppLocalization.text("branch.local"))
        }

        remotePicker
        nameRow

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            option("sync.setUpstream", value: $upstream)
        }
    }

    /// 名称字段在创建和发布时采用相同的实时规范化。
    private var nameRow: some View {
        GridRow {
            Text(AppLocalization.text("branch.name")).gridColumnAlignment(.trailing)
            TextField("", text: $name)
                .accessibilityLabel(AppLocalization.text("branch.name"))
                .accessibilityIdentifier("branch-name")
        }
    }

    /// 远端从配置快照中选择，不在 UI 接受未经验证的 URL。
    private var remotePicker: some View {
        GridRow {
            Text(AppLocalization.text("sync.remote")).gridColumnAlignment(.trailing)
            Picker("", selection: $remote) {
                ForEach(session.history.snapshot?.remotes ?? []) { Text($0.name).tag($0.name) }
            }
            .labelsHidden()
            .accessibilityLabel(AppLocalization.text("sync.remote"))
        }
    }

    /// 合并与拉取的可行性预览，随所选分支重新计算。
    private var preview: some View {
        MergeabilityPreview(session: session, revision: source)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
    }

    /// Fetch、合并及推送附带的选项按各自行为过滤。
    @ViewBuilder
    private var options: some View {
        VStack(alignment: .leading, spacing: 8) {
            if request.kind == .fetch {
                option("sync.prune", value: $prune)
                option("sync.fetchSubmodules", value: $fetchSubmodules)
                option("sync.allTags", value: $allTags)
            }

            if request.kind == .merge { option("merge.verify", value: $mergeVerify).disabled(squash) }
            if request.kind == .pull { option("merge.verify", value: $pullVerify) }

            if request.kind == .push {
                option("sync.pushAllTags", value: $pushAllTags)
                option("sync.forcePush", value: $forcePush)

                SubmodulePushOption(enabled: $pushSubmodules, mode: $pushSubmoduleMode)
            }

            if request.kind != .fetch { option("sync.skipHooks", value: $skipHooks) }
        }
    }

    /// 底栏：取消与执行按钮，参数不完整或仓库不可写时禁用执行。
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(AppLocalization.text("action.cancel"), action: cancel)
                .keyboardShortcut(.cancelAction)

            Button(AppLocalization.text(request.kind.rawValue), action: perform)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
        }
        .padding(.horizontal, 20)
        .frame(height: 53)
    }

    /// 合并可选两类分支；拉取和跟踪只选远端。
    private func branchPicker(local: Bool?) -> some View {
        GridRow {
            Text(AppLocalization.text("branch.target")).gridColumnAlignment(.trailing)
            Picker("", selection: $source) {
                ForEach(branches.filter { local == nil || $0.isLocal == local }) {
                    Text($0.name).tag($0.id)
                }
            }
            .labelsHidden()
            .accessibilityLabel(AppLocalization.text("branch.target"))
        }
    }

    /// 勾选项说明保持正常文本色，仅禁用时随控件变灰。
    private func option(_ key: String, value: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(AppLocalization.text(key), isOn: value)
            Text(AppLocalization.text(key + ".help"))
                .font(.system(size: 11))
                .padding(.leading, 19)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        case .create: source = request.reference ?? "HEAD"

        case .track:
            source = request.reference ?? branches.first(where: \.isRemote)?.id ?? ""
            name = remoteBranchName(source)

        case .fetch:
            if request.remote != nil { allRemotes = false }
            if request.prune { prune = true }

        case .merge, .pull:
            let tracked = branches.first {
                $0.id == head?.upstream && (request.kind == .merge || $0.isRemote)
            }
            source =
                request.reference ?? tracked?.id
                    ?? branches.first(where: { $0.id != head?.id && (request.kind == .merge || $0.isRemote) })?.id
                    ?? ""

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
            upstream = request.kind == .publish || selected?.upstream == nil
        }

        if
            [.fetch, .pull, .push, .publish, .track].contains(request.kind),
            session.history.snapshot?.remotes.isEmpty != false
        {
            error = AppLocalization.text("sync.noRemotes")
        }
    }

    /// 同名本地分支不能覆盖；名称校验异步去抖，保留 Git 原始错误。
    private func validateName() async {
        validName = false
        guard
            [.create, .track, .push, .publish].contains(request.kind), !name.isEmpty,
            let runner = session.runner
        else { return }
        do {
            try await Task.sleep(for: .milliseconds(150))
            try await RepositoryReferences(runner: runner).validate(name: name)
            try Task.checkCancellation()
            if
                [.create, .track].contains(request.kind),
                branches.contains(where: { $0.id == "refs/heads/" + name })
            {
                error = AppLocalization.text("branch.exists")
                return
            }
            if
                request.kind == .publish,
                branches.contains(where: { $0.id == "refs/remotes/" + remote + "/" + name })
            {
                error = AppLocalization.text("branch.exists")
                return
            }
            validName = true
            error = ""
        } catch {
            if !Task.isCancelled {
                self.error = AppFailure(error: error, opening: false, location: session.repository).details
            }
        }
    }

    /// 推送的选项与强推期望值：发布只带跳过钩子；推送时强推以表单所见的远端跟踪分支为期望值，没有跟踪分支时要求远端分支不存在。
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

        let tracking = branches.first { $0.id == "refs/remotes/" + remote + "/" + name }
        return (options, forcePush ? tracking?.objectID ?? "" : nil)
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
        let name = name

        // 不与属性 source 同名：闭包里引用同名属性会让 Swift 6.3 的类型推断失败
        let revision = branches.first { $0.id == source || $0.name == source }?.id ?? source
        let remote = remote
        let localBranch = localBranch
        let checkout = checkout
        let track = track
        let upstream = upstream
        let allRemotes = allRemotes
        let prune = prune
        let allTags = allTags
        let submodules = fetchSubmodules
        let rebase = rebase
        let verify = request.kind == .pull ? pullVerify : mergeVerify
        let skipHooks = skipHooks
        let kind = request.kind
        let selected = branches.first { $0.id == revision }
        let pullRemote = selected.flatMap { session.history.snapshot?.remote(for: $0) }
        let pullBranch = selected.map { "refs/heads/" + remoteBranchName($0.id) }
        var mergeOptions = MergeOptions()
        mergeOptions.squash = squash
        mergeOptions.alwaysCreateCommit = alwaysCommit
        mergeOptions.commit = alwaysCommit && !squash ? autoCommit : true
        mergeOptions.verifySignatures = verify
        mergeOptions.skipHooks = skipHooks
        let options = mergeOptions
        let push = pushConfiguration()

        /// 按动作种类调用核心库，只读取上面复制的表单值。
        @Sendable
        func run(
            _ runner: GitRunner,
            _ output: @escaping @Sendable (GitOutputEvent) -> Void
        ) async throws {
            switch kind {
            case .create, .track:
                try await RepositoryReferences(runner: runner)
                    .create(
                        name: name,
                        startingAt: revision,
                        track: kind == .track || track,
                        checkout: checkout
                    )

            case .fetch:
                _ = try await RepositorySync(runner: runner)
                    .fetch(
                        remote: allRemotes ? nil : remote,
                        prune: prune,
                        allTags: allTags,
                        submodules: submodules,
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
                        remote: remote,
                        destination: name,
                        setUpstream: upstream,
                        options: push.options,
                        lease: push.lease,
                        onOutput: output
                    )

            case .merge:
                try await RepositorySync(runner: runner).merge(revision, options: options, onOutput: output)
            }
        }

        // 仓库在点击瞬间变为不可写时表单不关闭，原因显示在表单内，已填写的参数原样保留。
        _ = submit(AppLocalization.text(kind.rawValue), run)
    }
}
