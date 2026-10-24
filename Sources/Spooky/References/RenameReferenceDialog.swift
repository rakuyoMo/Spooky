import SpookyKit
import SwiftUI

// MARK: - RenameReferenceDialog

/// 重命名本地分支、远端分支或远端：一个名称框，名字为空、未变、不合法或已被占用时主按钮禁用。
struct RenameReferenceDialog: View {
    /// 要重命名的对象。
    enum Target {
        /// 本地分支或远端分支。
        case branch(RepositoryReference)

        /// 远端。
        case remote(String)
    }

    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 要重命名的对象。
    let target: Target

    /// 关闭 sheet。
    let close: () -> Void

    /// 打开对话框时的仓库；提交时仓库已切换则不执行。
    @State
    private var repository: RepositoryLocation?

    /// 新名字。
    @State
    private var name = ""

    /// 校验通过后才能提交。
    @State
    private var isValid = false

    /// 校验失败的说明。
    @State
    private var error = ""

    /// 输入时规范化引用名的开关，只作用于分支名。
    @AppStorage("cleanRefNames")
    private var cleanNames = true

    /// 一个 “Name:” 输入框，打开时填入原名字。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text(keys.title),
            message: AppLocalization.text(keys.message, originalName),
            submitTitle: AppLocalization.text("reference.rename"),
            error: error,
            isValid: isValid,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text("reference.name")) {
                TextField("", text: $name)
                    .accessibilityIdentifier("reference-name")
            }
        }
        .onAppear {
            repository = session.repository
            name = originalName
        }
        .onChange(of: name) {
            if cleanNames, case .branch = target {
                name = RepositoryReferences.normalizedName(name)
            }
        }
        .task(id: name) { await validate() }
    }
}

// MARK: - Actions

extension RenameReferenceDialog {
    /// 标题与说明的文案键：本地分支、远端分支与远端各一组。
    private var keys: (title: String, message: String) {
        switch target {
        case .branch(let reference) where reference.isRemote:
            ("branch.renameRemote", "branch.renameRemote.message")

        case .branch:
            ("branch.rename", "branch.rename.message")

        case .remote:
            ("remote.rename", "remote.rename.message")
        }
    }

    /// 原名字：远端分支去掉远端名前缀。
    private var originalName: String {
        switch target {
        case .branch(let reference): session.remoteParts(of: reference)?.branch ?? reference.name
        case .remote(let remote): remote
        }
    }

    /// 名字为空或未变时直接不可提交；其余按 Git 规则校验，并检查同名对象。
    private func validate() async {
        isValid = false
        error = ""

        guard !name.isEmpty, name != originalName, let runner = session.runner else {
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            let references = RepositoryReferences(runner: runner)

            switch target {
            case .branch:
                try await references.validate(name: name)

            case .remote:
                try await references.validate(remote: name)
            }

            try Task.checkCancellation()

            if let conflict = conflictMessage() {
                error = conflict
                return
            }

            isValid = true
        } catch {
            if !Task.isCancelled {
                self.error = ReferenceDialogRows.validationMessage(error, in: session)
            }
        }
    }

    /// 新名字已被同类对象占用时的说明。
    private func conflictMessage() -> String? {
        let snapshot = session.history.snapshot

        switch target {
        case .branch(let reference):
            if let parts = session.remoteParts(of: reference) {
                let id = "refs/remotes/" + parts.remote + "/" + name
                let taken = snapshot?.references.contains { $0.id == id } ?? false
                return taken ? AppLocalization.text("branch.remoteExists", name, parts.remote) : nil
            }

            let taken = snapshot?.references.contains { $0.id == "refs/heads/" + name } ?? false
            return taken ? AppLocalization.text("branch.exists") : nil

        case .remote:
            let taken = snapshot?.remotes.contains { $0.name == name } ?? false
            return taken ? AppLocalization.text("remote.exists") : nil
        }
    }

    /// 捕获表单值后开始写入；仓库忙碌或已切换时表单保持打开。
    private func submit() {
        let name = name
        let title = AppLocalization.text(keys.title)

        guard session.repository == repository else {
            return
        }

        let started: Bool =
            switch target {
            case .branch(let reference):
                if let parts = session.remoteParts(of: reference) {
                    session.performGit(
                        { runner, output in
                            try await RepositoryReferences(runner: runner)
                                .renameRemoteBranch(parts.branch, on: parts.remote, to: name, onOutput: output)
                        },
                        title: title
                    )
                } else {
                    session.performGit(
                        { runner, _ in try await RepositoryReferences(runner: runner).rename(reference.id, to: name) },
                        title: title
                    )
                }

            case .remote(let remote):
                session.performGit(
                    { runner, _ in try await RepositoryRemotes(runner: runner).rename(remote, to: name) },
                    title: title,
                    success: { [session] in
                        if session.selectedRemote == remote { session.selectedRemote = name }
                    }
                )
            }

        if started {
            close()
        }
    }
}
