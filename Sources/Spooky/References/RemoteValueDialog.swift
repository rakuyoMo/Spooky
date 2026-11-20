import SpookyKit
import SwiftUI

// MARK: - RemoteValueDialog

/// 修改远端的一项设置：获取或推送地址，或者添加、修改一条 refspec；一个输入框，值不合法或未变时主按钮禁用。
///
/// 修改地址要先连上新地址：执行期间表单保持打开、底栏显示进度，成功后才关闭；失败时错误框叠在表单上，关掉后填写的值还在。
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

    /// 修改地址正在执行。
    @State
    private var running = false

    /// 最近一次修改地址已成功，执行结束后据此关闭表单。
    @State
    private var succeeded = false

    /// “Remote URL:” 或 “Refspec:” 一个输入框。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text(keys.title),
            message: AppLocalization.text(keys.message, remote),
            inputColumn: isURL ? 146 : DialogMetrics.inputColumn,
            submitTitle: AppLocalization.text(keys.submit),
            error: error,
            progress: running ? AppLocalization.text("remote.checking") : nil,
            helpArticle: isURL ? .remoteSettings : nil,
            isValid: isValid && !running,
            cancel: close,
            submit: submit
        ) {
            RepositoryDialogRows.row(AppLocalization.text(isURL ? "remote.url" : "remote.refspec")) {
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
                self.error = RepositoryDialogRows.validationMessage(error, in: session)
            }
        }
    }

    /// 值为空或未变时直接不可提交；地址只查写法，refspec 按 Git 规则校验。
    private func validate() async {
        isValid = false

        // 输入停顿期间保留上一次的错误，新结果出来后一次替换；值为空或未变时没有错误
        guard !value.isEmpty, value != original, let runner = session.runner else {
            error = ""
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

            error = ""
            isValid = true
        } catch {
            if !Task.isCancelled {
                self.error = RepositoryDialogRows.validationMessage(error, in: session)
            }
        }
    }

    /// 捕获表单值后开始写入；服务器已断开或仓库已切换时表单保持打开。修改 refspec 开始后即关闭，修改地址见 ``submitURL(remote:push:)``。
    private func submit() {
        let value = value
        let title = AppLocalization.text(keys.title)

        guard session.repository == repository else {
            return
        }

        switch target {
        case .url(let remote, let push):
            submitURL(remote: remote, push: push)

        case .refspec(let remote, let push, let original):
            let started = session.performGit(
                { runner, _ in
                    let remotes = RepositoryRemotes(runner: runner)

                    if let original {
                        try await remotes.replaceRefspec(original, with: value, in: remote, push: push)
                    } else {
                        try await remotes.addRefspec(value, to: remote, push: push)
                    }
                },
                title: title,
                touchesWorkingCopy: false,
                undo: .changingRemote(remote)
            )

            if started {
                close()
            }
        }
    }

    /// 开始修改地址，表单留到写操作结束：成功时关闭，失败时错误框已叠在表单上，表单留着；
    /// 仓库正有写操作时排进队列，表单随即关闭；服务器已断开时什么都不做。
    private func submitURL(remote: String, push: Bool) {
        let value = value
        let queued = session.repository.map { !RepositoryWriteQueue.shared.isIdle($0) } ?? false
        succeeded = false

        let started = session.performGit(
            { runner, output in
                try await RepositoryRemotes(runner: runner).setURL(value, of: remote, push: push, onOutput: output)
            },
            title: AppLocalization.text(keys.title),
            touchesWorkingCopy: false,
            undo: .changingRemote(remote),
            success: { succeeded = true }
        )

        guard started else {
            return
        }

        // 排进队列的修改由活动区与 Activity 窗口接着显示
        guard !queued else {
            close()
            return
        }

        running = true
        let write = session.writeTask

        Task {
            await write?.value
            running = false

            if succeeded {
                close()
            }
        }
    }
}
