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
    func update(head: String?) {
        guard path != nil, head != self.head else {
            return
        }

        self.head = head

        if revision == nil {
            load()
        }
    }

    /// 读取原文、贡献者，以及 Blame 模式下的逐行追溯。
    func load() {
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
        isLoading = true

        task = Task { [weak self] in
            do {
                let views = RepositoryFileViews(runner: runner)
                let content = try await FileRevisionContent.load(path, at: revision, views: views)

                // 贡献者与逐行追溯互不依赖，服务器上只占一次往返的等待时间
                async let contributors = views.contributors(of: content.path, at: revision)
                let blame = mode == .blame && content.unavailable == nil
                    ? try await views.blame(content.path, at: revision)
                    : nil
                let people = try await contributors

                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                self.path = content.path
                self.content = content
                self.blame = blame
                blameLines = blame?.lines.map(FileRevisionContent.displayLine) ?? []
                self.contributors = people
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
