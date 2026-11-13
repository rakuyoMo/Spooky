import AppKit
import ApplicationServices
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - PushDestinationTests

/// 推送 HEAD 的 Destination 与无目标状态：候选只取已配置远端的远端分支，预选依次是上游、无上游时同名、第一个；
/// 各动作没有目标时各自说明并禁止提交；强推的期望值是所选远端分支的版本。
///
/// 读对话框控件的一项经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct PushDestinationTests {
    /// 同一个仓库上依次增删远端与远端分支，核对 Destination 的候选、推送目标、预选与各动作的空状态。
    @Test("Destination 的候选、推送目标、预选与空状态")
    func destinations() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        try await Self.expectCandidates(in: fixture)
        try await Self.expectPreselection(in: fixture)
        try await Self.expectEmptyStates(in: fixture)
    }

    /// 还没有提交的仓库没有本地分支，也没有可合并的引用：发布与合并各自说明，Push HEAD 说明还没有远端分支。
    @Test("没有提交的仓库的空状态")
    func unbornEmptyStates() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        _ = try await runner.run(["remote", "add", "origin", directory.path])

        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        defer { session.close() }

        session.display(location)
        await Self.reload(session)

        try #require(!(session.history.snapshot?.remotes.isEmpty ?? true))

        let emptyState = { (kind: RepositoryActionRequest.Kind) in
            RepositoryOperationDialog.emptyState(for: RepositoryActionRequest(kind: kind), in: session)
        }

        #expect(emptyState(.publish) == AppLocalization.text("sync.publish.noBranches"))
        #expect(emptyState(.merge) == AppLocalization.text("sync.merge.empty"))
        #expect(emptyState(.push) == AppLocalization.text("sync.noRemoteBranches"))
        #expect(emptyState(.fetch) == nil)
    }

    /// 强推下拉下方的提交数与远端多出提交的提醒，零、一个与多个各用一条文案。
    @Test("强推说明的单复数")
    func leaseCounts() {
        let counts = { introduced, overwritten in
            SyncDialog.leaseCounts(
                of: ForcePushPreview(
                    source: "",
                    destination: "",
                    introduced: introduced,
                    overwritten: overwritten,
                    status: .matchesLastKnown
                )
            )
        }

        #expect(counts(0, 1) == (
            AppLocalization.text("sync.lease.introduced.zero"),
            AppLocalization.text("sync.lease.overwritten.one")
        ))

        #expect(counts(1, 0) == (
            AppLocalization.text("sync.lease.introduced.one"),
            AppLocalization.text("sync.lease.overwritten.zero")
        ))

        #expect(counts(3, 2) == (
            AppLocalization.text("sync.lease.introduced", 3),
            AppLocalization.text("sync.lease.overwritten", 2)
        ))

        // 远端多出的提交至少一个
        #expect(SyncDialog.newerCommits(1) == AppLocalization.text("sync.lease.newer.one"))
        #expect(SyncDialog.newerCommits(2) == AppLocalization.text("sync.lease.newer", 2))
    }

    /// 从对话框提交 Push HEAD 的强推：目标是 Destination 预选的上游，远端已不是它记下的版本时 Git 拒绝并报告原文；
    /// 打开后所选的远端分支被删除时改选下一个，全部删除后说明没有远端分支，主按钮不可用。
    @Test("Push HEAD 对话框的强推与打开后目标被移除", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func pushHeadDialog() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        try await Self.expectLeaseRejection(in: fixture)
        try await Self.expectTargetRemoval(in: fixture)
    }
}

// MARK: - Destinations

extension PushDestinationTests {
    /// 候选不含远端 HEAD 这类符号引用、本地分支与没有配置的远端留下的远端分支；
    /// 推送目标切掉所属远端的前缀，期望值是这个远端跟踪分支的版本。
    private static func expectCandidates(in fixture: OperationWiringTests.Fixture) async throws {
        let runner = fixture.runner
        let session = fixture.session
        let side = try #require(fixture.ids["S"])
        let first = try #require(fixture.ids["A"])

        // 远端 HEAD 的符号引用、另一个已配置的远端，以及没有配置的远端留下的远端分支
        _ = try await runner.run(["symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main"])
        _ = try await runner.run(["remote", "add", "backup", fixture.directory.path])
        _ = try await runner.run(["update-ref", "refs/remotes/backup/feature/一", side])
        _ = try await runner.run(["update-ref", "refs/remotes/backup/main", first])
        _ = try await runner.run(["update-ref", "refs/remotes/gone/main", first])

        await reload(session)

        let candidates = RepositoryOperationDialog.pushDestinations(in: session).map(\.id)

        #expect(
            Set(candidates) == [
                "refs/remotes/origin/main",
                "refs/remotes/backup/feature/一",
                "refs/remotes/backup/main",
            ]
        )

        // 推送目标
        let target = try #require(
            RepositoryOperationDialog.destinationTarget("refs/remotes/backup/feature/一", in: session)
        )

        #expect(target.remote == "backup" && target.branch == "feature/一" && target.lease == side)
        #expect(RepositoryOperationDialog.destinationTarget("refs/remotes/gone/main", in: session) == nil)
    }

    /// HEAD 有上游时取上游；HEAD 没有上游时取同名的远端分支而不是第一个候选；上游已删除时直接取第一个候选。
    private static func expectPreselection(in fixture: OperationWiringTests.Fixture) async throws {
        let runner = fixture.runner
        let session = fixture.session
        let preselect = { RepositoryOperationDialog.destinationPreselection(in: session) }

        #expect(preselect() == "refs/remotes/origin/main")

        // HEAD 没有上游，origin 上也没有 main：只有 backup 上有同名的远端分支，它不是第一个候选
        _ = try await runner.run(["config", "--local", "--unset", "branch.main.remote"])
        _ = try await runner.run(["config", "--local", "--unset", "branch.main.merge"])
        _ = try await runner.run(["symbolic-ref", "--delete", "refs/remotes/origin/HEAD"])
        _ = try await runner.run(["update-ref", "-d", "refs/remotes/origin/main"])

        await reload(session)

        let candidates = RepositoryOperationDialog.pushDestinations(in: session).map(\.id)

        try #require(candidates.first != "refs/remotes/backup/main")

        #expect(preselect() == "refs/remotes/backup/main")

        // 上游仍配置为已删除的 origin/main
        _ = try await runner.run(["config", "--local", "branch.main.remote", "origin"])
        _ = try await runner.run(["config", "--local", "branch.main.merge", "refs/heads/main"])

        await reload(session)

        #expect(preselect() == candidates.first)
    }

    /// 远端都在、远端分支全部删除时 Push HEAD、拉取与跟踪说明还没有远端分支，Push Branch 仍可推到新的远端分支；
    /// 远端全部移除后各动作各自说明。
    private static func expectEmptyStates(in fixture: OperationWiringTests.Fixture) async throws {
        let runner = fixture.runner
        let session = fixture.session
        let emptyState = { RepositoryOperationDialog.emptyState(for: $0, in: session) }
        let pushHead = RepositoryActionRequest(kind: .push)
        let pushBranch = RepositoryActionRequest(kind: .push, localBranch: "side")
        let noRemoteBranches = AppLocalization.text("sync.noRemoteBranches")
        let noRemotes = AppLocalization.text("sync.noRemotes")

        #expect(emptyState(pushHead) == nil)

        for reference in ["refs/remotes/backup/feature/一", "refs/remotes/backup/main", "refs/remotes/gone/main"] {
            _ = try await runner.run(["update-ref", "-d", reference])
        }

        await reload(session)

        #expect(emptyState(pushHead) == noRemoteBranches)
        #expect(emptyState(pushBranch) == nil)
        #expect(emptyState(RepositoryActionRequest(kind: .pull)) == noRemoteBranches)
        #expect(emptyState(RepositoryActionRequest(kind: .track)) == noRemoteBranches)
        #expect(emptyState(RepositoryActionRequest(kind: .fetch)) == nil)
        #expect(RepositoryOperationDialog.destinationPreselection(in: session).isEmpty)

        // 远端全部移除
        _ = try await runner.run(["remote", "remove", "origin"])
        _ = try await runner.run(["remote", "remove", "backup"])

        await reload(session)

        #expect(emptyState(pushHead) == AppLocalization.text("sync.push.empty"))
        #expect(emptyState(pushBranch) == AppLocalization.text("sync.push.empty"))
        #expect(emptyState(RepositoryActionRequest(kind: .publish)) == AppLocalization.text("sync.publish.noRemotes"))
        #expect(emptyState(RepositoryActionRequest(kind: .fetch)) == noRemotes)
        #expect(emptyState(RepositoryActionRequest(kind: .pull)) == noRemotes)
        #expect(emptyState(RepositoryActionRequest(kind: .track)) == noRemotes)
        #expect(emptyState(RepositoryActionRequest(kind: .merge)) == nil)
    }
}

// MARK: - Dialog

extension PushDestinationTests {
    /// 对话框交出的推送：Activity 记下所选的远端与 refspec；预选的 origin/main 记的是 C，
    /// 而远端的 main 已是 B，强推被 Git 以期望值过期拒绝。
    private static func expectLeaseRejection(in fixture: OperationWiringTests.Fixture) async throws {
        let runner = fixture.runner
        let remote = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: remote) }

        // origin 换成单独的裸仓库，main 停在 B：与本地的 D 不同，推送不会因已是最新而跳过期望值的核对
        let older = try #require(fixture.ids["B"])

        _ = try await runner.run(["init", "--bare", "-q", remote.path])
        _ = try await runner.run(["push", "-q", remote.path, older + ":refs/heads/main"])
        _ = try await runner.run(["config", "--local", "remote.origin.url", remote.path])

        let captured = CapturedSubmission()

        _ = await AccessibilityProbe.elements(
            width: 450,
            pressing: [
                AppLocalization.text("dialog.options"),
                AppLocalization.text("sync.forcePush"),
                AppLocalization.text("sync.pushHead"),
            ],
            until: { _ in captured.operation != nil }
        ) {
            RepositoryOperationDialog(
                session: fixture.session,
                request: RepositoryActionRequest(kind: .push),
                cancel: { }
            ) { _, _, target, _, operation in
                captured.target = target
                captured.operation = operation
                return true
            }
        }

        let operation = try #require(captured.operation)

        #expect(captured.target?.remote == "origin")
        #expect(captured.target?.refspec == "refs/heads/main:refs/heads/main")

        do {
            try await operation(runner) { _ in }
            Issue.record("远端已不是期望值时必须拒绝")
        } catch let error as GitError {
            #expect(error.category == .pushRejected)
            #expect(String(decoding: error.result.standardOutput, as: UTF8.self).contains("stale info"))
        }
    }

    /// 打开时预选上游 origin/main；删掉它后改选 backup 上的第一个远端分支；backup 的远端分支也删掉后说明没有远端分支，
    /// 主按钮不可用。
    private static func expectTargetRemoval(in fixture: OperationWiringTests.Fixture) async throws {
        let runner = fixture.runner
        let session = fixture.session
        let first = try #require(fixture.ids["A"])

        _ = try await runner.run(["remote", "add", "backup", fixture.directory.path])
        _ = try await runner.run(["update-ref", "refs/remotes/backup/main", first])
        _ = try await runner.run(["update-ref", "refs/remotes/backup/topic", first])

        await reload(session)

        let steps = TargetRemoval(runner: runner, session: session)
        let submit = AppLocalization.text("sync.pushHead")
        let noRemoteBranches = AppLocalization.text("sync.noRemoteBranches")

        let elements = await AccessibilityProbe.elements(width: 450, until: steps.advance) {
            RepositoryOperationDialog(
                session: session,
                request: RepositoryActionRequest(kind: .push),
                cancel: { },
                submit: { _, _, _, _, _ in false }
            )
        }

        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == noRemoteBranches })
        #expect(elements.contains { $0.role == "AXButton" && $0.name == submit && !$0.isEnabled })
    }
}

// MARK: - Helpers

extension PushDestinationTests {
    /// 对话框交给 `submit` 的 Activity 对象与业务操作。
    @MainActor
    final class CapturedSubmission {
        /// Activity 记录连接的对象。
        var target: ActivityTarget? = nil

        /// 按表单值执行推送的操作。
        var operation: (@Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void)? = nil
    }

    /// 读到 Destination 的选择后依次删除远端分支，等对话框改选或进入空状态。
    @MainActor
    final class TargetRemoval {
        /// 仓库的执行器。
        let runner: GitRunner

        /// 显示仓库的会话。
        let session: RepositorySession

        /// 已经发起的删除次数。
        private var removals = 0

        /// 用仓库的执行器与会话建立。
        init(runner: GitRunner, session: RepositorySession) {
            self.runner = runner
            self.session = session
        }

        /// 读到预选的 origin/main 时删掉它，读到改选的 backup/main 时删掉 backup 的全部远端分支；
        /// 读到没有远端分支的说明时结束。
        func advance(_ elements: [AccessibilityProbe.Element]) -> Bool {
            let selected = elements.first { $0.role == "AXPopUpButton" }?.value

            if removals == 0, selected == "origin/main" {
                remove(["refs/remotes/origin/main"])
            } else if removals == 1, selected == "backup/main" {
                remove(["refs/remotes/backup/main", "refs/remotes/backup/topic"])
            }

            return removals == 2
                && elements.contains { $0.value == AppLocalization.text("sync.noRemoteBranches") }
        }

        /// 删掉这些远端分支并重新读取仓库。
        private func remove(_ references: [String]) {
            removals += 1

            Task { [runner, session] in
                do {
                    for reference in references {
                        _ = try await runner.run(["update-ref", "-d", reference])
                    }
                } catch {
                    Issue.record(error)
                }

                await PushDestinationTests.reload(session)
            }
        }
    }

    /// 重新读取仓库，等引用与历史都读完。
    static func reload(_ session: RepositorySession) async {
        session.refresh(full: true)
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
    }
}
