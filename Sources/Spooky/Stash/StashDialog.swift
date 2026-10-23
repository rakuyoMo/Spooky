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

    #warning("TODO: 在全新的偏好下打开自动储藏对话框，核实 “完成后恢复改动” 是否默认勾选；只影响该选项的初始值。")

    /// 自动储藏的操作完成后恢复改动。
    @AppStorage("autoStashReapply")
    private var reapply = true

    /// 头部、内容、提示与底栏依次排列，与其它操作对话框的骨架一致。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Grid(horizontalSpacing: 8, verticalSpacing: 10) {
                form
            }
            .font(.system(size: 13))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if case .apply = request, session.stashes.entries.isEmpty {
                Label(AppLocalization.text("stash.noStashes"), systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            // 断线或其它写操作进行中时主按钮禁用，说明原因并保留已填写的内容。
            if !session.canWrite {
                Label(AppLocalization.text("dialog.blocked"), systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            footer
        }
        .frame(width: 540)
        .onAppear(perform: prepare)
    }
}

// MARK: - Layout

extension StashDialog {
    /// 头部：图标、标题、仓库路径与说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text(titleKey))
                    .font(.system(size: 14, weight: .bold))

                Text(session.repository?.displayPath ?? "")
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Text(AppLocalization.text(titleKey + ".help"))
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 按种类呈现字段：说明与未跟踪文件、储藏与应用选项，或自动储藏的说明与恢复选项。
    @ViewBuilder
    private var form: some View {
        switch request {
        case .save(_, let entries):
            messageRow(placeholder: "stash.messagePlaceholder")

            // 部分储藏总是带上所选的未跟踪文件，不显示这个选项
            if entries.isEmpty {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    Toggle(AppLocalization.text("stash.includeUntracked"), isOn: $includeUntracked)
                }
            }

        case .apply:
            applyRows

        case .autoStash:
            messageRow(placeholder: "stash.autoStash.placeholder")
                .disabled(reapply)

            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Toggle(AppLocalization.text("stash.autoStash.reapply"), isOn: $reapply)
            }
        }
    }

    /// 应用储藏：储藏下拉、应用后删除与恢复暂存区两个选项。
    @ViewBuilder
    private var applyRows: some View {
        GridRow {
            Text(AppLocalization.text("stash.picker")).gridColumnAlignment(.trailing)

            Picker("", selection: $selectedStash) {
                ForEach(session.stashes.entries) { Text($0.title).tag($0.id) }
            }
            .labelsHidden()
            .frame(maxWidth: 350, alignment: .leading)
            .disabled(session.stashes.entries.isEmpty)
            .accessibilityLabel(AppLocalization.text("stash.picker"))
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            VStack(alignment: .leading, spacing: 8) {
                Toggle(AppLocalization.text("stash.deleteAfterApply"), isOn: $deleteAfterApply)
                Toggle(AppLocalization.text("stash.restoreIndex"), isOn: $restoreIndex)
            }
        }
    }

    /// 底栏：普通对话框为取消与主按钮；自动储藏把中止放在左侧，右侧是不储藏与储藏。
    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 8) {
            if case .autoStash(let pending) = request {
                Button(AppLocalization.text("stash.autoStash.abort"), action: close)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(AppLocalization.text("stash.autoStash.skip")) {
                    close()
                    session.declineAutoStash(pending)
                }
            } else {
                Spacer()

                Button(AppLocalization.text("action.cancel"), action: close)
                    .keyboardShortcut(.cancelAction)
            }

            Button(AppLocalization.text(submitKey), action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
        }
        .padding(.horizontal, 20)
        .frame(height: 53)
    }

    /// 说明输入行。
    private func messageRow(placeholder: String) -> some View {
        GridRow {
            Text(AppLocalization.text("stash.message")).gridColumnAlignment(.trailing)

            TextField("", text: $message, prompt: Text(AppLocalization.text(placeholder)))
                .accessibilityLabel(AppLocalization.text("stash.message"))
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

    /// 输入在客户端及时校验，执行时核心库仍重新核对。
    private var canSubmit: Bool {
        guard session.canWrite, session.repository == repository else { return false }

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
            let typed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = reapply || typed.isEmpty ? AppLocalization.text("stash.autoStash.message", pending.title) : typed
            started = session.performAutoStash(pending, message: text, reapply: reapply)
        }

        if started { close() }
    }
}
