import Foundation
import Testing

@testable import SpookyKit

// MARK: - BranchConditionTests

/// 分支的完全合并、陈旧与跟踪错误只看结构化结果：基准分支的可达性、提交时间与上游引用是否还在。
struct BranchConditionTests {
    /// 已并入基准、未并入、上游已删除与按父分支判断的分支各得到对应的状态；SHA-1 与 SHA-256 结果一致。
    @Test("完全合并、跟踪错误与父分支基准", arguments: ["sha1", "sha256"])
    func conditions(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])

        // 并入 main 的分支名带引号、中文与斜杠
        let merged = "feature/it's-\"合并\""
        _ = try await runner.run(["branch", merged])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "main moves on"])

        // 自定义名字的父分支也是基准：child 并入了它，但没有并入 main
        _ = try await runner.run(["switch", "-q", "-c", "team/base"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "base work"])
        _ = try await runner.run(["branch", "child"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "base moves on"])

        // 有自己提交的分支，上游指向已经不存在的远端分支
        _ = try await runner.run(["switch", "-q", "-c", "active", "main"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "active work"])
        _ = try await runner.run(["config", "branch.active.remote", "origin"])
        _ = try await runner.run(["config", "branch.active.merge", "refs/heads/active"])
        _ = try await runner.run(["config", "remote.origin.url", "/nonexistent"])
        _ = try await runner.run(["config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*"])
        try await refs.setParent("refs/heads/team/base", of: "refs/heads/child")

        let snapshot = try await refs.snapshot()
        let bases = RepositoryReferences.baseBranches(in: snapshot)
        #expect(bases == ["refs/heads/main", "refs/heads/team/base"])

        let conditions = try await refs.conditions(in: snapshot, bases: bases)
        #expect(Set(conditions.keys) == Set(snapshot.references.filter(\.isLocal).map(\.id)))

        // 基准分支本身不算完全合并
        let main = try #require(conditions["refs/heads/main"])
        #expect(main.isBase && !main.isFullyMerged && !main.hasTrackingError)

        #expect(conditions["refs/heads/" + merged]?.mergedInto == "refs/heads/main")
        #expect(conditions["refs/heads/child"]?.mergedInto == "refs/heads/team/base")
        let base = try #require(conditions["refs/heads/team/base"])
        #expect(base.isBase)

        let active = try #require(conditions["refs/heads/active"])
        #expect(!active.isFullyMerged)
        #expect(active.missingUpstream == "refs/remotes/origin/active")

        // 时间来自顶端提交，与快照里的同一字段一致
        #expect(active.lastUpdated == snapshot.references.first { $0.id == "refs/heads/active" }?.date)
        #expect(active.lastUpdated != nil)

        // 只按 main 判断时，并入父分支的分支不算完全合并
        let mainOnly = try await refs.conditions(in: snapshot, bases: ["refs/heads/main"])
        let child = try #require(mainOnly["refs/heads/child"])
        let teamBase = try #require(mainOnly["refs/heads/team/base"])
        #expect(!child.isFullyMerged)
        #expect(!teamBase.isBase)
    }

    /// 分离 HEAD 与未出生分支不在 refs/heads 里，没有状态；上游指向已删除的本地分支同样是跟踪错误。
    @Test("分离 HEAD、未出生分支与本机上游")
    func detachedAndUnborn() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)

        // 还没有提交的仓库：快照与状态都为空
        let empty = try await refs.snapshot()
        #expect(try await refs.conditions(in: empty, bases: RepositoryReferences.baseBranches(in: empty)).isEmpty)

        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["branch", "tracked"])
        _ = try await runner.run(["branch", "--set-upstream-to=main", "tracked"])
        _ = try await runner.run(["branch", "temporary"])
        _ = try await runner.run(["branch", "--set-upstream-to=temporary", "main"])
        _ = try await runner.run(["branch", "-D", "temporary"])

        // 分离 HEAD 之后再切到一个未出生的分支
        _ = try await runner.run(["switch", "-q", "--detach", "main"])
        _ = try await runner.run(["switch", "-q", "--orphan", "unborn"])

        let snapshot = try await refs.snapshot()
        let conditions = try await refs.conditions(in: snapshot, bases: RepositoryReferences.baseBranches(in: snapshot))
        #expect(Set(conditions.keys) == ["refs/heads/main", "refs/heads/tracked"])
        #expect(conditions["refs/heads/main"]?.missingUpstream == "refs/heads/temporary")
        let tracked = try #require(conditions["refs/heads/tracked"])
        #expect(!tracked.hasTrackingError)

        // 顶端与基准相同的分支也算完全合并
        #expect(conditions["refs/heads/tracked"]?.mergedInto == "refs/heads/main")
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

    /// 合并查询的输出逐条去掉记录间的换行，不是本地分支的记录视为格式错误。
    @Test("合并查询输出的解析")
    func parseNames() throws {
        let data = Data("refs/heads/main\0\nrefs/heads/it's \"引号\"/*?\0\n".utf8)
        #expect(try RepositoryReferences.parseReferenceNames(data) == ["refs/heads/main", "refs/heads/it's \"引号\"/*?"])
        #expect(try RepositoryReferences.parseReferenceNames(Data()).isEmpty)

        #expect(throws: RepositoryReadError.self) {
            try RepositoryReferences.parseReferenceNames(Data("refs/tags/v1\0\n".utf8))
        }
        #expect(throws: RepositoryReadError.self) {
            try RepositoryReferences.parseReferenceNames(Data("main\n".utf8))
        }
    }

    /// 基准名单只收快照里存在的分支；父分支去重并排在标准名之后。
    @Test("基准分支名单")
    func baseBranches() {
        let snapshot = ReferenceSnapshot(
            references: ["refs/heads/master", "refs/heads/dev", "refs/heads/zeta", "refs/heads/alpha"].map(reference),
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
            RepositoryReferences.baseBranches(in: snapshot)
                == ["refs/heads/master", "refs/heads/dev", "refs/heads/alpha", "refs/heads/zeta"]
        )
    }

    /// 标签检出成分离 HEAD；不是完整标签名的参数直接拒绝，不交给 Git。
    @Test("检出标签")
    func checkoutTag() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let refs = RepositoryReferences(runner: runner)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["tag", "-a", "v1.0", "-m", "Release"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "next"])

        try await refs.checkoutTag("refs/tags/v1.0")
        let status = try await runner.status()
        let tagged = try await refs.resolve("refs/tags/v1.0")
        #expect(status.branch.head == nil)
        #expect(status.branch.oid == tagged)

        await #expect(throws: RepositoryReadError.self) { try await refs.checkoutTag("v1.0") }
        await #expect(throws: RepositoryReadError.self) { try await refs.checkoutTag("refs/tags/") }
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
            mergedInto: nil,
            isBase: isBase
        )
    }

    /// 指向同一个提交的本地分支。
    private func reference(_ id: String) -> RepositoryReference {
        RepositoryReference(
            id: id,
            objectID: String(repeating: "a", count: 40),
            objectType: "commit",
            upstream: nil,
            upstreamRemote: nil,
            upstreamBranch: nil,
            symbolicTarget: nil
        )
    }
}
