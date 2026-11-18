import AppKit
import SpookyKit
import SwiftUI

// MARK: - Detail Editing

extension RepositoryManagerController {
    /// 详情区的写操作能否开始：概况已读出，且同一仓库没有执行中或排队的写操作；详情区的写入不排队。
    var canEditDetail: Bool {
        guard let detailLocation, case .loaded = detailState else {
            return false
        }

        return RepositoryWriteQueue.shared.isIdle(detailLocation)
    }

    /// 编辑描述的对话框，预填当前描述。
    func editDescription() {
        guard canEditDetail, let location = detailLocation, case .loaded(let summary, _) = detailState else {
            return
        }

        window?.presentDialog { [weak self] close in
            EditDescriptionDialog(text: summary.description ?? "", close: close) { text in
                self?.write(location, title: AppLocalization.text("bookmarks.description.edit")) {
                    try await $0.setRepositoryDescription(text)
                }
            }
        }
    }

    /// 编辑仓库身份的对话框，预填当前提交人。
    func editIdentity() {
        guard canEditDetail, let location = detailLocation, case .loaded(let summary, _) = detailState else {
            return
        }

        window?.presentDialog { [weak self] close in
            EditIdentityDialog(
                name: summary.committer?.name ?? "",
                email: summary.committer?.email ?? "",
                close: close
            ) { name, email in
                self?.write(location, title: AppLocalization.text("bookmarks.identity.edit")) {
                    try await WorkingCopyOperations(runner: $0).applyIdentity(name: name, email: email, signingKey: nil)
                }
            }
        }
    }

    /// 删除仓库本地配置里的提交人，此后提交用全局身份。
    func clearIdentity() {
        guard canEditDetail, let location = detailLocation else {
            return
        }

        write(location, title: AppLocalization.text("bookmarks.identity.edit")) {
            try await WorkingCopyOperations(runner: $0).clearIdentity()
        }
    }

    /// 选用身份档案：说明要写入的配置项与位置，确认后写进仓库本地配置。
    func applyProfile(_ profile: UserProfile) {
        guard canEditDetail, let location = detailLocation else {
            return
        }

        window?.presentDialog { close in
            applyProfilePrompt(profile, to: location, close: close)
        }
    }

    /// 选用身份档案的询问：说明写出要写入的配置项与仓库，主按钮是 Use Profile；确认后写进仓库本地配置。
    ///
    /// - Parameters:
    ///   - profile: 要选用的身份档案。
    ///   - location: 详情区的仓库。
    ///   - close: 关闭询问。
    func applyProfilePrompt(
        _ profile: UserProfile,
        to location: RepositoryLocation,
        close: @escaping () -> Void
    ) -> ConfirmationDialog {
        let keys = profile.signingKey == nil
            ? "user.name, user.email"
            : "user.name, user.email, user.signingkey, gpg.format"

        return ConfirmationDialog(
            title: AppLocalization.text("profiles.apply"),
            message: location.host == nil
                ? AppLocalization.text("profiles.apply.local", keys, location.displayPath)
                : AppLocalization.text("profiles.apply.remote", keys, location.displayPath),
            submitTitle: AppLocalization.text("profiles.apply.submit"),
            close: close
        ) { [weak self] _ in
            self?.write(location, title: AppLocalization.text("profiles.apply")) {
                try await WorkingCopyOperations(runner: $0)
                    .applyIdentity(name: profile.name, email: profile.email, signingKey: profile.signingKey)
            }
        }
    }

    /// 写入仓库：仓库空闲时登记为执行中的写操作，不建 Activity 记录，失败时显示原文；期间各窗口提交的写操作排在它后面。
    /// 结束后重读概况，显示同一仓库的窗口随之刷新。
    ///
    /// - Parameters:
    ///   - location: 详情区的仓库。
    ///   - title: 已本地化的操作名称。
    ///   - operation: 经连接检查后的执行器完成的写入。
    private func write(
        _ location: RepositoryLocation,
        title: String,
        operation: @escaping @Sendable (GitRunner) async throws -> Void
    ) {
        let write = RepositoryWrite(location: location, session: nil, title: title, touchesWorkingCopy: false)

        guard RepositoryWriteQueue.shared.begin(write) else {
            return
        }

        Task { [weak self] in
            do {
                let runner = try await Self.openedRunner(for: location)
                try await operation(runner)
            } catch {
                self?.window?.showFailure(AppFailure(error: error, opening: false, location: location, writing: true))
            }

            RepositoryWriteQueue.shared.finish(write)

            guard let self else {
                return
            }

            if let window {
                coordinator?.repositoryChanged(location, by: window)
            }

            reloadDetail()
        }
    }
}
