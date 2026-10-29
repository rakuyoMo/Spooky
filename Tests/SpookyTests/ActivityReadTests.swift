import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ActivityReadTests

/// Repository 页的读取记录：结束时才插入的记录、各类清单的增减计数，以及会话里哪些刷新记录读取。
///
/// 每个测试使用自己的 `RepositoryActivities` 实例，不碰共享的活动列表。
@MainActor
struct ActivityReadTests {
    /// 读取成功、取消与失败各记一条已结束的记录；开始时刻是读取开始的时刻；读取本身的结果与错误照常交给调用方。
    @Test("读取结束时记进 Repository 页")
    func readRecords() async throws {
        let location = RepositoryLocation.local(path: "/temporary/读取 [1]-" + UUID().uuidString)
        let activities = RepositoryActivities()
        let before = Date()

        // 成功：一行结果同时是日志，没有取消入口；读取的结果原样返回
        let value = try await activities.recordRead(["Load"], in: location, results: { (count: Int) in ["Loaded \(count)"] }) {
            try await Task.sleep(for: .milliseconds(50))

            return 3
        }

        let finished = try #require(activities.items.first)
        #expect(value == 3)
        #expect(finished.kind == .repository && finished.repository == location && finished.title == "Load")
        #expect(finished.state == "activity.finished" && finished.cancel == nil)
        #expect(finished.result == "Loaded 3" && finished.log == "Loaded 3")
        #expect(finished.started >= before)
        #expect((finished.elapsed ?? 0) >= 0.05)

        // 一次读取按标题各记一条，结果按位置对应，缺的一条没有结果，状态照旧写在行上
        _ = try await activities.recordRead(["A", "B", "C"], in: location, results: { _ in ["1", nil] }) { 0 }
        #expect(activities.items.prefix(3).map(\.title) == ["C", "B", "A"])
        #expect(activities.items.prefix(3).map(\.result) == [nil, nil, "1"])

        // 失败：日志是错误说明，错误照常抛出
        let error = RepositoryReadError.invalidQuery

        await #expect(throws: RepositoryReadError.self) {
            try await activities.recordRead(["Load"], in: location) { () throws -> Int in
                throw error
            }
        }

        let failed = try #require(activities.items.first)
        #expect(failed.state == "activity.failed" && failed.result == nil)
        #expect(failed.log == AppFailure(error: error, opening: false, location: location).details)

        // 取消：没有结果，日志为空
        let cancelled = Task {
            try await activities.recordRead(["Load"], in: location) {
                try await Task.sleep(for: .seconds(60))
            }
        }

        cancelled.cancel()
        _ = await cancelled.result

        #expect(activities.items.first?.state == "activity.cancelled")
        #expect(activities.items.first?.log.isEmpty ?? false)

        // 读取完成时任务已被取消、结果不再使用的，同样记为取消，结果仍交给调用方
        let superseded = Task {
            try await activities.recordRead(["Load"], in: location, results: { (count: Int) in ["Loaded \(count)"] }) {
                try? await Task.sleep(for: .seconds(60))

                return 5
            }
        }

        superseded.cancel()
        #expect(try await superseded.value == 5)
        #expect(activities.items.first?.state == "activity.cancelled")
        #expect(activities.items.first?.result == nil)

        // 不记录时只执行读取
        let count = activities.items.count
        #expect(try await activities.recordRead(["Load"], in: location, records: false) { 7 } == 7)
        #expect(activities.items.count == count)
    }

    /// 没有基准时全算新增；之后新增、删除与比较值变化分别计数；各仓库、各类的基准分开。
    @Test("增减计数与基准")
    func changeCounts() {
        let location = RepositoryLocation.local(path: "/temporary/计数-" + UUID().uuidString)
        let other = RepositoryLocation.remote(host: "spooky-test", path: "/Users/wgy/spooky-test/计数")
        let activities = RepositoryActivities()

        #expect(activities.changes(of: .branches, items: ["a": "1", "b": "1"], in: location) == changes(0, 2, 0))
        #expect(activities.changes(of: .branches, items: ["a": "2", "c": "1"], in: location) == changes(1, 1, 1))
        #expect(activities.changes(of: .branches, items: ["a": "2", "c": "1"], in: location) == changes(0, 0, 0))

        // 别的类与别的仓库还没有基准
        #expect(activities.changes(of: .stashes, items: ["a": "2"], in: location) == changes(0, 1, 0))
        #expect(activities.changes(of: .branches, items: ["a": "2"], in: other) == changes(0, 1, 0))
    }

    /// 本地分支只算本地的：顶端、上游与领先落后数变了算更新；远端分支的移动与远端设置的变化算在远端上。
    @Test("分支与远端的清单")
    func referenceInventories() {
        let main = reference("refs/heads/main", "1", upstream: "refs/remotes/origin/main")
        let tracking = reference("refs/remotes/origin/main", "1")
        let head = reference("refs/remotes/origin/HEAD", "1", symbolicTarget: "refs/remotes/origin/main")
        let remotes = [RepositoryRemote(name: "origin")]
        let snapshot = ReferenceSnapshot(
            references: [head, tracking, main],
            remotes: remotes,
            remoteSettingsDigests: ["origin": "url"]
        )

        let branches = ActivityInventory.branches(in: snapshot, divergence: [:])
        let origin = ActivityInventory.remotes(in: snapshot)
        #expect(Array(branches.keys) == ["refs/heads/main"])
        #expect(Array(origin.keys) == ["origin"])

        // 领先落后数变了，分支算更新
        let behind = ["refs/heads/main": ReferenceDivergence(ahead: 0, behind: 1)]
        #expect(ActivityInventory.branches(in: snapshot, divergence: behind) != branches)

        // 远端分支移动：分支的清单不变，远端的变了
        let moved = ReferenceSnapshot(
            references: [head, reference("refs/remotes/origin/main", "2"), main],
            remotes: remotes,
            remoteSettingsDigests: ["origin": "url"]
        )

        #expect(ActivityInventory.branches(in: moved, divergence: [:]) == branches)
        #expect(ActivityInventory.remotes(in: moved) != origin)

        // 远端的设置变了
        let changed = ReferenceSnapshot(
            references: [head, tracking, main],
            remotes: remotes,
            remoteSettingsDigests: ["origin": "other"]
        )

        #expect(ActivityInventory.remotes(in: changed) != origin)
    }

    /// 储藏按提交对齐，序号变了算更新；子模块检出别的提交、工作区里有改动或地址变了都算更新。
    @Test("储藏与子模块的清单")
    func stashAndSubmoduleInventories() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = StashEntry(index: 0, id: "a", parents: ["p"], date: date, subject: "On main: one")
        let second = StashEntry(index: 1, id: "a", parents: ["p"], date: date, subject: "On main: one")

        #expect(Array(ActivityInventory.stashes([first]).keys) == ["a"])
        #expect(ActivityInventory.stashes([first]) != ActivityInventory.stashes([second]))

        let clean = submodule(checkedOut: "1", state: .clean)
        let summary = SubmoduleSummary(changes: 0, ahead: 0, behind: 0)
        let items = ActivityInventory.submodules([clean], summaries: ["lib": summary])
        #expect(Array(items.keys) == ["lib"])
        #expect(ActivityInventory.submodules([clean], summaries: ["lib": summary]) == items)

        // 检出别的提交
        let checkedOut = submodule(checkedOut: "2", state: .updated)
        #expect(ActivityInventory.submodules([checkedOut], summaries: ["lib": summary]) != items)

        // 子模块工作区里有改动
        let dirty = SubmoduleSummary(changes: 1, ahead: 0, behind: 0)
        #expect(ActivityInventory.submodules([clean], summaries: ["lib": dirty]) != items)

        // 地址变了
        let moved = submodule(checkedOut: "1", state: .clean, url: "https://example.com/moved.git")
        #expect(ActivityInventory.submodules([moved], summaries: ["lib": summary]) != items)
    }

    /// 写成 “x updated, y added, z deleted” 的一行结果。
    func changes(_ updated: Int, _ added: Int, _ deleted: Int) -> String {
        AppLocalization.text("activity.result.changes", updated, added, deleted)
    }

    /// 一条指向提交的引用。
    private func reference(
        _ id: String,
        _ objectID: String,
        upstream: String? = nil,
        symbolicTarget: String? = nil
    ) -> RepositoryReference {
        RepositoryReference(
            id: id,
            objectID: objectID,
            objectType: "commit",
            upstream: upstream,
            upstreamRemote: nil,
            upstreamBranch: nil,
            symbolicTarget: symbolicTarget
        )
    }

    /// 路径为 `lib` 的子模块。
    private func submodule(
        checkedOut: String,
        state: SubmoduleState,
        url: String = "https://example.com/lib.git"
    ) -> Submodule {
        Submodule(
            name: "lib",
            path: "lib",
            shared: SubmoduleSettings(path: "lib", url: url),
            local: nil,
            pointer: "1",
            checkedOut: checkedOut,
            state: state,
            problem: nil,
            needsSynchronizing: false
        )
    }
}
