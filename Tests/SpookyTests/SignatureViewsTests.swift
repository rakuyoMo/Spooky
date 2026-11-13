import AppKit
import Foundation
import SpookyKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky

// MARK: - SignatureViewsTests

/// 标签签名弹窗：校验结果晚于弹窗出现，弹窗要跟着结果变大，否则用户只看到被截成 “…” 的结果。
@MainActor
struct SignatureViewsTests {
    /// 对没有签名的标签打开签名弹窗：结果到达后，弹窗宽到放得下整句说明与两侧各 20 pt 的边距。
    @Test("标签签名弹窗随校验结果变大")
    func tagPopoverFitsResult() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))

        _ = try await runner.run(["commit", "--allow-empty", "-m", "base"])
        _ = try await runner.run(["tag", "v1.0"])

        let window = NSWindow(
            contentRect: NSRect(x: 400, y: 200, width: 300, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: Color.clear
                .frame(width: 300, height: 200)
                .popover(isPresented: .constant(true), arrowEdge: .leading) {
                    TagSignaturePopover(reference: "refs/tags/v1.0", runner: runner)
                }
        )

        window.orderFront(nil)
        defer { window.close() }

        // 弹窗打开时内容是转圈，校验结果到达后内容变宽，弹窗跟着变宽
        let text = NSAttributedString(
            string: AppLocalization.text("signature.unsigned"),
            attributes: [.font: NSFont.systemFont(ofSize: 13)]
        )

        let width = text.size().width + 40

        await until {
            NSApp.windows.contains { popover in
                popover.parent === window && (popover.contentView?.frame.width ?? 0) >= width
            }
        }
    }
}
