import AppKit
import SpookyKit
import SwiftUI

// MARK: - WorkingCopyCommitView

/// 提交区保持正文、身份与按钮可见，所有写操作共享会话锁定状态。
struct WorkingCopyCommitView: View {
    /// 标题与正文的键盘焦点。
    private enum Field: Hashable {
        /// 单行提交标题。
        case subject

        /// 多行提交正文。
        case body
    }

    /// 当前仓库的草稿与操作状态。
    @Bindable
    var session: RepositorySession

    /// 信息框焦点决定 ⌥ 是否进入快速修补。
    @FocusState
    private var focusedField: Field?

    /// ⌥ 同时切换全部暂存与快速修补。
    @State
    private var optionPressed = false

    /// 松开 ⌥ 时仅撤销本视图自动开启的修补状态。
    @State
    private var quickAmend = false

    /// 进行中横幅位于信息区上方，冲突解决后重新显示提交控件。
    var body: some View {
        VStack(spacing: 12) {
            OperationBannerView(session: session)

            if session.conflictCount == 0 {
                subjectField
                bodyEditor
                amendRow
                actionRow
            }
        }
        .padding(20)
        .background(AppPalette.color("general_header_background_color"))
        .onModifierKeysChanged(mask: .option) { _, flags in
            optionPressed = flags.contains(.option)

            if
                optionPressed, focusedField == nil, !session.amend,
                session.status?.branch.oid != nil, session.context?.operation == nil
            {
                session.setAmend(true)
                quickAmend = session.amend
            } else if !optionPressed, quickAmend {
                session.setAmend(false)
                quickAmend = false
            }
        }
        .onChange(of: focusedField) { session.isEditingCommitMessage = focusedField != nil }
        .onDisappear { session.isEditingCommitMessage = false }
        .onChange(of: session.commitFocusRequest) { focusedField = .subject }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            optionPressed = false

            if quickAmend {
                session.setAmend(false)
                quickAmend = false
            }
        }
    }
}

// MARK: - Private

extension WorkingCopyCommitView {
    /// 单行提交标题，回车后转到正文。
    private var subjectField: some View {
        TextField(AppLocalization.text("working.subject"), text: $session.commitSubject)
            .textFieldStyle(.roundedBorder)
            .focused($focusedField, equals: .subject)
            .disabled(session.isWriting || quickAmend || continuesSequence)
            .onSubmit { focusedField = .body }
            .accessibilityIdentifier("commit-subject")
    }

    /// 多行提交正文，内容为空时叠加不拦截点击的占位文字。
    private var bodyEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $session.commitBody)
                .font(.system(size: 13))
                .focused($focusedField, equals: .body)
                .disabled(session.isWriting || quickAmend || continuesSequence)
                .accessibilityLabel(AppLocalization.text("working.body"))
                .accessibilityIdentifier("commit-body")

            if session.commitBody.isEmpty {
                Text(AppLocalization.text("working.body"))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 5)
                    .padding(.top, 6)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 96)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.separator))
    }

    /// 修补开关与当前提交者身份。
    private var amendRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Toggle(AppLocalization.text("working.amend"), isOn: Binding(
                get: { session.amend }, set: { session.setAmend($0) }
            ))
            .toggleStyle(.checkbox)
            .disabled(
                !session.canWrite || quickAmend
                    || session.status?.branch.oid == nil || session.context?.operation != nil
            )

            Spacer(minLength: 0)

            Text(session.context?.committer ?? AppLocalization.text("working.identityLoading"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
                .help(session.repository?.displayPath ?? "")
        }
    }

    /// 全部暂存或取消暂存，以及提交、修补或继续序列的按钮。
    private var actionRow: some View {
        HStack {
            Button(AppLocalization.text(unstageAll ? "working.unstageAll" : "working.stageAll")) {
                session.stageAll(staged: !unstageAll)
            }
            .disabled(
                unstageAll
                    ? !session.canUnstage(session.status?.entries ?? [])
                    : !session.canStage(session.status?.entries ?? [])
            )

            Spacer(minLength: 0)

            if session.isWriting { ProgressView().controlSize(.small) }

            if let operation = session.context?.operation, [.rebase, .cherryPick, .revert].contains(operation) {
                Button(AppLocalization.text("working.continue")) { session.finishOperation("continue") }
                    .disabled(!session.canWrite)
            } else {
                Button(AppLocalization.text(session.amend ? "working.amend" : "working.commit")) { session.commit() }
                    .disabled(!session.canCommit)
                    .accessibilityIdentifier("commit-button")
            }
        }
    }

    /// 全部已暂存时自动切换；⌥ 在存在已暂存项时切到取消暂存。
    private var unstageAll: Bool {
        let entries = session.status?.entries ?? []
        return entries.contains(where: \.hasStagedChanges)
            && (optionPressed || !entries.contains(where: \.hasUnstagedChanges))
    }

    /// 序列继续沿用 Git 已保存的信息，普通提交和合并收尾才编辑输入。
    private var continuesSequence: Bool {
        guard let operation = session.context?.operation else { return false }
        return [.rebase, .cherryPick, .revert].contains(operation)
    }
}
