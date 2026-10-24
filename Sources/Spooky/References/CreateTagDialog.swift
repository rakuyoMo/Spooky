import SpookyKit
import SwiftUI

// MARK: - CreateTagDialog

/// 新建标签：名称、版本、说明，以及签名与签名密钥；没有说明是轻量标签，签名时说明不能为空。
struct CreateTagDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 预填的版本；为 nil 时用当前分支，没有当前分支时用 HEAD。
    let revision: String?

    /// 关闭 sheet。
    let close: () -> Void

    /// 打开对话框时的仓库；提交时仓库已切换则不执行。
    @State
    private var repository: RepositoryLocation?

    /// 标签名。
    @State
    private var name = ""

    /// 版本框的文字。
    @State
    private var target = ""

    /// 标签说明。
    @State
    private var message = ""

    /// 选中的签名密钥；空字符串表示用仓库配置的密钥。
    @State
    private var signingKey = ""

    /// 本机可用的签名密钥。
    @State
    private var keys: [SigningKey] = []

    /// 名称校验通过。
    @State
    private var validName = false

    /// 名称校验失败的说明。
    @State
    private var nameError = ""

    /// 是否签名，跨仓库记忆。
    @AppStorage("signTag")
    private var sign = false

    /// 输入时规范化引用名的开关。
    @AppStorage("cleanRefNames")
    private var cleanNames = true

    /// 名称、版本、说明、签名与签名密钥依次排列。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text("tag.create"),
            message: AppLocalization.text("tag.create.message"),
            submitTitle: AppLocalization.text("tag.create.submit"),
            error: error,
            isValid: validName && !target.isEmpty && error.isEmpty,
            cancel: close,
            submit: submit
        ) {
            rows
        }
        .onAppear(perform: prepare)
        .onChange(of: name) {
            if cleanNames {
                name = RepositoryReferences.normalizedName(name)
            }
        }
        .task(id: name) { await validateName() }
        .task { keys = await SigningKeys.local() }
    }
}

// MARK: - Layout

extension CreateTagDialog {
    /// 表单各行；签名密钥只在勾选签名时可选。
    @ViewBuilder
    private var rows: some View {
        ReferenceDialogRows.row(AppLocalization.text("reference.name")) {
            TextField("", text: $name)
                .accessibilityIdentifier("tag-name")
        }

        // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐
        GridRow(alignment: .center) {
            Text(AppLocalization.text("tag.revision"))
                .gridColumnAlignment(.trailing)

            RevisionComboBox(
                text: $target,
                items: session.revisionReferences.map(\.name),
                label: AppLocalization.text("tag.revision")
            )
            .frame(maxWidth: .infinity)
        }

        ReferenceDialogRows.row(AppLocalization.text("tag.messageField")) {
            TextField("", text: $message, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
        }

        GridRow {
            Color.clear
                .gridCellUnsizedAxes([.horizontal, .vertical])

            Toggle(AppLocalization.text("tag.sign"), isOn: $sign)
        }

        ReferenceDialogRows.row(AppLocalization.text("tag.signingKey")) {
            Picker("", selection: $signingKey) {
                Text(AppLocalization.text("tag.signingKey.configured")).tag("")

                ForEach(keys, id: \.value) { Text(UserProfiles.title(of: $0)).tag($0.value) }
            }
            .labelsHidden()
            .disabled(!sign)
        }
    }
}

// MARK: - Actions

extension CreateTagDialog {
    /// 名称、重名与签名缺说明的说明；名称的 Git 校验结果优先。
    private var error: String {
        if !nameError.isEmpty {
            return nameError
        }

        if session.tags.contains(where: { $0.name == name }) {
            return AppLocalization.text("tag.exists")
        }

        if sign, message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AppLocalization.text("tag.signRequiresMessage")
        }

        if session.revisionReferences.isEmpty, session.status?.branch.oid == nil {
            return AppLocalization.text("tag.noRevisions")
        }

        return ""
    }

    /// 版本默认取入口指定的版本，否则取当前分支。
    private func prepare() {
        repository = session.repository
        target = revision.map { value in session.revisionReferences.first { $0.id == value }?.name ?? value }
            ?? session.status?.branch.head
            ?? "HEAD"
    }

    /// 名称按 Git 的标签规则校验，输入停顿后再查。
    private func validateName() async {
        validName = false
        nameError = ""

        guard !name.isEmpty, let runner = session.runner else {
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            try await RepositoryReferences(runner: runner).validate(tag: name)
            try Task.checkCancellation()
            validName = true
        } catch {
            if !Task.isCancelled {
                nameError = ReferenceDialogRows.validationMessage(error, in: session)
            }
        }
    }

    /// 捕获表单值后开始写入；仓库忙碌或已切换时表单保持打开。
    private func submit() {
        let name = name
        let revision = session.revision(for: target)
        let message = message
        let sign = sign
        let key = signingKey.isEmpty ? nil : signingKey

        guard session.repository == repository else {
            return
        }

        let started = session.performGit(
            { runner, _ in
                try await RepositoryTags(runner: runner)
                    .create(name: name, revision: revision, message: message, sign: sign, signingKey: key)
            },
            title: AppLocalization.text("tag.create"),
            undo: .reversible
        )

        if started {
            close()
        }
    }
}
