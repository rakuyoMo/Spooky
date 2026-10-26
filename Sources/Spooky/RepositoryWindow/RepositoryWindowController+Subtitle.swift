import AppKit

// MARK: - Subtitle

extension RepositoryWindowController {
    /// 仓库视图的窗口副标题：工作区写出分支与改动数，历史写出所选引用与提交数，储藏视图显示储藏的数量，Reflog 写出所看的引用，文件历史与文件原文写出所看的文件，远端设置写出远端名，仓库设置写 Settings，子模块写出子模块名。
    var repositorySubtitle: String {
        switch session.activeView {
        case .workingCopy:
            workingCopySubtitle

        case .history:
            historySubtitle

        case .stashes:
            AppLocalization.text("stash.subtitle", session.stashes.entries.count)

        case .reflog:
            AppLocalization.text("reflog.subtitle", ReflogListView.name(of: session.reflog.reference))

        case .fileHistory:
            fileHistorySubtitle

        case .fileContent:
            fileContentSubtitle

        case .remote:
            AppLocalization.text("remote.subtitle", session.selectedRemote ?? "")

        case .branchesReview:
            AppLocalization.text("review.title")

        case .settings:
            AppLocalization.text("repositorySettings.title")

        case .submodule:
            AppLocalization.text("submodule.subtitle", session.submodules.selected?.name ?? "")
        }
    }

    /// 按当前视图写入副标题；仓库管理、丢失页与克隆进度页这类没有打开仓库的页面副标题为空。
    func updateSubtitle() {
        window?.subtitle = showsManager || session.repository == nil ? "" : repositorySubtitle
    }

    /// 副标题依赖的会话状态变化后重新写入。
    func observeSubtitle() {
        withObservationTracking {
            _ = repositorySubtitle
        } onChange: { [weak self] in
            // 变更通知早于新值写入，下一轮主线程再更新并重新订阅。
            Task { @MainActor in
                self?.updateSubtitle()
                self?.observeSubtitle()
            }
        }
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 工作区的副标题：“Working Copy (分支 – n Changed Files)”，分离 HEAD 或还没读到状态时不写分支。
    private var workingCopySubtitle: String {
        let count = session.status?.entries.count ?? 0

        guard let branch = session.status?.branch.head else {
            return AppLocalization.text("working.subtitle", count)
        }

        return AppLocalization.text("working.subtitle.branch", branch, count)
    }

    /// 历史的副标题：所选引用以 “, ” 相连，没有选引用时是 “History”，与基准分支比较时是 “分支 → 基准”；后面是提交数，数到上限时写 “or more”。
    private var historySubtitle: String {
        let history = session.history
        var name = history.selectedReferences.isEmpty ? AppLocalization.text("history.title") : history.title

        if let comparison = history.baseComparison {
            name = comparison.branch.name + " → " + comparison.base.name
        }

        guard let count = history.commitCount else {
            return name
        }

        let key = count >= RepositoryHistoryState.maximumLoadedCommits ? "history.subtitle.more" : "history.subtitle"
        return AppLocalization.text(key, name, count)
    }

    /// 文件历史的副标题：“File History – 文件名”。
    private var fileHistorySubtitle: String {
        guard let path = session.fileHistory.path else {
            return AppLocalization.text("fileHistory.title")
        }

        return AppLocalization.text("fileHistory.subtitle", RepositorySession.fileName(path))
    }

    /// 文件原文与 Blame 的副标题：“Blob – 文件名@版本”，跟随 HEAD 时版本写作 HEAD。
    private var fileContentSubtitle: String {
        guard let path = session.fileContent.path else {
            return AppLocalization.text("showFile.blob")
        }

        let revision = session.fileContent.revision.map { String($0.prefix(8)) } ?? "HEAD"

        return AppLocalization.text("showFile.subtitle", RepositorySession.fileName(path), revision)
    }
}
