import SpookyKit
import SwiftUI

// MARK: - AddRemoteDialog

/// 添加远端：名称与地址；提交后先连上远端确认地址与认证，再写入配置，进度与失败进 Activity。
struct AddRemoteDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 关闭 sheet。
    let close: () -> Void

    /// 打开对话框时的仓库；提交时仓库已切换则不执行。
    @State
    private var repository: RepositoryLocation?

    /// 远端名。
    @State
    private var name = ""

    /// 远端地址。
    @State
    private var url = ""

    /// 名称校验通过。
    @State
    private var validName = false

    /// 名称校验失败的说明。
    @State
    private var nameError = ""

    /// “Name:” 与 “Remote URL:” 两个输入框。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text("remote.add"),
            message: AppLocalization.text("remote.add.message"),
            submitTitle: AppLocalization.text("remote.add.submit"),
            error: error,
            isValid: validName && !url.isEmpty && error.isEmpty,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text("reference.name")) {
                TextField("", text: $name, prompt: Text(AppLocalization.text("remote.name.placeholder")))
                    .accessibilityIdentifier("remote-name")
            }

            ReferenceDialogRows.row(AppLocalization.text("remote.url")) {
                TextField("", text: $url, prompt: Text(verbatim: "ssh://example.com/repo.git"))
                    .accessibilityIdentifier("remote-url")
            }
        }
        .onAppear { repository = session.repository }
        .task(id: name) { await validateName() }
    }
}

// MARK: - Actions

extension AddRemoteDialog {
    /// 名称与地址的说明：名称的 Git 校验结果优先，再看重名与地址写法。
    private var error: String {
        if !nameError.isEmpty {
            return nameError
        }

        if session.history.snapshot?.remotes.contains(where: { $0.name == name }) ?? false {
            return AppLocalization.text("remote.exists")
        }

        guard !url.isEmpty else {
            return ""
        }

        do {
            try RepositoryReferences.validate(url: url)
            return ""
        } catch {
            return ReferenceDialogRows.validationMessage(error, in: session)
        }
    }

    /// 名称按 Git 的远端名规则校验，输入停顿后再查。
    private func validateName() async {
        validName = false
        nameError = ""

        guard !name.isEmpty, let runner = session.runner else {
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            try await RepositoryReferences(runner: runner).validate(remote: name)
            try Task.checkCancellation()
            validName = true
        } catch {
            if !Task.isCancelled {
                nameError = ReferenceDialogRows.validationMessage(error, in: session)
            }
        }
    }

    /// 捕获表单值后开始添加；仓库忙碌或已切换时表单保持打开。
    private func submit() {
        let name = name
        let url = url

        guard session.repository == repository else {
            return
        }

        let started = session.performGit(
            { runner, output in
                try await RepositoryRemotes(runner: runner).add(name: name, url: url, onOutput: output)
            },
            title: AppLocalization.text("remote.add")
        )

        if started {
            close()
        }
    }
}
