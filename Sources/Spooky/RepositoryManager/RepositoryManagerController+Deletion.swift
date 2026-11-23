import AppKit
import SpookyKit
import SwiftUI

// MARK: - Deletion

extension RepositoryManagerController {
    /// 没能移进废纸篓的一个仓库与原因。
    typealias TrashFailure = (location: RepositoryLocation, reason: String)

    /// 要删的书签里可以移进废纸篓的仓库：文件夹按里面各层的书签展开，取服务器仓库与目录还在的本机仓库，同一位置只算一次。
    static func repositoryFolders(in targets: [Bookmark]) -> [RepositoryLocation] {
        var seen = Set<RepositoryLocation>()

        return targets.repositories
            .filter { !$0.isLocalDirectoryGone }
            .compactMap(\.location)
            .filter { seen.insert($0).inserted }
    }

    /// 没能移进废纸篓的说明：骨架的提示版，只有 Close；说明下面空一行，逐行写出仓库与原因。
    /// 本机仓库的家目录缩写成 `~`，服务器仓库写带主机前缀的位置。
    ///
    /// - Parameters:
    ///   - failures: 没能移走的仓库与原因，按处理的先后排列。
    ///   - close: 关掉提示。
    static func trashFailureNotice(
        _ failures: [TrashFailure],
        close: @escaping () -> Void
    ) -> DialogLayout<EmptyView, EmptyView> {
        let lines = failures.map { failure in
            let location = failure.location.host == nil
                ? HomePath.abbreviated(failure.location.path)
                : failure.location.displayPath

            return location + " — " + failure.reason
        }

        return DialogLayout(
            title: AppLocalization.text("bookmarks.trashFailed.title"),
            message: AppLocalization.text("bookmarks.trashFailed.message") + "\n\n" + lines.joined(separator: "\n"),
            submitTitle: AppLocalization.text("action.close"),
            cancel: nil,
            submit: close
        )
    }

    /// 删除书签：要删的书签里（文件夹按里面各层的书签算）有服务器仓库或目录还在的本机仓库时询问；
    /// 只剩空文件夹与目录已不存在的本机仓库时不询问，直接删除。
    func confirmDelete(_ ids: [Bookmark.ID]) {
        let targets = ids.compactMap(bookmarks.bookmark)

        guard !targets.isEmpty else {
            return
        }

        guard !Self.repositoryFolders(in: targets).isEmpty else {
            delete(targets)
            return
        }

        window?.presentDialog { close in
            deleteBookmarksPrompt(targets, close: close)
        }
    }

    /// 删除书签的询问：标题按个数取写法，说明按有没有服务器仓库取写法，下面是每次都不勾的移到废纸篓勾选框，主按钮是 Delete。
    /// 确认后删除书签并从选中里去掉；勾上时再在后台把仓库文件夹移进废纸篓。
    ///
    /// 目录已不存在的服务器仓库没有文件夹可移，不算进勾选框的个数；要问的都是这样的仓库时勾选框置灰。
    ///
    /// - Parameters:
    ///   - targets: 要删除的书签。
    ///   - close: 关闭询问。
    func deleteBookmarksPrompt(_ targets: [Bookmark], close: @escaping () -> Void) -> ConfirmationDialog {
        let folders = Self.repositoryFolders(in: targets)
        let movable = folders.filter { !bookmarks.isDirectoryGone($0) }

        let message = folders.contains { $0.host != nil }
            ? AppLocalization.text("bookmarks.delete.noteServer")
            : AppLocalization.text("bookmarks.delete.note")

        // 置灰时照旧按全部仓库写个数
        let count = movable.isEmpty ? folders.count : movable.count

        let checkbox = count == 1
            ? AppLocalization.text("bookmarks.delete.trash")
            : AppLocalization.text("bookmarks.delete.trashMultiple", count)

        return ConfirmationDialog(
            title: targets.count == 1
                ? AppLocalization.text("bookmarks.delete.title", targets[0].displayName)
                : AppLocalization.text("bookmarks.delete.titleMultiple", targets.count),
            message: message,
            submitTitle: AppLocalization.text("bookmarks.delete.submit"),
            checkbox: checkbox,
            isCheckboxEnabled: !movable.isEmpty,
            close: close
        ) { [weak self] checked in
            self?.delete(targets)

            if checked {
                self?.moveToTrash(movable)
            }
        }
    }
}

// MARK: - Private

extension RepositoryManagerController {
    /// 删除书签，并从选中里去掉。
    private func delete(_ targets: [Bookmark]) {
        bookmarks.delete(targets.map(\.id))
        selection.removeAll { bookmarks.bookmark($0) == nil }
    }

    /// 在后台把仓库文件夹逐个移进废纸篓；全部处理完后，有没移走的弹出错误框逐行列出。
    ///
    /// 克隆中的仓库先停止克隆、等它结束，再移走还在的目录；为移动而建立的服务器连接，没有窗口在用时交还。
    private func moveToTrash(_ locations: [RepositoryLocation]) {
        let trash = folderTrash
        let clones = coordinator?.clones

        trashTask = Task { [weak window, weak coordinator] in
            var failures: [TrashFailure] = []

            for location in locations {
                await clones?.unfinished(at: location)?.stop()

                if let reason = await trash.move(location) {
                    failures.append((location, reason))
                }

                coordinator?.releaseConnection(location)
            }

            if !failures.isEmpty, let sheetParent = window?.window {
                DialogWindow.present(on: sheetParent) { close in
                    Self.trashFailureNotice(failures, close: close)
                }
            }

            return failures
        }
    }
}
