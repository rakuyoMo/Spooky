import SpookyKit
import SwiftUI

// MARK: - RemoteValueDialog

/// 修改远端的一项设置：获取或推送地址，或者添加、修改一条 refspec；一个输入框，值不合法或未变时主按钮禁用。
struct RemoteValueDialog: View {
    /// 要修改的设置。
    enum Target {
        /// 获取地址或推送地址。
        case url(remote: String, push: Bool)

        /// 一条 refspec；原值为 nil 表示添加。
        case refspec(remote: String, push: Bool, original: String?)
    }

    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 要修改的设置。
    let target: Target

    /// 关闭 sheet。
    let close: () -> Void

    /// 打开对话框时的仓库；提交时仓库已切换则不执行。
    @State
    private var repository: RepositoryLocation?

    /// 打开时的值；添加 refspec 时为空。
    @State
    private var original = ""

    /// 输入框的值。
    @State
    private var value = ""

    /// 校验通过后才能提交。
    @State
    private var isValid = false

    /// 校验或读取失败的说明。
    @State
    private var error = ""

    /// “Remote URL:” 或 “Refspec:” 一个输入框。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text(keys.title),
            message: AppLocalization.text(keys.message, remote),
            submitTitle: AppLocalization.text(keys.submit),
            error: error,
            isValid: isValid,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text(isURL ? "remote.url" : "remote.refspec")) {
                TextField("", text: $value, prompt: isURL ? Text(verbatim: "ssh://example.com/repo.git") : nil)
                    .accessibilityIdentifier("remote-value")
            }
        }
        .task { await load() }
        .task(id: value) { await validate() }
    }
}

// MARK: - Actions

extension RemoteValueDialog {
    /// 远端名。
    private var remote: String {
        switch target {
        case .url(let remote, _), .refspec(let remote, _, _): remote
        }
    }

    /// 是否在修改地址。
    private var isURL: Bool {
        if case .url = target { true } else { false }
    }

    /// 标题、说明与主按钮的文案键：两种地址、添加与修改两种 refspec 各一组。
    private var keys: (title: String, message: String, submit: String) {
        switch target {
        case .url(_, push: true):
            ("remote.pushURL.edit", "remote.pushURL.edit.message", "remote.url.submit")

        case .url:
            ("remote.fetchURL.edit", "remote.fetchURL.edit.message", "remote.url.submit")

        case .refspec(_, push: true, original: nil):
            ("remote.refspec.addPush", "remote.refspec.addPush.message", "remote.refspec.add.submit")

        case .refspec(_, push: false, original: nil):
            ("remote.refspec.addFetch", "remote.refspec.addFetch.message", "remote.refspec.add.submit")

        case .refspec(_, push: true, _):
            ("remote.refspec.editPush", "remote.refspec.editPush.message", "remote.refspec.edit.submit")

        case .refspec:
            ("remote.refspec.editFetch", "remote.refspec.editFetch.message", "remote.refspec.edit.submit")
        }
    }

    /// 地址读出当前值；refspec 用入口给出的原值。
    private func load() async {
        repository = session.repository

        switch target {
        case .refspec(_, _, let original):
            self.original = original ?? ""
            value = self.original

        case .url(let remote, let push):
            guard let runner = session.runner else {
                return
            }

            do {
                let configuration = try await RepositoryRemotes(runner: runner).configurations()
                    .first { $0.name == remote }
                original = (push ? configuration?.pushURLs.first : configuration?.url) ?? ""
                value = original
            } catch {
                self.error = ReferenceDialogRows.validationMessage(error, in: session)
            }
        }
    }

    /// 值为空或未变时直接不可提交；地址只查写法，refspec 按 Git 规则校验。
    private func validate() async {
        isValid = false
        error = ""

        guard !value.isEmpty, value != original, let runner = session.runner else {
            return
        }

        do {
            switch target {
            case .url:
                try RepositoryReferences.validate(url: value)

            case .refspec(_, let push, _):
                try await Task.sleep(for: .milliseconds(150))
                try await RepositoryReferences(runner: runner).validate(refspec: value, push: push)
                try Task.checkCancellation()
            }

            isValid = true
        } catch {
            if !Task.isCancelled {
                self.error = ReferenceDialogRows.validationMessage(error, in: session)
            }
        }
    }

    /// 捕获表单值后开始写入；仓库忙碌或已切换时表单保持打开。
    private func submit() {
        let value = value
        let title = AppLocalization.text(keys.title)

        guard session.repository == repository else {
            return
        }

        let started: Bool =
            switch target {
            case .url(let remote, let push):
                session.performGit(
                    { runner, output in
                        try await RepositoryRemotes(runner: runner).setURL(value, of: remote, push: push, onOutput: output)
                    },
                    title: title
                )

            case .refspec(let remote, let push, let original):
                session.performGit(
                    { runner, _ in
                        let remotes = RepositoryRemotes(runner: runner)

                        if let original {
                            try await remotes.replaceRefspec(original, with: value, in: remote, push: push)
                        } else {
                            try await remotes.addRefspec(value, to: remote, push: push)
                        }
                    },
                    title: title
                )
            }

        if started {
            close()
        }
    }
}
