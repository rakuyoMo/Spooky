import AppKit
import SpookyKit
import SwiftUI

// MARK: - WorkingCopyCommitView

/// 提交区：标题框获得焦点时展开正文、选项与提交人，所有写操作共享会话锁定状态。
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

    /// 信息框焦点决定是否展开，以及 ⌥ 是否进入快速修补。
    @State
    private var focusedField: Field?

    /// ⌥ 同时切换全部暂存与快速修补。
    @State
    private var optionPressed = false

    /// 松开 ⌥ 时仅撤销本视图自动开启的修补状态。
    @State
    private var quickAmend = false

    /// 标题按回车或 Tab 时让正文获得焦点。
    @State
    private var bodyFocusRequest = 0

    /// 是否显示标题剩余字数。
    @AppStorage(CommitEditorSettings.showsSubjectCounterKey)
    private var showsCounter = true

    /// 标题字数上限。
    @AppStorage(CommitEditorSettings.subjectLimitKey)
    private var subjectLimit = CommitEditorSettings.defaultSubjectLimit

    /// 正文折行方式。
    @AppStorage(CommitEditorSettings.wrappingKey)
    private var wrapping = CommitEditorSettings.Wrapping.soft.rawValue

    /// 正文每行字数上限。
    @AppStorage(CommitEditorSettings.bodyLineLimitKey)
    private var bodyLineLimit = CommitEditorSettings.defaultBodyLineLimit

    /// 硬折行时显示参考线。
    @AppStorage(CommitEditorSettings.showsGuideKey)
    private var showsGuide = true

    /// Sign Off 勾选状态，所有仓库共用。
    @AppStorage(CommitEditorSettings.signOffKey)
    private var signOff = false

    /// 钉住后正文区保持展开。
    @AppStorage(CommitEditorSettings.pinnedKey)
    private var pinned = false

    /// 正文区高度。
    @AppStorage(CommitEditorSettings.bodyHeightKey)
    private var bodyHeight = CommitEditorSettings.minimumBodyHeight

    /// 进行中横幅位于信息区上方，冲突解决后重新显示提交控件。
    ///
    /// 储藏恢复等没有进行中操作的冲突既没有横幅也没有提交控件，此时整块不留边距，不显示空的底色块。
    var body: some View {
        VStack(spacing: 12) {
            OperationBannerView(session: session)

            if session.conflictCount == 0 {
                // 提交成功到清空信息之间，选项与按钮同信息框一起锁定。
                VStack(spacing: 8) {
                    subjectField

                    if isExpanded {
                        details
                    }

                    actionRow
                }
                .disabled(session.commitResetTask != nil)
            }
        }
        .padding(session.conflictCount == 0 || session.context?.progress != nil ? 20 : 0)
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
    /// 焦点在信息框、已钉住或正文非空时展开。
    private var isExpanded: Bool {
        focusedField != nil || pinned || !session.commitBody.isEmpty
    }

    /// 写入、提交后等待清空、快速修补和继续序列期间信息只读。
    private var isEditable: Bool {
        !(session.isWriting || session.commitResetTask != nil || quickAmend || continuesSequence)
    }

    /// 标题剩余字数，超出上限时为负数。
    private var remaining: Int {
        max(1, subjectLimit) - session.commitSubject.count
    }

    /// 硬折行时使用等宽字体、参考线与上限列折行。
    private var hardWrap: Bool {
        wrapping == CommitEditorSettings.Wrapping.hard.rawValue
    }

    /// 单行标题，右端是剩余字数；回车或 Tab 转到正文。
    private var subjectField: some View {
        CommitMessageEditor(
            role: .subject,
            text: $session.commitSubject,
            placeholder: AppLocalization.text("working.subject"),
            isEditable: isEditable,
            monospaced: hardWrap,
            characterLimit: max(1, subjectLimit),
            reformatLimit: nil,
            wrapColumn: nil,
            showsGuide: false,
            focusRequest: session.commitFocusRequest,
            onFocusChange: { focusChanged(.subject, focused: $0) },
            onSubmit: { bodyFocusRequest += 1 },
            completions: { await session.completions(for: $0) }
        )
        .padding(.trailing, showsCounter ? 36 : 0)
        .overlay(alignment: .trailing) {
            if showsCounter {
                Text(String(remaining))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                    .accessibilityLabel(AppLocalization.text("commit.remaining", remaining))
            }
        }
        .frame(height: 29)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.separator))
    }

    /// 正文框连同底部的钉住与折行按钮，下沿与右下角可拖动；其下是提交选项与提交人。
    private var details: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                CommitMessageEditor(
                    role: .body,
                    text: $session.commitBody,
                    placeholder: AppLocalization.text("working.body") + "\n\n" + AppLocalization.text("commit.quickAmendHint"),
                    isEditable: isEditable,
                    monospaced: hardWrap,
                    characterLimit: hardWrap ? nil : max(1, bodyLineLimit),
                    reformatLimit: max(1, bodyLineLimit),
                    wrapColumn: hardWrap ? max(1, bodyLineLimit) : nil,
                    showsGuide: showsGuide,
                    focusRequest: bodyFocusRequest,
                    onFocusChange: { focusChanged(.body, focused: $0) },
                    onSubmit: { },
                    completions: { await session.completions(for: $0) }
                )

                Divider()
                bodyActionBar
            }
            .frame(height: bodyHeight)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.separator))
            .overlay { resizeHandles }

            HStack(alignment: .top, spacing: 12) {
                options
                Spacer(minLength: 0)
                CommitIdentityView(session: session)
            }
        }
    }

    /// 钉住正文区与切换软 / 硬折行。
    private var bodyActionBar: some View {
        HStack(spacing: 8) {
            Button {
                pinned.toggle()
            } label: {
                Image(systemName: pinned ? "pin.fill" : "pin")
            }
            .help(AppLocalization.text("commit.pin"))
            .accessibilityLabel(AppLocalization.text("commit.pin"))

            Divider().frame(height: 14)

            #warning("TODO: 正文动作栏的折行按钮用于切换软 / 硬折行是推断。核实方式：确认这个按钮应切换全局的折行偏好，还是只切换当前草稿的显示；只影响这个按钮的作用。")
            Button {
                wrapping = (hardWrap ? CommitEditorSettings.Wrapping.soft : .hard).rawValue
            } label: {
                Image(systemName: "arrow.turn.down.left")
                    .foregroundStyle(hardWrap ? Color.accentColor : Color.secondary)
            }
            .help(AppLocalization.text(hardWrap ? "editor.hardWrap" : "editor.softWrap"))
            .accessibilityLabel(AppLocalization.text("editor.wrapping"))

            Spacer(minLength: 0)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 8)
        .frame(height: 24)
    }

    /// 正文框下沿 4 pt 高、只改高度的细条，以及右下角 20 × 20 pt、还能移动分隔线的拖柄。
    private var resizeHandles: some View {
        ZStack(alignment: .bottomTrailing) {
            CommitBodyResizeHandle(kind: .edge, height: $bodyHeight)
                .frame(height: 4)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            CommitBodyResizeHandle(kind: .corner, height: $bodyHeight)
                .frame(width: 20, height: 20)
        }
    }

    /// Amend、Sign Off 与 Skip Hooks；Skip Hooks 只在仓库启用了提交钩子时出现。
    private var options: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(amendTitle, isOn: Binding(get: { session.amend }, set: { session.setAmend($0) }))
                .disabled(
                    !session.canWrite || quickAmend
                        || session.status?.branch.oid == nil || session.context?.operation != nil
                )

            Toggle(AppLocalization.text("commit.signOff"), isOn: $signOff)
                .disabled(!session.canWrite || quickAmend)

            if session.commitConfiguration?.hasCommitHooks ?? false {
                Toggle(AppLocalization.text("commit.skipHooks"), isOn: $session.skipHooks)
                    .disabled(!session.canWrite || continuesSequence)
            }
        }
        .toggleStyle(.checkbox)
        .padding(.vertical, 2)
    }

    /// 勾上修补后标题带上被修补提交的短哈希。
    private var amendTitle: String {
        guard session.amend, let head = session.status?.branch.oid else {
            return AppLocalization.text("working.amend")
        }

        return AppLocalization.text("commit.amendHash", String(head.prefix(8)))
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

            if continuesSequence {
                Button(AppLocalization.text("working.continue")) { session.finishOperation("continue") }
                    .disabled(!session.canWrite)
                    .help(AppLocalization.text("commit.continueHelp"))
            } else {
                Button(AppLocalization.text(session.amend ? "working.amend" : "working.commit")) { session.commit() }
                    .disabled(!session.canCommit)
                    .help(AppLocalization.text(session.amend ? "commit.amendHelp" : "commit.commitHelp"))
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

        // 停在 edit 上时撤回到工作区的改动要先提交，继续在横幅里
        return [.rebase, .cherryPick, .revert].contains(operation) && !(session.context?.progress?.stopsForEdit ?? false)
    }

    /// 焦点在标题与正文之间移动时不收起：失去焦点后等这一轮事件结束，另一个框没有接过焦点才收起。
    private func focusChanged(_ field: Field, focused: Bool) {
        if focused {
            withAnimation(.easeInOut(duration: 0.2)) { focusedField = field }
            return
        }

        DispatchQueue.main.async {
            guard focusedField == field else { return }
            withAnimation(.easeInOut(duration: 0.2)) { focusedField = nil }
        }
    }
}
