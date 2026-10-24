import AppKit

// MARK: - Subtitle

extension RepositoryWindowController {
    /// 仓库视图的窗口副标题：储藏视图显示储藏的数量，其余视图显示仓库路径。
    var repositorySubtitle: String {
        switch session.activeView {
        case .stashes:
            AppLocalization.text("stash.subtitle", session.stashes.entries.count)

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
