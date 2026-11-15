import ApplicationServices
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - BranchDialogTests

/// 新建、跟踪、改名与删除分支的对话框：名称框的规范化与校验说明、跟踪远端分支与拉取、合并来源的预选，
/// 以及删除分支的说明与选项顺序。
///
/// 删除分支的一项经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct BranchDialogTests {
    /// 新建本地分支与本地分支改名按分支规则规范化，推送与发布按通用规则，跟踪远端分支、远端分支改名与远端改名原样保留，
    /// 关闭设置后都原样保留；空名称不可提交也不显示说明，不合法时写出原因，新建与跟踪的本地重名、
    /// 与已有分支文件夹同名、发布的远端重名分别说明，推送不查重名。
    @Test("名称框的规范化与校验说明")
    func nameInput() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let session = fixture.session
        let branches = session.history.branches
        let local = try #require(branches.first { $0.id == "refs/heads/side" })
        let remote = try #require(branches.first { $0.id == "refs/remotes/origin/main" })
        let input = "-a b~c..d.lock"

        // 已有分支 feature/login，feature 是它的文件夹
        _ = try await fixture.runner.run(["branch", "feature/login"])
        await Self.reload(session)

        // 操作对话框的名称框
        #expect(RepositoryOperationDialog.normalizedName(input, for: .create, cleaning: true) == "-a-b-c.d")
        #expect(RepositoryOperationDialog.normalizedName(input, for: .publish, cleaning: true) == "a-bc.d.lock")
        #expect(RepositoryOperationDialog.normalizedName(input, for: .track, cleaning: true) == input)
        #expect(RepositoryOperationDialog.normalizedName(input, for: .create, cleaning: false) == input)

        // 改名对话框
        #expect(RenameReferenceDialog.normalizedName(input, for: .branch(local), cleaning: true) == "-a-b-c.d")
        #expect(RenameReferenceDialog.normalizedName(input, for: .branch(remote), cleaning: true) == input)
        #expect(RenameReferenceDialog.normalizedName(input, for: .remote("origin"), cleaning: true) == input)
        #expect(RenameReferenceDialog.normalizedName(input, for: .branch(local), cleaning: false) == input)

        // 校验结果与说明
        let cases: [(String, RepositoryActionRequest.Kind, Bool, String)] = [
            ("", .create, false, ""),
            ("-x", .create, false, AppLocalization.text("reference.name.leadingHyphen")),
            ("a/.b", .track, false, AppLocalization.text("reference.name.component")),
            ("side", .create, false, AppLocalization.text("branch.exists", "side")),
            ("side", .track, false, AppLocalization.text("branch.exists", "side")),
            ("feature", .create, false, AppLocalization.text("branch.groupExists")),
            ("feature", .track, false, AppLocalization.text("branch.groupExists")),
            ("main", .publish, false, AppLocalization.text("branch.remoteExists", "main", "origin")),
            ("main", .push, true, ""),
            ("feature/新", .create, true, ""),
        ]

        for (name, kind, isValid, error) in cases {
            let result = await RepositoryOperationDialog.nameValidation(
                name,
                for: kind,
                remote: "origin",
                in: session
            )

            #expect(result.isValid == isValid, "\(name) \(kind)")
            #expect(result.error == error, "\(name) \(kind)")
        }

        // 改名时文件夹里只有被改名的分支自己，不算同名
        #expect(!session.isBranchFolder("feature", excluding: "refs/heads/feature/login"))
    }

    /// 跟踪远端分支的预选：入口传入的远端分支优先；没有预选或预选不是远端分支时取 HEAD 的上游；
    /// HEAD 没有上游时取第一个远端分支；没有远端分支时为空。
    ///
    /// 合并与版本框的候选依次是本地分支（含 HEAD 分支）、各远端的远端分支与标签，拉取与跟踪只有远端分支：
    /// 组内 main 在最前，origin 的远端分支排在别的远端之前；两者先预选 HEAD 的上游，HEAD 没有上游时取第一个不是 HEAD 分支的候选。
    /// 远端下拉同样 origin 在前；父分支只列其它本地分支。
    @Test("跟踪远端分支与拉取、合并来源的候选和预选回退")
    func trackPreselection() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let session = fixture.session
        _ = try await fixture.runner.run(["update-ref", "refs/remotes/origin/feature", "HEAD"])

        // 名字排在 origin 之前的另一个远端
        _ = try await fixture.runner.run(["remote", "add", "extra", "/nonexistent/extra.git"])
        _ = try await fixture.runner.run(["update-ref", "refs/remotes/extra/main", "HEAD"])
        await Self.reload(session)

        let source = { RepositoryOperationDialog.trackSource(preselection: $0, in: session) }

        // HEAD 的上游是 origin/main
        #expect(source("refs/remotes/origin/feature") == "refs/remotes/origin/feature")
        #expect(source(nil) == "refs/remotes/origin/main")
        #expect(source("refs/heads/side") == "refs/remotes/origin/main")

        // 拉取与合并的候选和预选
        let candidates = { RepositoryOperationDialog.sourceCandidates(for: $0, in: session).map(\.id) }
        let preselection = {
            RepositoryOperationDialog.sourcePreselection(for: $0, preselection: nil, in: session)
        }

        // 远端分支里 main 排在最前，不按名字排在 feature 之后；origin 排在 extra 之前
        let remotes = ["refs/remotes/origin/main", "refs/remotes/origin/feature", "refs/remotes/extra/main"]

        #expect(candidates(.merge) == ["refs/heads/main", "refs/heads/side"] + remotes + ["refs/tags/v1"])
        #expect(candidates(.pull) == remotes)
        #expect(session.revisionReferences.map(\.id) == candidates(.merge))
        #expect(session.orderedRemoteNames == ["origin", "extra"])

        let side = try #require(session.history.branches.first { $0.id == "refs/heads/side" })
        #expect(SetParentBranchDialog(session: session, branch: side) { }.candidates.map(\.id) == ["refs/heads/main"])
        #expect(preselection(.merge) == "refs/remotes/origin/main")
        #expect(preselection(.pull) == "refs/remotes/origin/main")

        // HEAD 没有上游
        _ = try await fixture.runner.run(["branch", "--unset-upstream", "main"])
        await Self.reload(session)

        #expect(source(nil) == "refs/remotes/origin/main")
        #expect(preselection(.merge) == "refs/heads/side")
        #expect(preselection(.pull) == "refs/remotes/origin/main")

        // 没有远端分支
        let empty = RepositorySession(loadStatus: { _ in throw CancellationError() })

        #expect(RepositoryOperationDialog.trackSource(preselection: nil, in: empty).isEmpty)
    }

    /// 新建分支的父分支只能是起点本身（本地分支）或与远端起点同名、且确实跟踪它的本地分支；
    /// 提交、标签、只是同名或只是跟踪它的起点都没有候选，候选分支消失后同样没有。
    @Test("新建分支的父分支候选随起点核对")
    func parentCandidates() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let session = fixture.session
        let runner = fixture.runner
        let candidate = { RepositoryOperationDialog.parentCandidate(for: $0, in: session)?.id }

        // 远端有与 side 同名的分支 origin/side，还有 origin/feature
        _ = try await runner.run(["update-ref", "refs/remotes/origin/side", "side"])
        _ = try await runner.run(["update-ref", "refs/remotes/origin/feature", "HEAD"])
        await Self.reload(session)

        // 本地分支起点、提交与标签起点；main 跟踪同名的 origin/main
        #expect(candidate("side") == "refs/heads/side")
        #expect(candidate("refs/heads/main") == "refs/heads/main")
        #expect(candidate(try #require(fixture.ids["A"])) == nil)
        #expect(candidate("v1") == nil)
        #expect(candidate("origin/main") == "refs/heads/main")

        // side 同名但不跟踪 origin/side；跟踪 origin/feature 但不同名
        _ = try await runner.run(["branch", "-q", "--set-upstream-to=origin/feature", "side"])
        await Self.reload(session)

        #expect(candidate("origin/side") == nil)
        #expect(candidate("origin/feature") == nil)

        // 改为跟踪同名的 origin/side 后才是候选
        _ = try await runner.run(["branch", "-q", "--set-upstream-to=origin/side", "side"])
        await Self.reload(session)

        #expect(candidate("refs/remotes/origin/side") == "refs/heads/side")

        // 候选分支消失
        _ = try await runner.run(["branch", "-q", "-D", "side"])
        await Self.reload(session)

        #expect(candidate("origin/side") == nil)
    }

    /// 删除一个跟踪远端分支的本地分支：说明写出分支名，强制删除在上、不带说明、不勾，删除跟踪的远端分支在下并写出它；
    /// 删除多个分支时说明写成所选分支；删除多个分支、或跟踪的远端分支已不存在时，没有删除跟踪分支的选项。
    @Test("删除分支的说明与选项顺序", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func deleteBranches() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let session = fixture.session
        let branches = session.history.branches
        let main = try #require(branches.first { $0.id == "refs/heads/main" })
        let side = try #require(branches.first { $0.id == "refs/heads/side" })

        // 单个分支
        let single = await Self.deleteDialog(.branches([main]), in: session)
        let checkBoxes = single.filter { $0.role == "AXCheckBox" }.sorted { $0.frame.minY < $1.frame.minY }

        #expect(checkBoxes.map(\.name) == [
            AppLocalization.text("branch.forceDelete"),
            AppLocalization.text("branch.deleteUpstream"),
        ])

        #expect(checkBoxes.map(\.value) == ["0", "0"])
        #expect(single.contains { $0.value == AppLocalization.text("branch.delete.message", "main") })
        #expect(single.contains { $0.value == AppLocalization.text("branch.deleteUpstream.help", "origin/main") })

        // 多个分支
        let multiple = await Self.deleteDialog(.branches([main, side]), in: session)

        #expect(multiple.contains { $0.value == AppLocalization.text("branch.deleteMultiple.message") })
        #expect(multiple.filter { $0.role == "AXCheckBox" }.map(\.name) == [AppLocalization.text("branch.forceDelete")])

        // 跟踪的远端分支已不存在：没有删除跟踪分支一项与它的说明
        _ = try await fixture.runner.run(["config", "--local", "branch.side.remote", "origin"])
        _ = try await fixture.runner.run(["config", "--local", "branch.side.merge", "refs/heads/gone"])
        await Self.reload(session)

        let tracking = try #require(session.history.branches.first { $0.id == "refs/heads/side" })
        let gone = await Self.deleteDialog(.branches([tracking]), in: session)

        #expect(tracking.upstream == "refs/remotes/origin/gone")
        #expect(gone.filter { $0.role == "AXCheckBox" }.map(\.name) == [AppLocalization.text("branch.forceDelete")])
        #expect(!gone.contains { $0.value == AppLocalization.text("branch.deleteUpstream.help", "origin/gone") })
    }
}

// MARK: - Helpers

extension BranchDialogTests {
    /// 重新读取仓库，等引用与历史都读完。
    private static func reload(_ session: RepositorySession) async {
        session.refresh(full: true)
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
    }

    /// 打开删除对话框，读出全部元素。
    private static func deleteDialog(
        _ target: DeleteReferencesDialog.Target,
        in session: RepositorySession
    ) async -> [AccessibilityProbe.Element] {
        await AccessibilityProbe.elements(until: { $0.contains { $0.role == "AXCheckBox" } }) {
            DeleteReferencesDialog(session: session, target: target, close: { })
        }
    }
}
