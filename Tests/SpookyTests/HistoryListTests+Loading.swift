import Foundation
import Testing
import TestSupport

@testable import Spooky

// MARK: - Loading

extension HistoryListTests {
    /// 首屏加载行的三段延迟由注入的等待控制，不看墙钟：
    /// 0.5 s 内读完时不出现；出现后 0.6 s 内读完时再留 0.7 s；显示满 0.6 s 后读完立即收起；取消读取时立即收起。
    @Test("首屏加载行的延迟出现与延迟收起")
    func firstPageLoadingRow() async throws {
        let history = RepositoryHistoryState()
        let sleeper = ManualSleeper()

        history.loadingRowSleep = { try await sleeper.wait($0) }

        defer { sleeper.releaseAll() }

        // 0.5 s 内读完：加载行不出现，计时作废
        history.beginLoadingRow()
        await until { sleeper.durations == [.milliseconds(500)] }

        let quick = history.loadingRowTask
        history.endLoadingRow()
        sleeper.releaseFirst()
        await quick?.value

        #expect(history.loadingRowPhase == .hidden)

        // 出现后 0.6 s 内读完：再留 0.7 s 才收起
        await showLoadingRow(history, sleeper: sleeper)

        let shown = history.loadingRowTask
        history.endLoadingRow()

        #expect(history.loadingRowPhase == .holding)

        sleeper.releaseFirst()
        await shown?.value
        await until { sleeper.durations == [.milliseconds(700)] }

        #expect(history.loadingRowPhase == .holding)

        sleeper.releaseFirst()
        await until { history.loadingRowPhase == .hidden }

        // 显示满 0.6 s 后读完：立即收起
        await showLoadingRow(history, sleeper: sleeper)
        sleeper.releaseFirst()
        await until { history.loadingRowPhase == .shown(settled: true) }

        history.endLoadingRow()

        #expect(history.loadingRowPhase == .hidden)
        #expect(sleeper.durations.isEmpty)

        // 取消读取：立即收起，不再停留
        await showLoadingRow(history, sleeper: sleeper)
        history.cancelPage()

        #expect(history.loadingRowPhase == .hidden)
    }
}

// MARK: - Steps

extension HistoryListTests {
    /// 开始首屏读取并放过 0.5 s 的等待，直到加载行出现、0.6 s 的等待已登记。
    private func showLoadingRow(_ history: RepositoryHistoryState, sleeper: ManualSleeper) async {
        history.beginLoadingRow()
        await until { sleeper.durations == [.milliseconds(500)] }

        sleeper.releaseFirst()
        await until { history.loadingRowPhase == .shown(settled: false) && sleeper.durations == [.milliseconds(600)] }
    }
}

// MARK: - ManualSleeper

/// 由测试放行的等待：每次等待都登记时长并挂起，测试按登记的先后放行。
@MainActor
private final class ManualSleeper {
    /// 挂起中的等待，按登记的先后。
    private var waiting: [(duration: Duration, continuation: CheckedContinuation<Void, Never>)] = []

    /// 挂起中的等待的时长。
    var durations: [Duration] {
        waiting.map(\.duration)
    }

    /// 登记一次等待并挂起到测试放行。
    ///
    /// - Parameter duration: 调用方要等的时长。
    func wait(_ duration: Duration) async {
        await withCheckedContinuation { waiting.append((duration, $0)) }
    }

    /// 放行最早登记的等待。
    func releaseFirst() {
        guard !waiting.isEmpty else {
            return
        }

        waiting.removeFirst().continuation.resume()
    }

    /// 放行全部等待。
    func releaseAll() {
        while !waiting.isEmpty {
            releaseFirst()
        }
    }
}
