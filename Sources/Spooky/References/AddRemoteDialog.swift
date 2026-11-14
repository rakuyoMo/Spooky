import SpookyKit
import SwiftUI

// MARK: - AddRemoteDialog

/// 添加远端：名称与地址；提交后先连上远端确认地址与认证，再写入配置，进度与失败进 Activity。
///
/// 执行期间表单保持打开、底栏显示进度，添加成功后才关闭；失败时错误框叠在表单上，关掉后填写的内容还在。
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

    /// 输入时规范化名称的开关，与新建分支共用。
    @AppStorage("cleanRefNames")
    private var cleanNames = true

    /// 添加正在执行。
    @State
    private var running = false

    /// 最近一次添加已成功，执行结束后据此关闭表单。
    @State
    private var succeeded = false

    /// “Name:” 与 “Remote URL:” 两个输入框。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("remote.add"),
            message: AppLocalization.text("remote.add.message"),
            submitTitle: AppLocalization.text("remote.add.submit"),
            error: error,
            progress: running ? AppLocalization.text("remote.checking") : nil,
            isValid: validName && !url.isEmpty && error.isEmpty && !running,
            cancel: close,
            submit: submit
        ) {
            RepositoryDialogRows.row(AppLocalization.text("reference.name")) {
                TextField("", text: $name, prompt: Text(AppLocalization.text("remote.name.placeholder")))
                    .accessibilityIdentifier("remote-name")
            }

            RepositoryDialogRows.row(AppLocalization.text("remote.url")) {
                TextField("", text: $url, prompt: Text(verbatim: "ssh://example.com/repo.git"))
                    .accessibilityIdentifier("remote-url")
            }
        }
        .onAppear { repository = session.repository }
        .onChange(of: name) {
            if cleanNames {
                name = RepositoryReferences.normalizedBranchName(name)
            }
        }
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
            return RepositoryDialogRows.validationMessage(error, in: session)
        }
    }

    /// 名称按 Git 的远端名规则校验，输入停顿后再查。
    private func validateName() async {
        validName = false

        // 输入停顿期间保留上一次的错误，新结果出来后一次替换；名字为空时没有错误
        guard !name.isEmpty, let runner = session.runner else {
            nameError = ""
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            try await RepositoryReferences(runner: runner).validate(remote: name)
            try Task.checkCancellation()
            nameError = ""
            validName = true
        } catch {
            if !Task.isCancelled {
                nameError = RepositoryDialogRows.validationMessage(error, in: session)
            }
        }
    }

    /// 开始添加，添加成功后关闭表单并随即获取这个远端；仓库忙碌、已切换或添加失败时表单保持打开。
    private func submit() {
        guard session.repository == repository else {
            return
        }

        succeeded = false

        guard session.addRemote(name: name, url: url, added: { succeeded = true }) else {
            return
        }

        running = true
        let write = session.writeTask

        // 写操作结束后：成功时关闭，失败时错误框已叠在表单上，表单留着
        Task {
            await write?.value
            running = false

            if succeeded {
                close()
            }
        }
    }
}
