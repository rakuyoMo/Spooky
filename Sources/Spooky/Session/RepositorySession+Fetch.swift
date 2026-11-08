import Foundation
import SpookyKit

// MARK: - Fetch

extension RepositorySession {
    /// 自动获取：获取全部远端（跳过设了 skipFetchAll 的），不询问凭据，失败只记进 Activity。
    ///
    /// - Parameter defaults: 读取获取选项的偏好，测试使用独立的域。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func autoFetch(defaults: UserDefaults = .standard) -> Bool {
        fetchWithPreferences(
            nil,
            title: AppLocalization.text("sync.autoFetch"),
            undo: .unrecorded,
            background: true,
            defaults: defaults
        )
    }

    /// 快速获取：远端取自参数；未指定时按获取对话框的选择获取全部远端，或 HEAD 跟踪的远端。
    ///
    /// - Parameters:
    ///   - remote: 要获取的远端。
    ///   - defaults: 读取获取选项的偏好，测试使用独立的域。
    func quickFetch(remote: String? = nil, defaults: UserDefaults = .standard) {
        let target = remote
            ?? (SyncPreferences.fetchAllRemotes(in: defaults) ? nil : headBranch?.upstreamRemote)

        fetchWithPreferences(
            target,
            title: AppLocalization.text("sync.quickFetch"),
            undo: .irreversible,
            defaults: defaults
        )
    }

    /// Fetch All：获取全部远端（跳过设了 skipFetchAll 的），选项与快速获取相同。
    ///
    /// - Parameter defaults: 读取获取选项的偏好，测试使用独立的域。
    func fetchAll(defaults: UserDefaults = .standard) {
        fetchWithPreferences(
            nil,
            title: AppLocalization.text("sync.fetch"),
            undo: .irreversible,
            defaults: defaults
        )
    }

    /// 添加远端，成功后立即获取它；两步各记一条 Activity。
    ///
    /// 添加失败不获取；获取失败、取消或断线时远端已经添加，只报告获取的结果，不再重复添加。
    ///
    /// - Parameters:
    ///   - name: 远端名。
    ///   - url: 远端地址。
    ///   - defaults: 读取获取选项的偏好，测试使用独立的域。
    /// - Returns: 添加是否已开始执行；仓库不可写时不启动，调用方据此保留表单。
    @discardableResult
    func addRemote(name: String, url: String, defaults: UserDefaults = .standard) -> Bool {
        performGit(
            { runner, output in
                try await RepositoryRemotes(runner: runner).add(name: name, url: url, onOutput: output)
            },
            title: AppLocalization.text("remote.add"),
            undo: .addingRemote(name),
            success: { [weak self] in
                self?.fetchAddedRemote(name, defaults: defaults)
            }
        )
    }
}

// MARK: - Private

extension RepositorySession {
    /// 添加远端的写操作结束后获取这个远端；期间换了仓库就不再获取。
    ///
    /// 获取由添加带起，不碰撤销记录，添加仍可撤销。
    private func fetchAddedRemote(_ name: String, defaults: UserDefaults) {
        guard let repository, let adding = writeTask else {
            return
        }

        Task { [weak self] in
            // 添加的写锁在它的任务结束时才释放
            await adding.value

            guard let self, self.repository == repository else {
                return
            }

            fetchWithPreferences(
                name,
                title: AppLocalization.text("sync.fetch"),
                undo: .unrecorded,
                defaults: defaults
            )
        }
    }

    /// 跳过对话框的获取共用的写操作：清理与递归子模块读获取对话框保存的偏好，不带全部标签。
    ///
    /// - Parameters:
    ///   - remote: 要获取的远端；nil 表示全部远端，跳过设了 skipFetchAll 的。
    ///   - title: 已本地化的操作名称。
    ///   - undo: 与撤销记录的关系。
    ///   - background: 不由用户直接发起：不询问凭据，失败只记进 Activity。
    ///   - defaults: 读取获取选项的偏好。
    /// - Returns: 是否已开始执行。
    @discardableResult
    private func fetchWithPreferences(
        _ remote: String?,
        title: String,
        undo: UndoRecording,
        background: Bool = false,
        defaults: UserDefaults
    ) -> Bool {
        let options = SyncPreferences.fetchOptions(in: defaults)

        return performGit(
            { runner, output in
                // 后台获取不能弹出输入框，只用已存的凭据
                try await RemoteCallbackRequest.$allowsInteraction.withValue(!background) {
                    _ = try await RepositorySync(runner: runner)
                        .fetch(
                            remote: remote,
                            prune: options.prune,
                            submodules: options.submodules,
                            onRemote: ActivityRecording.fetching,
                            onOutput: output
                        )
                }
            },
            title: title,
            target: .fetch(remote),
            reportsFailure: !background,
            undo: undo
        )
    }
}
