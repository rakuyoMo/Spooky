import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 中断的获取或推送重连核对后，报告列出远端跟踪分支的变化，用户据此判断是否需要重试。
@MainActor
struct RecoveryReferencesTests {
    /// 改动、新增与删除的远端跟踪分支各占一行；没有变化时只说明没有变化。
    @Test("核对报告里的远端跟踪分支")
    func remoteReferenceChanges() throws {
        let old = String(repeating: "a", count: 40)
        let new = String(repeating: "b", count: 40)

        var write = InterruptedWrite(title: "Push", branch: nil, time: Date())
        write.remoteReferences = ["refs/remotes/origin/main": old, "refs/remotes/origin/gone": old]

        var snapshot = RemoteRecoverySnapshot(
            status: try WorkingCopyStatus(porcelainV2: Data()),
            indexLocked: false,
            merging: false,
            rebasing: false,
            checkedAt: Date()
        )
        snapshot.remoteReferences = ["refs/remotes/origin/main": new, "refs/remotes/origin/新分支": new]

        let none = AppLocalization.text("recovery.noReference")
        let lines = RepositoryWindowController.remoteReferenceChanges(write, snapshot: snapshot)
            .split(separator: "\n")
            .map(String.init)

        #expect(
            lines == [
                AppLocalization.text("recovery.remoteChanged"),
                "origin/gone  aaaaaaaa → " + none,
                "origin/main  aaaaaaaa → bbbbbbbb",
                "origin/新分支  " + none + " → bbbbbbbb",
            ]
        )

        snapshot.remoteReferences = write.remoteReferences

        #expect(
            RepositoryWindowController.remoteReferenceChanges(write, snapshot: snapshot)
                == AppLocalization.text("recovery.remoteUnchanged")
        )
    }
}
