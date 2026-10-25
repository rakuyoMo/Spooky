import AppKit
import Observation
import SpookyKit

// MARK: - RepositoryManagerController

/// 一个窗口里的仓库管理：侧边栏选中的书签、详情区读取的仓库概况，以及书签的打开、添加、删除与整理。
///
/// 侧边栏与详情区共用一份；窗口每次进入仓库管理时新建。
@MainActor
@Observable
final class RepositoryManagerController {
    /// 详情区显示的内容。
    enum Content: Equatable {
        /// 没有选中、或选中一个文件夹：拖放页。
        case dropZone

        /// 选中一个仓库。
        case repository(Bookmark)

        /// 选中多项。
        case multiple(Int)
    }

    /// 详情区读取仓库概况的状态。
    enum DetailState {
        /// 正在连接或读取。
        case loading

        /// 读取完成。
        case loaded(RepositorySummary)

        /// 仓库所在的路径不存在，或那里已不是 Git 仓库。
        case missing

        /// 连不上服务器或其它读取失败，带原文。
        case failed(AppFailure)
    }

    /// 跨窗口共享的书签。
    let bookmarks: RepositoryBookmarks

    /// 所在窗口的会话：菜单与工具栏经它取得选中的仓库，打开中的状态也在这里。
    let session: RepositorySession

    /// 侧边栏选中的书签，按列表顺序排列。
    var selection: [Bookmark.ID] = [] {
        didSet {
            guard selection != oldValue else {
                return
            }

            session.selectedRecentLocation = selectedRepository?.location
            updateDetail()
        }
    }

    /// 等侧边栏开始原地改名的书签；侧边栏开始编辑后清空。
    var renameRequest: Bookmark.ID? = nil

    /// 详情区正在显示的仓库位置。
    private(set) var detailLocation: RepositoryLocation? = nil

    /// 详情区的读取状态。
    private(set) var detailState: DetailState? = nil

    /// 发起打开与呈现 sheet 的窗口。
    @ObservationIgnored
    weak var window: RepositoryWindowController?

    /// 打开仓库、添加书签与回收连接的应用协调器。
    @ObservationIgnored
    weak var coordinator: SpookyApplicationController?

    /// 详情区的读取任务。
    @ObservationIgnored
    private var detailTask: Task<Void, Never>? = nil

    /// 创建窗口的仓库管理状态；选择沿用会话里上次选中的仓库。
    ///
    /// - Parameters:
    ///   - bookmarks: 跨窗口共享的书签。
    ///   - session: 所在窗口的会话。
    init(bookmarks: RepositoryBookmarks, session: RepositorySession) {
        self.bookmarks = bookmarks
        self.session = session

        if let location = session.selectedRecentLocation, let bookmark = bookmarks.bookmark(for: location) {
            selection = [bookmark.id]
            updateDetail()
        }
    }

    /// 离开仓库管理时停止读取，并交还详情区为服务器仓库建立的连接。
    isolated deinit {
        detailTask?.cancel()

        if let detailLocation {
            coordinator?.releaseConnection(detailLocation)
        }
    }
}

// MARK: - Selection

extension RepositoryManagerController {
    /// 选中的书签，已删除的不算。
    var selectedBookmarks: [Bookmark] {
        selection.compactMap(bookmarks.bookmark)
    }

    /// 只选中一个仓库时的那个书签。
    var selectedRepository: Bookmark? {
        let selected = selectedBookmarks
        return selected.count == 1 && !selected[0].isFolder ? selected[0] : nil
    }

    /// 只选中一个文件夹时的那个文件夹；添加的仓库放进它里面。
    var selectedFolder: Bookmark.ID? {
        let selected = selectedBookmarks
        return selected.count == 1 && selected[0].isFolder ? selected[0].id : nil
    }

    /// 详情区按选中的数量与种类切换。
    var content: Content {
        let selected = selectedBookmarks

        switch selected.count {
        case 0:
            return .dropZone

        case 1:
            return selected[0].isFolder ? .dropZone : .repository(selected[0])

        default:
            return .multiple(selected.count)
        }
    }
}

// MARK: - Detail

extension RepositoryManagerController {
    /// 与打开仓库相同的检查：本机先确认 Git 版本与工作区，服务器先接入回调再完成连接体检。
    static func openedRunner(for location: RepositoryLocation) async throws -> GitRunner {
        let runner = GitRunner(location: location)

        if let remote = runner.remote {
            await remote.setCallbackHandler { request in
                await RemoteCallbackPresenter.shared.respond(to: request)
            }

            _ = try await remote.open()
        } else {
            _ = try await runner.openLocalRepository()
        }

        return runner
    }

    /// 失败是否说明仓库已不在原处：本机路径不存在或不再是仓库，服务器上的路径不存在或不是工作区。
    static func isMissing(_ location: RepositoryLocation, error: any Error) -> Bool {
        if let remote = error as? RemoteConnectionError {
            return [.pathUnavailable, .notWorkingTree].contains(remote.kind)
        }

        if location.host == nil, !FileManager.default.fileExists(atPath: location.path) {
            return true
        }

        if let git = error as? GitError {
            return [.pathUnavailable, .notRepository].contains(git.category)
        }

        return false
    }

    /// 选中的仓库变了才重新读取；服务器仓库只在这时经它的主连接读取，读完前一个服务器仓库的连接交还。
    func updateDetail() {
        let location = selectedRepository?.location

        guard location != detailLocation else {
            return
        }

        detailTask?.cancel()
        detailTask = nil

        if let previous = detailLocation {
            coordinator?.releaseConnection(previous)
        }

        detailLocation = location
        detailState = nil

        if location != nil {
            reloadDetail()
        }
    }

    /// 重新读取详情区的仓库概况；写入描述或身份后同样调用。
    func reloadDetail() {
        guard let location = detailLocation else {
            return
        }

        detailTask?.cancel()

        // 已有结果时保留显示，读完再替换，避免写入后整块闪烁
        if case .loaded = detailState {} else {
            detailState = .loading
        }

        detailTask = Task { [weak self] in
            do {
                let runner = try await Self.openedRunner(for: location)
                let summary = try await runner.repositorySummary()

                guard !Task.isCancelled, let self, detailLocation == location else {
                    return
                }

                detailState = .loaded(summary)
                bookmarks.markAvailable(location)
            } catch {
                guard !Task.isCancelled, let self, detailLocation == location else {
                    return
                }

                let missing = Self.isMissing(location, error: error)
                detailState = missing ? .missing : .failed(AppFailure(error: error, opening: true, location: location))
                bookmarks.markMissing(location)
            }
        }
    }
}
