import AppKit
import SpookyKit
import SwiftUI

// MARK: - Detail Editing

extension RepositoryManagerController {
    /// 详情区的写操作能否开始：概况已读出，且应用内没有同一仓库的写操作。
    var canEditDetail: Bool {
        guard let detailLocation, case .loaded = detailState else {
            return false
        }

        return !RepositoryWriteLocks.shared.contains(detailLocation)
    }

    /// 编辑描述的对话框，预填当前描述。
    func editDescription() {
        guard canEditDetail, let location = detailLocation, case .loaded(let summary) = detailState else {
            return
        }

        window?.presentDialog { [weak self] close in
            EditDescriptionDialog(text: summary.description ?? "", close: close) { text in
                self?.write(location) { try await $0.setRepositoryDescription(text) }
            }
        }
    }

    /// 编辑仓库身份的对话框，预填当前提交人。
    func editIdentity() {
        guard canEditDetail, let location = detailLocation, case .loaded(let summary) = detailState else {
            return
        }

        window?.presentDialog { [weak self] close in
            EditIdentityDialog(
                name: summary.committer?.name ?? "",
                email: summary.committer?.email ?? "",
                close: close
            ) { name, email in
                self?.write(location) {
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

        write(location) { try await WorkingCopyOperations(runner: $0).clearIdentity() }
    }

    /// 选用身份档案：说明要写入的配置项与位置，确认后写进仓库本地配置。
    func applyProfile(_ profile: UserProfile) {
        guard canEditDetail, let location = detailLocation else {
            return
        }

        let keys = profile.signingKey == nil
            ? "user.name, user.email"
            : "user.name, user.email, user.signingkey, gpg.format"

        window?.presentDialog { close in
            ConfirmationDialog(
                title: AppLocalization.text("profiles.apply"),
                message: location.host == nil
                    ? AppLocalization.text("profiles.apply.local", keys, location.displayPath)
                    : AppLocalization.text("profiles.apply.remote", keys, location.displayPath),
                submitTitle: AppLocalization.text("profiles.apply.submit"),
                close: close
            ) { [weak self] _ in
                self?.write(location) {
                    try await WorkingCopyOperations(runner: $0)
                        .applyIdentity(name: profile.name, email: profile.email, signingKey: profile.signingKey)
                }
            }
        }
    }

    /// 写入仓库：登记应用内的写锁，失败时显示原文；结束后重读概况，显示同一仓库的窗口随之刷新。
    ///
    /// - Parameters:
    ///   - location: 详情区的仓库。
    ///   - operation: 经连接检查后的执行器完成的写入。
    private func write(_ location: RepositoryLocation, operation: @escaping @Sendable (GitRunner) async throws -> Void) {
        guard RepositoryWriteLocks.shared.acquire(location) else {
            return
        }

        Task { [weak self] in
            do {
                let runner = try await Self.openedRunner(for: location)
                try await operation(runner)
            } catch {
                self?.window?.showFailure(AppFailure(error: error, opening: false, location: location, writing: true))
            }

            RepositoryWriteLocks.shared.release(location)

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
