import SpookyKit
import SwiftUI

// MARK: - SyncDialogKind

/// 同步、变基、安全强推与推送任意版本这四个对话框。
enum SyncDialogKind {
    /// 依次获取、拉取、推送当前分支（Sync…）。
    case sync

    /// 把当前分支变基到所选分支上（Rebase…）。
    case rebase

    /// 带明确期望值的强推（Force Push with Lease…）。
    case forcePush

    /// 把任意版本推到远端的指定引用，包括 Gerrit 评审引用（Push To…）。
    case pushRevision

    /// 对话框标题的资源键。
    var titleKey: String {
        switch self {
        case .sync: "sync.syncHead"
        case .rebase: "sync.rebaseHead"
        case .forcePush: "sync.forcePushLease"
        case .pushRevision: "sync.pushRevision"
        }
    }

    /// 主按钮与 Activity 记录的资源键。
    var actionKey: String {
        switch self {
        case .sync: "sync.sync"
        case .rebase: "sync.rebaseHead"
        case .forcePush: "sync.forcePush"
        case .pushRevision: "sync.pushRevision"
        }
    }
}

// MARK: - SyncDialog

/// 参数 sheet 提交后立即关闭，Git 的进度与失败由仓库窗口承接；骨架与其它操作对话框一致。
struct SyncDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 对话框种类。
    let kind: SyncDialogKind

    /// 入口预选的变基目标分支（完整引用名）或推送来源（分支名或标签名）；为 nil 时按 HEAD 的跟踪关系预选。
    var preselection: String? = nil

    /// 关闭 sheet。
    let close: () -> Void

    /// 打开对话框时的仓库；提交时仓库已切换则不执行。
    @State
    var repository: RepositoryLocation?

    /// 同步的远端分支、变基的目标分支、强推的本地分支，或推送的版本。
    @State
    var source = ""

    /// 强推的远端分支，或推送到的远端引用。
    @State
    var destination = ""

    /// 推送任意版本时选的远端。
    @State
    var remote = ""

    /// 跳过钩子只在本次表单生效。
    @State
    var skipHooks = false

    /// 表单内的加载与校验错误。
    @State
    var error = ""

    /// 强推的提交数与状态；所选分支变化后重新计算。
    @State
    var lease: ForcePushPreview?

    /// 强推核对进行中。
    @State
    var checkingLease = false

    /// 选项展开状态不持久化。
    @State
    private var optionsExpanded = false

    /// 拉取以变基代替合并，与拉取对话框共用记忆。
    @AppStorage("pullUseRebase")
    var rebase = false

    /// 校验取回提交的签名，与拉取对话框共用记忆。
    @AppStorage("pullVerifySignatures")
    var verify = false

    /// 推送时另推全部标签，与推送对话框共用记忆。
    @AppStorage("pushAllTags")
    var pushAllTags = false

    /// 推送时递归处理子模块，与推送对话框共用记忆。
    @AppStorage("pushRecurseSubmodules")
    var pushSubmodules = false

    /// 递归处理子模块的方式，与推送对话框共用记忆。
    @AppStorage("pushSubmoduleMode")
    var pushSubmoduleMode = SubmodulePushMode.onDemand.rawValue

    /// 头部、内容、状态、错误、折叠选项与底栏依次排列。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Grid(horizontalSpacing: 8, verticalSpacing: 10) {
                form
            }
            .font(.system(size: 13))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if [.sync, .rebase].contains(kind) {
                MergeabilityPreview(session: session, revision: source)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            if kind == .forcePush {
                leaseStatus
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            notices

            DisclosureGroup(AppLocalization.text("dialog.options"), isExpanded: $optionsExpanded) {
                options.padding(.vertical, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(AppPalette.color("general_secondary_background_color"))

            footer
        }
        .frame(width: 540)
        .onAppear(perform: prepare)
        .onChange(of: source) {
            if kind == .forcePush {
                selectDestination()
            }
        }
        .task(id: source + "\u{0}" + destination) { await loadLease() }
    }
}

// MARK: - Layout

extension SyncDialog {
    /// 头部：图标、标题、仓库路径与说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text(kind.titleKey))
                    .font(.system(size: 14, weight: .bold))

                Text(session.repository?.displayPath ?? "")
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Text(help)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 标题下的说明；同步写出当前分支名。
    private var help: String {
        guard kind == .sync else {
            return AppLocalization.text(kind.titleKey + ".help")
        }

        return AppLocalization.text("sync.syncHead.help", session.status?.branch.head ?? "")
    }

    /// 表单内的错误与仓库暂不可写的说明。
    @ViewBuilder
    private var notices: some View {
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
    }

    /// 底栏：取消与执行按钮，参数不完整或仓库不可写时禁用执行。
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(AppLocalization.text("action.cancel"), action: close)
                .keyboardShortcut(.cancelAction)

            Button(AppLocalization.text(kind.actionKey), action: perform)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
        }
        .padding(.horizontal, 20)
        .frame(height: 53)
    }

    /// 勾选项说明保持正常文本色，仅禁用时随控件变灰。
    func option(_ key: String, value: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(AppLocalization.text(key), isOn: value)

            Text(AppLocalization.text(key + ".help"))
                .font(.system(size: 11))
                .padding(.leading, 19)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
