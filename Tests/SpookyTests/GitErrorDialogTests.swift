import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - GitErrorDialogTests

/// Git 错误框与几处提示版：错误框的原文区默认展开、随窗口变大，底栏只有 Close，打开失败时另有 Choose Another Folder…；
/// 断线后的恢复说明、无效链接与 Local Folder 的提示只有 Close。
@MainActor
struct GitErrorDialogTests {
    /// 原文区写出 Git 原文；对话框拉高、拉宽时，多出的高度与宽度都交给原文区。
    @Test("原文区随对话框变大")
    func detailsGrowWithDialog() throws {
        let failure = AppFailure(
            error: FailurePresentationTests.gitError(.indexLocked, ["add", "--", "a.txt"]),
            opening: false,
            location: nil
        )

        let hosting = NSHostingView(rootView: GitErrorDialog(failure: failure, close: { }, chooseAnother: nil))
        hosting.frame.size = hosting.fittingSize
        hosting.layoutSubtreeIfNeeded()

        let text = try #require(Self.textView(in: hosting))
        let scroll = try #require(text.enclosingScrollView)
        let original = scroll.frame.size

        #expect(text.string == failure.details)
        #expect(abs(original.height - 135) <= 1)
        #expect(abs(hosting.frame.width - 480) <= 1)

        let fitting = hosting.frame.size

        hosting.frame.size = NSSize(width: fitting.width, height: fitting.height + 200)
        hosting.layoutSubtreeIfNeeded()

        #expect(abs(scroll.frame.height - original.height - 200) <= 1)

        // 拉宽后说明折行变少，只核对宽度
        hosting.frame.size = NSSize(width: fitting.width + 100, height: fitting.height)
        hosting.layoutSubtreeIfNeeded()

        #expect(abs(scroll.frame.width - original.width - 100) <= 1)
    }

    /// 其余失败的底栏只有 Close；打开失败时 Close 左侧另有 Choose Another Folder…；说明后空一行是类别与仓库，
    /// “Git Error Message” 默认展开。
    @Test("错误框的按钮与原文区", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func buttonsAndDetails() async throws {
        let failure = AppFailure(
            error: FailurePresentationTests.gitError(.commandFailed, ["status"]),
            opening: true,
            location: nil
        )

        let other = await AccessibilityProbe.elements(until: { Self.buttons(in: $0).count == 1 }) {
            GitErrorDialog(failure: failure, close: { }, chooseAnother: nil)
        }

        let toggleTitle = AppLocalization.text("error.gitMessage")
        let message = failure.message + "\n\n" + failure.context
        let toggle = try #require(other.first { $0.role == "AXCheckBox" && $0.name == toggleTitle })

        #expect(Self.buttons(in: other).map(\.name) == [AppLocalization.text("action.close")])
        #expect(toggle.value == "1")
        #expect(other.contains { $0.role == "AXStaticText" && $0.value == message })
        #expect(other.contains { $0.role == "AXTextArea" && $0.value == failure.details })

        let opening = await AccessibilityProbe.elements(until: { Self.buttons(in: $0).count == 2 }) {
            GitErrorDialog(failure: failure, close: { }, chooseAnother: { })
        }

        #expect(
            Self.buttons(in: opening).map(\.name) == ["action.chooseAnother", "action.close"]
                .map { AppLocalization.text($0) }
        )
    }

    /// 断线后的恢复说明以核对结果开头；仓库设置里 Local Folder 核对没通过时，说明写出选的目录；
    /// 无效的 `spooky://` 链接的说明写出链接原文；三者都是只有 Close 的提示版。
    @Test("恢复说明、Local Folder 与无效链接的提示只有 Close")
    func notices() throws {
        let write = InterruptedWrite(title: "Push", branch: nil, time: Date())
        let recovery = RepositoryWindowController.recoveryNotice(write, snapshot: nil, in: nil) { }

        #expect(recovery.message.hasPrefix(AppLocalization.text("recovery.notStarted", "Push")))
        Self.expectCloseOnly(recovery)

        // Local Folder
        let folder = FileManager.default.temporaryDirectory.appending(path: "elsewhere")
        let rejection = RepositoryLocalFolderRow(session: RepositorySession()).rejectionNotice(of: folder) { }

        #expect(rejection.message.contains(HomePath.abbreviated(folder.path)))
        Self.expectCloseOnly(rejection)

        // 无效链接
        let url = try #require(URL(string: "spooky://delete?x=1"))
        let link = SpookyApplicationController.invalidLinkNotice(for: url) { }

        #expect(link.message.contains(url.absoluteString))
        Self.expectCloseOnly(link)
    }
}

// MARK: - Helpers

extension GitErrorDialogTests {
    /// 提示版：没有内容区与选项区的骨架。
    private typealias Notice = DialogLayout<EmptyView, EmptyView>

    /// Git 错误框记住尺寸用的偏好键。
    static let frameKey = "NSWindow Frame GitErrorDialog"

    /// 提示版：没有取消按钮，主按钮是 Close。
    private static func expectCloseOnly(_ notice: Notice) {
        #expect(notice.cancel == nil)
        #expect(notice.alternate == nil)
        #expect(notice.submitTitle == AppLocalization.text("action.close"))
    }

    /// 底栏的按钮，自左向右；不含标题栏上的窗口按钮与隐藏的 ⎋ 按钮。
    private static func buttons(in elements: [AccessibilityProbe.Element]) -> [AccessibilityProbe.Element] {
        elements
            .filter { $0.role == "AXButton" && $0.frame.minY > 30 && !$0.name.isEmpty }
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    /// 视图树里的第一个文本视图。
    private static func textView(in view: NSView) -> NSTextView? {
        if let text = view as? NSTextView {
            return text
        }

        return view.subviews.lazy.compactMap { textView(in: $0) }.first
    }
}
