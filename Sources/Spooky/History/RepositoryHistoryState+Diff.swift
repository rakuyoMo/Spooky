import Foundation
import SpookyKit

// MARK: - Diff

extension RepositoryHistoryState {
    /// 当前提交里一个文件的只读补丁来源，供语法着色与图片对照读取内容；没有选中提交或文件不在变更里时为空。
    func diffSource(path: String) -> CommitFileDiffSource? {
        guard
            let runner,
            let commit = selectedCommit,
            let file = changes.first(where: { $0.path == path })
        else { return nil }

        return CommitFileDiffSource(runner: runner, commit: commit.id, file: file, mergeMode: .preferred)
    }
}
