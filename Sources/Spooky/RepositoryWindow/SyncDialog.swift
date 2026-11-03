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

    /// 把任意版本推到远端的指定引用（Push To…）。
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

    /// 主按钮的资源键。
    var submitKey: String {
        switch self {
        case .sync: "sync.syncHead"
        case .rebase: "sync.rebaseHead"
        case .forcePush: "sync.forcePush"
        case .pushRevision: "sync.pushRevision"
        }
    }

    /// 下拉框的宽度上限：同步与变基 360，安全强推 320，推送版本不设上限。
    var pickerWidth: CGFloat {
        switch self {
        case .sync, .rebase: 360
        case .forcePush: 320
        case .pushRevision: .infinity
        }
    }
}

// MARK: - SyncDialog

/// 参数 sheet 提交后立即关闭，Git 的进度与失败由仓库窗口承接；骨架是 `RepositoryDialogLayout`。
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

    /// 对话框骨架：头部、表单、错误区、Options 与底栏。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text(kind.titleKey),
            message: help,
            submitTitle: AppLocalization.text(kind.submitKey),
            error: error,
            isValid: canSubmit,
            cancel: close,
            submit: perform
        ) {
            form
        } options: {
            options
        }
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
    /// 标题下的说明；同步写出当前分支名。
    private var help: String {
        guard kind == .sync else {
            return AppLocalization.text(kind.titleKey + ".help")
        }

        return AppLocalization.text("sync.syncHead.help", session.status?.branch.head ?? "")
    }

    /// 勾选框与下一行的说明，说明的资源键是勾选框的资源键加 `.help`。
    ///
    /// - Parameter spacing: 勾选框到说明的间距。
    func option(_ key: String, spacing: CGFloat = 8, value: Binding<Bool>) -> DialogFormOption {
        DialogFormOption(
            title: AppLocalization.text(key),
            help: AppLocalization.text(key + ".help"),
            spacing: spacing,
            isOn: value
        )
    }
}
