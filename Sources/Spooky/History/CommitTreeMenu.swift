import SpookyKit
import SwiftUI

// MARK: - CommitTreeMenu

/// 文件树条目的右键菜单：查看组只对单个文件提供，恢复、导出与归档对单个或多个条目都可用。
struct CommitTreeMenu: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 条目所在的提交。
    let commit: HistoryCommit

    /// 所选条目，按列表顺序排列。
    let entries: [TreeEntry]

    /// 单个条目与多个条目各一套文案。
    var body: some View {
        if entries.count == 1, let entry = entries.first {
            single(entry)
        } else if !entries.isEmpty {
            multiple
        }
    }

    /// 多个条目：恢复、导出与归档。
    @ViewBuilder
    private var multiple: some View {
        let paths = entries.map(\.path)

        Button(AppLocalization.text("tree.restoreItems", entries.count, commit.shortID)) {
            session.restoreItems(paths, at: commit.id)
        }
        .disabled(!session.canWrite)

        Button(AppLocalization.text("tree.exportItems", entries.count, commit.shortID)) {
            session.onRevisionRequest?(.export(revision: commit.id, paths: paths, archive: false))
        }

        Button(AppLocalization.text("tree.archiveItems", entries.count, commit.shortID)) {
            session.onRevisionRequest?(.export(revision: commit.id, paths: paths, archive: true))
        }
    }

    /// 单个条目：原文、Blame 与文件历史只对文件可用；导出单个文件直接存成文件。
    @ViewBuilder
    private func single(_ entry: TreeEntry) -> some View {
        let name = RepositorySession.fileName(entry.path)
        let file = entry.type == "blob"

        Button(AppLocalization.text("fileHistory.showAt", name, commit.shortID)) {
            session.showFile(entry.path, at: commit.id, mode: .raw)
        }
        .disabled(!file)

        Button(AppLocalization.text("fileHistory.blameAt", name, commit.shortID)) {
            session.showFile(entry.path, at: commit.id, mode: .blame)
        }
        .disabled(!file)

        Button(AppLocalization.text("fileHistory.showHistoryOf", name)) {
            session.showFileHistory(entry.path)
        }
        .disabled(!file)

        Divider()

        Button(AppLocalization.text("fileHistory.restoreInWorkingCopy", name, commit.shortID)) {
            session.restoreItems([entry.path], at: commit.id)
        }
        .disabled(!session.canWrite)

        Button(AppLocalization.text("fileHistory.exportAt", name, commit.shortID)) {
            if file {
                session.exportFile(entry.path, at: commit.id)
            } else {
                session.onRevisionRequest?(.export(revision: commit.id, paths: [entry.path], archive: false))
            }
        }

        Button(AppLocalization.text("tree.archiveAt", name, commit.shortID)) {
            session.onRevisionRequest?(.export(revision: commit.id, paths: [entry.path], archive: true))
        }
    }
}
