import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - BranchDialogTests

/// 新建、跟踪、改名分支的名称框：输入时的规范化随对话框与对象变化，校验说明写出不能使用的原因。
@MainActor
struct BranchDialogTests {
    /// 新建本地分支与本地分支改名按分支规则规范化，推送与发布按通用规则，跟踪远端分支、远端分支改名与远端改名原样保留，
    /// 关闭设置后都原样保留；空名称不可提交也不显示说明，不合法时写出原因，新建与跟踪的本地重名、
    /// 发布的远端重名分别说明，推送不查重名。
    @Test("名称框的规范化与校验说明")
    func nameInput() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let session = fixture.session
        let branches = session.history.branches
        let local = try #require(branches.first { $0.id == "refs/heads/side" })
        let remote = try #require(branches.first { $0.id == "refs/remotes/origin/main" })
        let input = "-a b~c..d.lock"

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
    }
}
