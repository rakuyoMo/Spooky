import AppKit

// MARK: - Subtitle

extension RepositoryWindowController {
    /// 仓库视图的窗口副标题：储藏视图显示储藏的数量，文件历史与文件原文写出所看的文件，其余视图显示仓库路径。
    var repositorySubtitle: String {
        switch session.activeView {
        case .stashes:
            AppLocalization.text("stash.subtitle", session.stashes.entries.count)

        case .fileHistory:
            fileHistorySubtitle

        case .fileContent:
            fileContentSubtitle

        default:
            session.repository?.displayPath ?? ""
        }
    }

    /// 按当前视图写入副标题；仓库管理显示期间副标题为空。
    func updateSubtitle() {
        window?.subtitle = showsManager ? "" : repositorySubtitle
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
