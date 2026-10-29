import Foundation
import SpookyKit

// MARK: - Search

extension FileHistoryState {
    /// 搜索框输入停顿这么久之后才重新读取。
    private static let searchDelay = Duration.milliseconds(300)

    /// 搜索框内容变化，停顿片刻后按新条件重读。
    func search(_ text: String) {
        searchTask?.cancel()

        guard text != searchText else {
            return
        }

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.searchDelay)
            } catch {
                return
            }

            self?.searchText = text
            self?.reload()
        }
    }

    /// 整个仓库的作者，供搜索框补全；第一次用到时读取，换仓库或 HEAD 移动后重读，读取失败时下次重试。
    func authors() async throws -> [FileContributor] {
        guard let runner, let head else {
            return []
        }

        // 同一仓库与 HEAD 的读取共用一次结果，换文件仍沿用
        if let load = authorsLoad, load.location == runner.location, load.head == head {
            return try await load.task.value
        }

        let task = Task {
            try await RepositoryFileViews(runner: runner).contributors(of: nil, at: head)
        }

        authorsLoad = (runner.location, head, task)

        do {
            return try await task.value
        } catch {
            // 失败的读取不留在缓存里，下次输入时重试
            if authorsLoad?.task == task {
                authorsLoad = nil
            }

            throw error
        }
    }
}
