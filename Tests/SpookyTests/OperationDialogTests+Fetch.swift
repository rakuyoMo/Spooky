import ApplicationServices
import Foundation
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

/// 获取对话框的勾选项与保存的偏好。
extension OperationDialogTests {
    /// 没有保存值时 Fetch All Remotes 不勾、Prune 勾选；入口预选的远端与 Prune 意图只作用于本次打开，不写回偏好；
    /// 用户切换的勾选框立即保存，不提交就关闭也保留，之后按保存值打开。
    @Test("获取的临时预选与保存的偏好", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func fetchPreferences() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let options = AppLocalization.text("dialog.options")
        let prune = AppLocalization.text("sync.prune")
        let allRemotes = AppLocalization.text("sync.allRemotes")
        let entry = RepositoryActionRequest(kind: .fetch, remote: "origin", prune: true)
        let plain = RepositoryActionRequest(kind: .fetch)

        // 远端右键的 Prune 入口：显示默认值，偏好仍没有保存值
        let initial = await Self.fetchElements(entry, in: fixture.session, defaults: defaults, pressing: [options]) {
            Self.checkBox(prune, in: $0) != nil
        }

        #expect(Self.checkBox(allRemotes, in: initial) == "0")
        #expect(Self.checkBox(prune, in: initial) == "1")
        #expect(defaults.object(forKey: "fetchPrune") == nil)
        #expect(defaults.object(forKey: "fetchAllRemotes") == nil)

        // 普通入口里取消 Prune、勾上 Fetch All Remotes，不提交就关闭
        _ = await Self.fetchElements(
            plain,
            in: fixture.session,
            defaults: defaults,
            pressing: [options, prune, allRemotes]
        ) {
            Self.checkBox(prune, in: $0) == "0" && Self.checkBox(allRemotes, in: $0) == "1"
        }

        let savedPrune = try #require(defaults.object(forKey: "fetchPrune") as? Bool)
        let savedAllRemotes = try #require(defaults.object(forKey: "fetchAllRemotes") as? Bool)

        #expect(!savedPrune)
        #expect(savedAllRemotes)

        // 再从 Prune 入口打开：本次勾选 Prune，Fetch All Remotes 照保存值，偏好不变
        let again = await Self.fetchElements(entry, in: fixture.session, defaults: defaults, pressing: [options]) {
            Self.checkBox(prune, in: $0) != nil
        }

        #expect(Self.checkBox(prune, in: again) == "1")
        #expect(Self.checkBox(allRemotes, in: again) == "1")
        #expect(defaults.object(forKey: "fetchPrune") as? Bool == savedPrune)

        // 普通入口按保存值显示
        let saved = await Self.fetchElements(plain, in: fixture.session, defaults: defaults, pressing: [options]) {
            Self.checkBox(prune, in: $0) != nil
        }

        #expect(Self.checkBox(prune, in: saved) == "0")
    }
}

// MARK: - Fetch Helpers

extension OperationDialogTests {
    /// 用这个偏好域打开获取对话框，依次按下这些控件，读到满足条件为止。
    private static func fetchElements(
        _ request: RepositoryActionRequest,
        in session: RepositorySession,
        defaults: UserDefaults,
        pressing names: [String],
        until isComplete: @escaping ([AccessibilityProbe.Element]) -> Bool
    ) async -> [AccessibilityProbe.Element] {
        await AccessibilityProbe.elements(pressing: names, until: isComplete) {
            RepositoryOperationDialog(
                session: session,
                request: request,
                cancel: { },
                submit: { _, _, _, _, _ in false }
            )
            .defaultAppStorage(defaults)
        }
    }

    /// 这个标题的勾选框的值，“1” 为勾选；没有这个勾选框时为 nil。
    private static func checkBox(_ name: String, in elements: [AccessibilityProbe.Element]) -> String? {
        elements.first { $0.role == "AXCheckBox" && $0.name == name }?.value
    }
}
