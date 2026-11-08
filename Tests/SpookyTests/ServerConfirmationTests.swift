import Foundation
import Testing

@testable import Spooky

// MARK: - ServerConfirmationTests

/// 服务器仓库的删除与覆盖确认：关掉以后直接执行。
@MainActor
struct ServerConfirmationTests {
    /// 打开时交给窗口确认，关掉后不再询问、直接执行。
    @Test("关掉的确认直接执行")
    func suppression() {
        let confirmation = ServerConfirmation.restoreFiles
        let saved = UserDefaults.standard.object(forKey: confirmation.key)
        defer { UserDefaults.standard.set(saved, forKey: confirmation.key) }

        let session = RepositorySession()
        var shown: [ServerConfirmation?] = []
        var performed = 0

        session.onConfirm = { request in
            shown.append(request.suppression)
            request.action()
        }

        UserDefaults.standard.removeObject(forKey: confirmation.key)

        session.confirmOnServer(
            confirmation,
            title: "Restore",
            submitTitle: "Restore",
            message: ""
        ) { performed += 1 }

        #expect(shown == [confirmation])
        #expect(performed == 1)

        // 在确认对话框里勾选不再提醒之后
        confirmation.isEnabled = false

        session.confirmOnServer(
            confirmation,
            title: "Restore",
            submitTitle: "Restore",
            message: ""
        ) { performed += 1 }

        #expect(shown == [confirmation])
        #expect(performed == 2)
    }
}
