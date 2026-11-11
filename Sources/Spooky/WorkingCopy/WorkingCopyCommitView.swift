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

    /// 提交区的坐标空间，标题框与正文框的位置以它的左上角为原点。
    private static let coordinateSpace = "working-copy-commit-area"

    /// 正文框底部动作栏的高度，上方另有 1 pt 由材质画出的分隔线。
    private static let bodyBarHeight: CGFloat = 24

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

    /// 标题框在提交区里的位置，供材质在同一处画出框的底与描边。
    @State
    private var subjectFrame: CGRect?

    /// 正文框在提交区里的位置，与标题框一样由材质画出框的底与描边。
    @State
    private var bodyFrame: CGRect?

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

    /// 进行中横幅位于信息区上方；进行中的操作还有未解决冲突或尚未开始时只显示横幅。
    ///
    /// 横幅自带外边距，信息区上、左、右各有 20 pt 内边距，两者之间不再留间距；按钮行下留 15 pt。
    var body: some View {
        VStack(spacing: 0) {
            OperationBannerView(session: session)

            if session.showsCommitArea {
                // 提交成功到清空信息之间，选项与按钮同信息框一起锁定。
                VStack(spacing: 8) {
                    subjectField

                    if isExpanded {
                        details
                    }

                    // 收起时按钮行距标题框 15 pt，展开时按 8 pt 的行距排在选项下面
                    actionRow
                        .padding(.top, isExpanded ? 0 : 7)
                }
                .disabled(session.commitResetTask != nil)
                .animation(.easeInOut(duration: 0.2), value: session.collapsesCommitBody)
                .padding(EdgeInsets(top: 20, leading: 20, bottom: 15, trailing: 20))
            }
        }
        .coordinateSpace(.named(Self.coordinateSpace))
        .background(
            // 提交后正文区收起时，材质里的正文框与正文区按同一动画淡出
            HeaderMaterial(fields: materialFields)
                .animation(.easeInOut(duration: 0.2), value: session.collapsesCommitBody)
        )
        .onModifierKeysChanged(mask: .option) { _, flags in
            optionPressed = flags.contains(.option)

            if optionPressed, focusedField == nil, !session.amend, session.canAmend {
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

// MARK: - Subject Counter

extension WorkingCopyCommitView {
    /// 标题剩余字数：上限减去去掉首尾空白后标题的 UTF-16 码元数，超出上限时为负数。
    ///
    /// 组合字符与 emoji 按码元计，不按字符计。标题与正文都为空或关闭计数时不显示，返回 nil。
    ///
    /// - Parameters:
    ///   - subject: 标题。
    ///   - body: 正文。
    ///   - limit: 标题字数上限，至少为 1。
    ///   - isEnabled: Editor 设置里是否显示计数。
    nonisolated static func remainingCharacters(
        subject: String,
        body: String,
        limit: Int,
        isEnabled: Bool
    ) -> Int? {
        guard isEnabled, !(subject.isEmpty && body.isEmpty) else {
            return nil
        }

        return max(1, limit) - subject.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count
    }
}

// MARK: - Private

extension WorkingCopyCommitView {
    /// 焦点在信息框、已钉住或正文非空时展开；提交成功后收起，直到信息框再次获得焦点。
    private var isExpanded: Bool {
        !session.collapsesCommitBody && (focusedField != nil || pinned || !session.commitBody.isEmpty)
    }

    /// 写入、提交后等待清空和快速修补期间信息只读；继续序列前可以编辑这一步的信息。
    private var isEditable: Bool {
        let locked = session.isWriting
            || session.commitResetTask != nil
            || quickAmend

        return !locked
    }

    /// 材质要画出的输入框：显示信息区时有标题框，展开时还有带动作栏的正文框。
    private var materialFields: [HeaderMaterialField] {
        guard session.showsCommitArea else {
            return []
        }

        let subject = subjectFrame.map { HeaderMaterialField(frame: $0) }

        let body = isExpanded
            ? bodyFrame.map { HeaderMaterialField(frame: $0, footerHeight: Self.bodyBarHeight + 1) }
            : nil

        return [subject, body].compactMap(\.self)
    }

    /// 标题右端显示的剩余字数；不显示时为 nil。
    private var remaining: Int? {
        Self.remainingCharacters(
            subject: session.commitSubject,
            body: session.commitBody,
            limit: subjectLimit,
            isEnabled: showsCounter
        )
    }

    /// 硬折行只改显示：等宽字体、正文不折行，参考线右侧变浅，超长的行整行标出。
    private var hardWrap: Bool {
        wrapping == CommitEditorSettings.Wrapping.hard.rawValue
    }

    /// 单行标题，右端是剩余字数；回车或 Tab 转到正文。
    ///
    /// 框的底与描边由提交区的材质在同一位置画出，剩余字数只在显示时占用标题右侧的空间。
    private var subjectField: some View {
        HStack(spacing: 0) {
            CommitMessageEditor(
                role: .subject,
                text: $session.commitSubject,
                placeholder: AppLocalization.text("working.subject"),
                isEditable: isEditable,
                releasesFocus: session.isCommitting,
                monospaced: hardWrap,
                characterLimit: max(1, subjectLimit),
                reformatLimit: nil,
                hardWrap: false,
                showsGuide: false,
                focusRequest: session.commitFocusRequest,
                onFocusChange: { focusChanged(.subject, focused: $0) },
                onSubmit: { bodyFocusRequest += 1 },
                completions: { await session.completions(for: $0) }
            )

            if let remaining {
                Text(String(remaining))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .padding(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 3))
                    .padding(.trailing, 1)
                    .accessibilityLabel(AppLocalization.text("commit.remaining", remaining))
            }
        }
        .frame(height: 29)
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(Self.coordinateSpace))
        } action: {
            subjectFrame = $0
        }
    }

    /// 正文每行的字数上限：仓库设置里有时用仓库的，否则用 Editor 设置页的。
    private var effectiveBodyLineLimit: Int {
        session.commitConfiguration?.bodyLineLimit ?? max(1, bodyLineLimit)
    }

    /// 正文框，其下是提交选项与提交人；选项行下留 11 pt。
    private var details: some View {
        VStack(spacing: 12) {
            bodyBox

            HStack(alignment: .top, spacing: 12) {
                options
                Spacer(minLength: 0)
                CommitIdentityView(session: session)
            }
        }
        .padding(.bottom, 11)
    }

    /// 正文框连同底部的钉住与折行按钮，下沿与右下角可拖动。
    ///
    /// 框的描边、输入区的底与动作栏上方的分隔线由提交区的材质在同一位置画出。
    private var bodyBox: some View {
        VStack(spacing: 0) {
            CommitMessageEditor(
                role: .body,
                text: $session.commitBody,
                placeholder: AppLocalization.text("working.body")
                    + "\n\n"
                    + AppLocalization.text("commit.quickAmendHint"),
                isEditable: isEditable,
                releasesFocus: session.isCommitting,
                monospaced: hardWrap,
                characterLimit: effectiveBodyLineLimit,
                reformatLimit: effectiveBodyLineLimit,
                hardWrap: hardWrap,
                showsGuide: session.commitConfiguration?.showsBodyGuide ?? showsGuide,
                focusRequest: bodyFocusRequest,
                onFocusChange: { focusChanged(.body, focused: $0) },
                onSubmit: { },
                completions: { await session.completions(for: $0) }
            )

            // 动作栏上方留出 1 pt，分隔线由材质画出
            bodyActionBar
                .padding(.top, 1)
        }
        .frame(height: bodyHeight)
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(Self.coordinateSpace))
        } action: {
            bodyFrame = $0
        }
        .overlay { resizeHandles }
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
        .frame(height: Self.bodyBarHeight)
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
                .disabled(!session.canAmend || quickAmend)

            Toggle(AppLocalization.text("commit.signOff"), isOn: $signOff)
                .disabled(!session.canWrite || quickAmend)

            if session.commitConfiguration?.hasCommitHooks ?? false {
                Toggle(AppLocalization.text("commit.skipHooks"), isOn: $session.skipHooks)
                    .disabled(!session.canWrite || session.continuesSequence)
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

            // 只有超过延迟仍未结束的提交才转圈，暂存、丢弃等其它写操作不显示
            if session.showsCommitProgress {
                ProgressView().controlSize(.small)
            }

            if session.continuesSequence {
                Button(AppLocalization.text("working.continue")) { session.continueSequence() }
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

    /// 焦点在标题与正文之间移动时不收起：失去焦点后等这一轮事件结束，另一个框没有接过焦点才收起。
    ///
    /// 提交成功后的收起在信息框重新获得焦点时结束。
    private func focusChanged(_ field: Field, focused: Bool) {
        if focused {
            withAnimation(.easeInOut(duration: 0.2)) {
                session.collapsesCommitBody = false
                focusedField = field
            }

            return
        }

        DispatchQueue.main.async {
            guard focusedField == field else { return }
            withAnimation(.easeInOut(duration: 0.2)) { focusedField = nil }
        }
    }
}
