import SpookyKit
import SwiftUI

// MARK: - StashDialog

/// 保存储藏、快照、应用储藏与自动储藏共用的 sheet；提交后立即关闭，进度与失败由仓库窗口承接。
struct StashDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 对话框种类与预填项。
    let request: StashRequest

    /// 打开对话框时的仓库；提交时仓库已切换则不执行。
    let repository: RepositoryLocation?

    /// 关闭 sheet。
    let close: () -> Void

    /// 储藏说明。
    @State
    private var message = ""

    /// 应用储藏时选中的储藏哈希。
    @State
    private var selectedStash = ""

    /// 保存储藏时是否包含未跟踪文件，跨仓库记忆。
    @AppStorage("stashIncludeUntracked")
    private var includeUntracked = false

    /// 应用成功后删除储藏，即 Pop。
    @AppStorage("stashDeleteAfterApply")
    private var deleteAfterApply = false

    /// 应用时恢复暂存区状态。
    @AppStorage("stashRestoreIndex")
    private var restoreIndex = false

    /// 自动储藏的操作完成后恢复改动，跨仓库记忆；没有保存值时不勾，储藏在操作完成后保留。
    @AppStorage("autoStashReapply")
    private var reapply = false

    /// 对话框骨架：内容区是表单；自动储藏换成备选底栏，中止在左，不储藏与储藏在右。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text(titleKey),
            message: AppLocalization.text(titleKey + ".help"),
            formInsets: formInsets,
            submitTitle: AppLocalization.text(submitKey),
            cancelTitle: AppLocalization.text(skipAction == nil ? "action.cancel" : "stash.autoStash.abort"),
            alternate: skipAction.map { (title: AppLocalization.text("stash.autoStash.skip"), action: $0) },
            error: notice,
            helpArticle: helpArticle,
            isValid: canSubmit,
            cancel: cancel,
            submit: submit
        ) {
            form
        }
        .onAppear(perform: prepare)
    }
}

// MARK: - Layout

extension StashDialog {
    /// 按种类呈现字段：说明与未跟踪文件、储藏与应用选项，或自动储藏的说明与恢复选项。
    @ViewBuilder
    private var form: some View {
        switch request {
        case .save(_, let entries):
            messageRow(placeholder: "stash.messagePlaceholder", height: 45, spacing: entries.isEmpty ? -1 : 0)

            // 部分储藏总是带上所选的未跟踪文件，不显示这个选项
            if entries.isEmpty {
                DialogFormOption(title: AppLocalization.text("stash.includeUntracked"), isOn: $includeUntracked)
            }

        case .apply:
            applyRows

        case .autoStash(let pending):
            // 完成后恢复时储藏只是临时的，说明不可编辑；修补旧提交时储藏一直保留，不提供恢复选项
            messageRow(placeholder: "stash.autoStash.placeholder", height: 43, disabled: reapplies(pending))

            if !pending.keepsStash {
                DialogFormOption(title: AppLocalization.text("stash.autoStash.reapply"), isOn: $reapply)
            }
        }
    }

    /// 表单第一行上方与最后一行下方的边距：储藏全部改动与快照上 12、下 11，应用储藏上 16、下 20，其余上下各 20。
    private var formInsets: (top: CGFloat, bottom: CGFloat) {
        switch request {
        case .save(_, let entries): entries.isEmpty ? (12, 11) : (20, 20)
        case .apply: (16, 20)
        case .autoStash: (20, 20)
        }
    }

    /// 应用储藏：不超过 350 pt 的储藏下拉、应用后删除与恢复暂存区两个选项。
    @ViewBuilder
    private var applyRows: some View {
        DialogFormRow(label: AppLocalization.text("stash.picker")) {
            Picker("", selection: $selectedStash) {
                ForEach(session.stashes.entries) { Text($0.subject).tag($0.id) }
            }
            .labelsHidden()
            .buttonSizing(.flexible)
            .dialogFieldWidth(350)
            .disabled(session.stashes.entries.isEmpty)
        }

        DialogFormOption(title: AppLocalization.text("stash.deleteAfterApply"), isOn: $deleteAfterApply)

        DialogFormOption(title: AppLocalization.text("stash.restoreIndex"), isOn: $restoreIndex)
    }

    /// 自动储藏的 Do Not Stash：关闭对话框，开始前询问的操作照常执行，被挡住的操作照常报告失败；其余种类没有这个按钮。
    private var skipAction: (() -> Void)? {
        guard case .autoStash(let pending) = request else {
            return nil
        }

        return {
            close()
            session.declineAutoStash(pending)
        }
    }

    /// 错误区的文字：应用储藏时没有储藏可选。
    private var notice: String {
        guard case .apply = request, session.stashes.entries.isEmpty else {
            return ""
        }

        return AppLocalization.text("stash.noStashes")
    }

    /// 填满输入列、按词折行的说明框；输入框本身高 45 pt（保存与快照）或 43 pt（自动储藏）。
    ///
    /// - Parameters:
    ///   - placeholder: 占位文字的资源键。
    ///   - height: 输入框本身的高度。
    ///   - spacing: 在表单行距之外与下一行多留的间距；储藏全部改动与快照是 −1，与勾选框相隔 7。
    ///   - disabled: 说明是否不可编辑。
    private func messageRow(
        placeholder: String,
        height: CGFloat,
        spacing: CGFloat = 0,
        disabled: Bool = false
    ) -> some View {
        DialogFormRow(label: AppLocalization.text("stash.message")) {
            BezelTextField(
                text: $message,
                label: AppLocalization.text("stash.message"),
                height: height,
                wraps: true,
                placeholder: AppLocalization.text(placeholder)
            )
            .disabled(disabled)
            .padding(.bottom, spacing)
        }
    }
}

// MARK: - Actions

extension StashDialog {
    /// 标题与说明的资源键。
    private var titleKey: String {
        switch request {
        case .save(let snapshot, let entries):
            switch (snapshot, entries.isEmpty) {
            case (false, true): "stash.save"
            case (true, true): "stash.snapshot"
            case (false, false): "stash.savePartial"
            case (true, false): "stash.snapshotPartial"
            }

        case .apply:
            "stash.apply"

        case .autoStash:
            "stash.autoStash"
        }
    }

    /// 主按钮的资源键：部分储藏与快照沿用保存和快照的按钮文字。
    private var submitKey: String {
        switch request {
        case .save(let snapshot, _): snapshot ? "stash.snapshot" : "stash.save"
        case .apply: "stash.apply"
        case .autoStash: "stash.autoStash.confirm"
        }
    }

    /// 帮助按钮打开的官网文章：储藏与快照同一节，只储藏所选文件时是部分储藏那一节。
    private var helpArticle: HelpArticle {
        switch request {
        case .save(_, let entries): entries.isEmpty ? .saveStash : .partialStash
        case .apply: .applyStash
        case .autoStash: .autoStash
        }
    }

    /// 输入在客户端及时校验，执行时核心库仍重新核对。
    private var canSubmit: Bool {
        guard session.repository == repository else { return false }

        switch request {
        case .save(_, let entries):
            guard entries.isEmpty else { return session.canStash(entries) }

            // 只有未跟踪文件时必须包含未跟踪文件，否则没有可储藏的改动
            let onlyUntracked = session.status?.entries.allSatisfy { $0.kind == .untracked } ?? true
            return session.canSaveStash && (includeUntracked || !onlyUntracked)

        case .apply:
            return session.stashes.entries.first { $0.id == selectedStash }.map(session.canApply) ?? false

        case .autoStash:
            return true
        }
    }

    /// 应用储藏预选入口指定的储藏，否则选最新的一个。
    private func prepare() {
        guard case .apply(let preselected) = request else { return }
        selectedStash = preselected?.id ?? session.stashes.entries.first?.id ?? ""
    }

    /// 自动储藏的操作完成后是否恢复改动：修补旧提交时总是保留储藏，其余按选项。
    private func reapplies(_ pending: AutoStashRequest) -> Bool {
        reapply && !pending.keepsStash
    }

    /// 取消或中止：关闭对话框；排进队列的检出轮到时的询问被中止时，连同它占着的轮次一起取消，后面排着的接着轮到。
    private func cancel() {
        close()

        if case .autoStash(let pending) = request, let turn = pending.turn {
            RepositoryWriteQueue.shared.cancel(turn)
        }
    }

    /// 捕获表单值后开始执行；仓库暂不可写时对话框保持打开，已填写的内容保留。
    private func submit() {
        guard canSubmit else { return }
        let started: Bool

        switch request {
        case .save(let snapshot, let entries):
            started = session.saveStash(
                snapshot: snapshot,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                includeUntracked: includeUntracked,
                entries: entries
            )

        case .apply:
            guard let stash = session.stashes.entries.first(where: { $0.id == selectedStash }) else { return }
            started = session.applyStash(stash, restoreIndex: restoreIndex, drop: deleteAfterApply)

        case .autoStash(let pending):
            // 完成后恢复时储藏只是临时的，说明固定为自动储藏的标记
            let reapply = reapplies(pending)
            let typed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = reapply || typed.isEmpty ? RepositoryStashState.autoStashMessage(at: Date()) : typed
            started = session.performAutoStash(pending, message: text, reapply: reapply)
        }

        if started { close() }
    }
}
