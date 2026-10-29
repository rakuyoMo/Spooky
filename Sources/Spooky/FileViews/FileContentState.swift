import Foundation
import Observation
import SpookyKit

// MARK: - FileContentMode

/// 文件原文与 Blame 共用一个整页视图，分段控件在两者之间切换。
enum FileContentMode: Hashable {
    /// 带行号的原文。
    case raw

    /// 逐行追溯到引入它的提交。
    case blame
}

// MARK: - FileContentState

/// 某个版本的文件原文、逐行追溯与贡献者；默认跟随当前 HEAD，过期请求不能覆盖新的结果。
@MainActor
@Observable
final class FileContentState {
    /// 当前查看的文件，使用树中存储的形式；没有打开文件时为 nil。
    private(set) var path: String? = nil

    /// 选定版本的完整哈希；nil 表示跟随当前 HEAD。
    private(set) var revision: String? = nil

    /// 显示原文还是逐行追溯。
    var mode = FileContentMode.raw {
        didSet {
            if mode != oldValue { load() }
        }
    }

    /// 已读取的原文。
    private(set) var content: FileRevisionContent? = nil

    /// 逐行追溯的结果，只在 Blame 模式下读取。
    private(set) var blame: FileBlame? = nil

    /// 逐行追溯各行的显示形式，与行号一一对应。
    private(set) var blameLines: [String] = []

    /// 修改过这个文件的作者，读取完成前为 nil。
    private(set) var contributors: [FileContributor]? = nil

    /// 是否正在读取。
    private(set) var isLoading = false

    /// 读取失败的可复制诊断；失败时不显示空文件。
    private(set) var failure: AppFailure? = nil

    /// 单击注释后一起高亮的提交。
    var highlightedCommit: String? = nil

    /// 当前 HEAD；仓库还没有提交时为 nil。
    private(set) var head: String? = nil

    /// 当前仓库的执行器。
    private var runner: GitRunner? = nil

    /// 换文件、换版本或关闭时变更代数，阻止旧结果回写。
    private var generation = 0

    /// 当前的读取任务。
    private var task: Task<Void, Never>? = nil

    /// 原文与逐行追溯的读取记进的 Activity 列表，由会话设成它自己的列表。
    @ObservationIgnored
    var activities = RepositoryActivities.shared

    /// 实际读取的提交：选定的版本或当前 HEAD。
    var resolvedRevision: String? { revision ?? head }

    /// 打开一个文件的某个版本。
    ///
    /// - Parameters:
    ///   - revision: 提交的完整哈希；nil 表示跟随当前 HEAD。
    ///   - head: 当前 HEAD，仓库还没有提交时为 nil。
    func open(_ path: String, revision: String?, mode: FileContentMode, head: String?, runner: GitRunner) {
        close()
        self.runner = runner
        self.head = head
        self.revision = revision

        // 路径为空时切换模式不会触发读取，读取只在最后发起一次
        self.mode = mode
        self.path = path
        load()
    }

    /// 版本选择器换到另一个版本；nil 回到跟随 HEAD。
    func select(revision: String?) {
        guard revision != self.revision else {
            return
        }

        self.revision = revision
        load()
    }

    /// 文件选择器换到同一版本里的另一个文件。
    func select(path: String) {
        guard path != self.path else {
            return
        }

        self.path = path
        load()
    }

    /// 刷新后的 HEAD 变化时，跟随 HEAD 的视图重读。
    ///
    /// - Parameter records: 重读是否记进 Activity，与引起它的刷新相同。
    func update(head: String?, records: Bool = true) {
        guard path != nil, head != self.head else {
            return
        }

        self.head = head

        if revision == nil {
            load(records: records)
        }
    }

    /// 读取原文、贡献者，以及 Blame 模式下的逐行追溯。
    ///
    /// - Parameter records: 原文与逐行追溯是否记进 Activity；自动刷新引起的重读不记。
    func load(records: Bool = true) {
        task?.cancel()
        generation += 1
        failure = nil
        blame = nil
        blameLines = []
        content = nil
        highlightedCommit = nil
        isLoading = false

        guard let path, let runner else {
            return
        }

        // 仓库还没有提交时没有可读取的版本
        guard let revision = resolvedRevision else {
            content = FileRevisionContent(path: path, data: nil, unavailable: .missing, lines: [])
            contributors = []
            return
        }

        let request = generation
        let mode = mode
        let activities = activities
        isLoading = true

        task = Task { [weak self] in
            do {
                let result = try await Self.read(
                    path,
                    at: revision,
                    mode: mode,
                    runner: runner,
                    activities: activities,
                    records: records
                )

                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                self.path = result.content.path
                content = result.content
                blame = result.blame
                blameLines = result.blame?.lines.map(FileRevisionContent.displayLine) ?? []
                contributors = result.contributors
            } catch {
                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                failure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, generation == request, !Task.isCancelled else {
                return
            }

            isLoading = false
        }
    }

    /// 关闭视图，清除全部结果。
    func close() {
        task?.cancel()
        task = nil
        generation += 1
        path = nil
        revision = nil
        head = nil
        runner = nil
        content = nil
        blame = nil
        blameLines = []
        contributors = nil
        isLoading = false
        failure = nil
        highlightedCommit = nil
    }
}

// MARK: - Private

extension FileContentState {
    /// 读取原文、贡献者，以及 Blame 模式下的逐行追溯；原文记为 Load Blob，逐行追溯记为 Load Blame，贡献者不记。
    ///
    /// - Parameters:
    ///   - revision: 读取的提交。
    ///   - mode: Blame 模式下才读逐行追溯。
    ///   - activities: 读取记进的 Activity 列表。
    ///   - records: 是否记进 Activity。
    /// - Returns: 原文、逐行追溯与修改过这个文件的作者。
    private static func read(
        _ path: String,
        at revision: String,
        mode: FileContentMode,
        runner: GitRunner,
        activities: RepositoryActivities,
        records: Bool
    ) async throws -> (content: FileRevisionContent, blame: FileBlame?, contributors: [FileContributor]) {
        let views = RepositoryFileViews(runner: runner)

        let content = try await activities.recordRead(
            [AppLocalization.text("activity.read.blob")],
            in: runner.location,
            records: records
        ) {
            try await FileRevisionContent.load(path, at: revision, views: views)
        }

        // 贡献者与逐行追溯互不依赖，服务器上只占一次往返的等待时间
        async let contributors = views.contributors(of: content.path, at: revision)
        var blame: FileBlame? = nil

        if mode == .blame, content.unavailable == nil {
            blame = try await activities.recordRead(
                [AppLocalization.text("activity.read.blame")],
                in: runner.location,
                records: records
            ) {
                try await views.blame(content.path, at: revision)
            }
        }

        return (content, blame, try await contributors)
    }
}
