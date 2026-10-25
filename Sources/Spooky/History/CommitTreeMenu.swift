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

    /// 多个条目：打开其中的文件，恢复、导出与归档。
    @ViewBuilder
    private var multiple: some View {
        let paths = entries.map(\.path)
        let files = entries.filter { $0.type == "blob" }.map(\.path)

        Button(AppLocalization.text("tree.openItemsAt", entries.count, commit.shortID)) {
            session.open(files, at: commit.id)
        }
        .disabled(files.count != entries.count)

        openWithMenu(AppLocalization.text("tree.openItemsAtWith", entries.count, commit.shortID), files: files)
            .disabled(files.count != entries.count)

        Divider()

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

    /// 单个条目：打开、原文、Blame 与文件历史只对文件可用；导出单个文件直接存成文件。
    @ViewBuilder
    private func single(_ entry: TreeEntry) -> some View {
        let name = RepositorySession.fileName(entry.path)
        let file = entry.type == "blob"

        Button(AppLocalization.text("tree.openAt", name, commit.shortID)) {
            session.open([entry.path], at: commit.id)
        }
        .disabled(!file)

        openWithMenu(AppLocalization.text("tree.openAtWith", name, commit.shortID), files: [entry.path])
            .disabled(!file)

        Divider()

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

    /// 用指定程序打开这个版本里的文件的子菜单：程序按文件名判断，最后是 Other…。
    private func openWithMenu(_ title: String, files: [String]) -> some View {
        Menu(title) {
            OpenWithMenuItems(
                names: files,
                open: { session.open(files, at: commit.id, with: $0) },
                other: { session.openWithOtherApplication(files, at: commit.id) }
            )
        }
    }
}
