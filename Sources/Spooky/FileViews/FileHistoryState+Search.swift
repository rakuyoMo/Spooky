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
}
