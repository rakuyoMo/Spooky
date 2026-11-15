import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - StashSelectionTests

/// 储藏列表重读后的选择与自动储藏的默认说明。
@MainActor
struct StashSelectionTests {
    /// 进入时选中第一个；删除选中的储藏后选中原位置上的那一项，删的是最后一个时选新的最后一个；仍在的选择保留。
    @Test("储藏列表重读后的选择")
    func selection() {
        let entries = ["a", "b", "c"].enumerated().map { index, id in
            StashEntry(index: index, id: id, parents: ["base", "index"], date: .now, subject: "On main: " + id)
        }

        let select = { (selected: Set<String>, current: [StashEntry]) in
            RepositoryStashState.selection(after: selected, previous: entries, current: current)
        }

        // 进入视图时没有选择
        #expect(select([], entries) == ["a"])

        // 删掉中间与最后一个
        #expect(select(["b"], [entries[0], entries[2]]) == ["c"])
        #expect(select(["c"], [entries[0], entries[1]]) == ["b"])

        // 仍在的选择保留，全部删光时没有选择
        #expect(select(["a", "c"], [entries[0], entries[1]]) == ["a"])
        #expect(select(["a"], []).isEmpty)
    }

    /// 默认说明是产品名加 “年-月-日 时:分:秒 时区偏移” 的保存时刻。
    @Test("自动储藏的默认说明")
    func autoStashMessage() throws {
        let timeZone = try #require(TimeZone(secondsFromGMT: -8 * 3600))
        let date = Date(timeIntervalSince1970: 1_794_631_697)

        #expect(
            RepositoryStashState.autoStashMessage(at: date, timeZone: timeZone)
                == AppLocalization.text("stash.autoStash.message", "2026-11-13 20:48:17 -0800")
        )
    }
}
