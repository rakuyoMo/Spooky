import Foundation
import Testing

@testable import Spooky

// MARK: - ServerConfirmationTests

/// 服务器仓库的删除与覆盖确认：关掉以后直接执行；丢弃块与 General 页已有的警告共用一个偏好，各项的偏好与文案都不重复。
@MainActor
struct ServerConfirmationTests {
    /// 打开时交给窗口确认，关掉后不再询问、直接执行。
    @Test("关掉的确认直接执行")
    func suppression() {
        let confirmation = ServerConfirmation.restoreFiles
        let saved = UserDefaults.standard.object(forKey: confirmation.key)
        defer { UserDefaults.standard.set(saved, forKey: confirmation.key) }

        let session = RepositorySession()
        var shown: [ServerConfirmation] = []
        var performed = 0

        session.onServerConfirm = { confirmation, _, _, action in
            shown.append(confirmation)
            action()
        }

        UserDefaults.standard.removeObject(forKey: confirmation.key)
        session.confirmOnServer(confirmation, title: "Restore", message: "") { performed += 1 }
        #expect(shown == [confirmation])
        #expect(performed == 1)

        // 在确认框里勾选不再提醒之后
        confirmation.isEnabled = false
        session.confirmOnServer(confirmation, title: "Restore", message: "") { performed += 1 }
        #expect(shown == [confirmation])
        #expect(performed == 2)
    }

    /// 丢弃块与本机仓库共用 General 页已有的警告；每一项都有自己的偏好与已翻译的文案。
    @Test("确认的偏好与文案")
    func preferences() {
        #expect(ServerConfirmation.discardChunks.key == WorkingCopyPreferences.warnsDiscardingChunks)
        #expect(Set(ServerConfirmation.allCases.map(\.key)).count == ServerConfirmation.allCases.count)

        for confirmation in ServerConfirmation.allCases {
            #expect(AppLocalization.text(confirmation.titleKey) != confirmation.titleKey)
        }
    }
}
