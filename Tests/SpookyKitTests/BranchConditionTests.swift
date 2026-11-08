import Foundation
import Testing

@testable import SpookyKit

// MARK: - BranchConditionTests

/// 分支的陈旧、跟踪错误与基准只看结构化结果：提交时间、上游引用是否还在与基准名单。
struct BranchConditionTests {
    /// 基准分支、按父分支认作基准的分支与上游已删除的分支各得到对应的状态；
    /// 分离 HEAD 与未出生分支不在 refs/heads 里，没有状态；上游指向已删除的本地分支同样是跟踪错误。
    @Test("跟踪错误、父分支基准、分离 HEAD 与未出生分支")
    func conditions() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)

        // 还没有提交的仓库：快照与状态都为空
        let empty = try await refs.snapshot()

        #expect(RepositoryReferences.conditions(in: empty).isEmpty)

        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])

        // 分支名带引号、中文与斜杠
        let quoted = "feature/it's-\"合并\""
        _ = try await runner.run(["branch", quoted])

        // 上游指向本机的 main 与已删除的本机分支
        _ = try await runner.run(["branch", "tracked"])
        _ = try await runner.run(["branch", "--set-upstream-to=main", "tracked"])
        _ = try await runner.run(["branch", "temporary"])
        _ = try await runner.run(["branch", "--set-upstream-to=temporary", quoted])
        _ = try await runner.run(["branch", "-D", "temporary"])

        // 自定义名字的父分支也是基准
        _ = try await runner.run(["switch", "-q", "-c", "team/base"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "base work"])
        _ = try await runner.run(["branch", "child"])
        try await refs.setParent("refs/heads/team/base", of: "refs/heads/child")

        // 有自己提交的分支，上游指向已经不存在的远端分支
        _ = try await runner.run(["switch", "-q", "-c", "active", "main"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "active work"])
        _ = try await runner.run(["config", "branch.active.remote", "origin"])
        _ = try await runner.run(["config", "branch.active.merge", "refs/heads/active"])
        _ = try await runner.run(["config", "remote.origin.url", "/nonexistent"])

        _ = try await runner.run([
            "config",
            "remote.origin.fetch",
            "+refs/heads/*:refs/remotes/origin/*",
        ])

        let snapshot = try await refs.snapshot()
        let bases = RepositoryReferences.baseBranches(in: snapshot)

        #expect(bases == ["refs/heads/main", "refs/heads/team/base"])

        let conditions = RepositoryReferences.conditions(in: snapshot, bases: bases)

        #expect(Set(conditions.keys) == Set(snapshot.references.filter(\.isLocal).map(\.id)))

        // 省略基准时取同一份名单
        #expect(RepositoryReferences.conditions(in: snapshot) == conditions)

        let main = try #require(conditions["refs/heads/main"])
        let base = try #require(conditions["refs/heads/team/base"])
        let child = try #require(conditions["refs/heads/child"])
        let tracked = try #require(conditions["refs/heads/tracked"])

        #expect(main.isBase && !main.hasTrackingError)
        #expect(base.isBase && !child.isBase)
        #expect(!tracked.isBase && !tracked.hasTrackingError)
        #expect(conditions["refs/heads/" + quoted]?.missingUpstream == "refs/heads/temporary")

        let active = try #require(conditions["refs/heads/active"])

        #expect(!active.isBase)
        #expect(active.missingUpstream == "refs/remotes/origin/active")

        // 时间来自顶端提交，与快照里的同一字段一致
        #expect(active.lastUpdated == snapshot.references.first { $0.id == "refs/heads/active" }?.date)
        #expect(active.lastUpdated != nil)

        // 只按 main 判断时，父分支不算基准
        let mainOnly = RepositoryReferences.conditions(in: snapshot, bases: ["refs/heads/main"])
        let parent = try #require(mainOnly["refs/heads/team/base"])

        #expect(!parent.isBase)

        // 分离 HEAD 之后再切到一个未出生的分支，状态里不多出任何一项
        _ = try await runner.run(["switch", "-q", "--detach", "main"])
        _ = try await runner.run(["switch", "-q", "--orphan", "unborn"])

        let unborn = try await refs.snapshot()

        #expect(Set(RepositoryReferences.conditions(in: unborn).keys) == Set(conditions.keys))
    }

    /// 陈旧按日历月比较：恰好在阈值上不算，早一秒就算；基准分支与读不到时间的分支从不陈旧。
    @Test("陈旧阈值的边界")
    func staleBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 12)))
        let threshold = try #require(calendar.date(byAdding: .month, value: -3, to: now))

        let onThreshold = condition(lastUpdated: threshold)
        #expect(!onThreshold.isStale(months: 3, now: now, calendar: calendar))

        let earlier = condition(lastUpdated: threshold.addingTimeInterval(-1))
        #expect(earlier.isStale(months: 3, now: now, calendar: calendar))
        #expect(!earlier.isStale(months: 4, now: now, calendar: calendar))
        #expect(!earlier.isStale(months: 0, now: now, calendar: calendar))

        #expect(!condition(lastUpdated: .distantPast, isBase: true).isStale(months: 1, now: now, calendar: calendar))
        #expect(!condition(lastUpdated: nil).isStale(months: 1, now: now, calendar: calendar))
    }

    /// 基准名单只收快照里存在的分支：标准名按 main、master、trunk、dev、develop、next 的顺序在前，父分支去重后排在其后。
    @Test("基准分支名单")
    func baseBranches() {
        let names = [
            "refs/heads/master",
            "refs/heads/dev",
            "refs/heads/trunk",
            "refs/heads/zeta",
            "refs/heads/alpha",
        ]

        let snapshot = ReferenceSnapshot(
            references: names.map { reference($0) },
            remotes: [],
            metadata: [
                "refs/heads/a": BranchMetadata(parent: "refs/heads/zeta"),
                "refs/heads/b": BranchMetadata(parent: "refs/heads/zeta"),
                "refs/heads/c": BranchMetadata(parent: "refs/heads/master"),
                "refs/heads/d": BranchMetadata(parent: "refs/heads/missing"),
                "refs/heads/e": BranchMetadata(parent: "refs/heads/alpha"),
            ]
        )

        #expect(
            RepositoryReferences.baseBranches(in: snapshot) == [
                "refs/heads/master",
                "refs/heads/trunk",
                "refs/heads/dev",
                "refs/heads/alpha",
                "refs/heads/zeta",
            ]
        )
    }
}

// MARK: - Helpers

extension BranchConditionTests {
    /// 只关心时间与是否为基准的分支状态。
    private func condition(lastUpdated: Date?, isBase: Bool = false) -> BranchCondition {
        BranchCondition(
            reference: "refs/heads/topic",
            lastUpdated: lastUpdated,
            missingUpstream: nil,
            isBase: isBase
        )
    }

    /// 指向同一个提交、读不到时间的本地分支。
    private func reference(_ id: String) -> RepositoryReference {
        RepositoryReference(
            id: id,
            objectID: String(repeating: "a", count: 40),
            objectType: "commit",
            upstream: nil,
            upstreamRemote: nil,
            upstreamBranch: nil,
            symbolicTarget: nil,
            date: nil
        )
    }
}
