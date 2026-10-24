import Foundation
import SpookyKit

// MARK: - History Operations

extension RepositorySession {
    /// 历史正在显示 HEAD 所在的分支：侧边栏单选了当前分支，或分离、未出生时的 HEAD 行。
    ///
    /// 改写历史的入口只在这时可用：右键菜单的反转与交互式变基各项、多选的 Revert、详情的 Rollback 与 Revert、列表内拖放。
    var isViewingHead: Bool {
        guard let reference = history.selectedReference else {
            return false
        }

        if reference == "HEAD" {
            return true
        }

        return status?.branch.head.map { reference == "refs/heads/" + $0 } ?? false
    }

    /// 只把提交里一个文件的改动套用到工作区，不改暂存区；套用不上时整体失败，工作区保持不变。
    ///
    /// - Returns: 是否已开始执行。
    @discardableResult
    func cherryPickFile(_ change: CommitFileChange, from commit: HistoryCommit) -> Bool {
        let path = change.path
        let originalPath = change.originalPath
        let id = commit.id

        return performGit(
            { runner, _ in
                try await RepositoryRewrite(runner: runner).cherryPick(path: path, originalPath: originalPath, from: id)
            },
            title: AppLocalization.text("files.applyPatch")
        )
    }
}
