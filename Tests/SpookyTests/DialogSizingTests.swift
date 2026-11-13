import AppKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky

// MARK: - DialogSizingTests

/// 经 `DialogWindow` 挂成 sheet 的对话框：窗口尺寸由骨架报上的理想尺寸驱动，显示前就排成理想尺寸，
/// 显示期间内容变高、变矮时窗口跟着变到新的理想尺寸；可以拉大的对话框收起选项区时减去它的高度，再展开时回到收起前的高度。
@MainActor
struct DialogSizingTests {
    /// 挂上时的尺寸、错误区出现与内容区加行后的尺寸，以及可以拉大的窗口切换选项区。
    @Test("对话框窗口的尺寸跟随内容")
    func windowFollowsContent() async throws {
        let parent = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        parent.isReleasedWhenClosed = false
        parent.orderFront(nil)
        defer { parent.close() }

        // 挂上时已是理想尺寸
        let model = Model()
        DialogWindow.present(on: parent) { _ in ProbeDialog(model: model) }

        let sheet = try await PromptDialogTests.attachedSheet(of: parent)

        #expect(Self.contentSize(of: sheet) == Self.idealSize(of: model))

        // 错误区出现由骨架带上动画，内容区加行经 `DialogAnimation`；窗口最后都停在新的理想尺寸
        model.error = "The name is already in use."

        let withError = Self.idealSize(of: model)

        await until { Self.contentSize(of: sheet) == withError }

        DialogAnimation.perform { model.rows = 3 }

        let withRows = Self.idealSize(of: model)

        #expect(withRows.height > withError.height)

        await until { Self.contentSize(of: sheet) == withRows }

        parent.endSheet(sheet)
        await until { parent.attachedSheet == nil }

        // 可以拉大的窗口：收起时减去选项区的高度，展开时回到收起前的高度
        let resizable = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )

        let sizing = DialogSizing(window: resizable)

        sizing.toggleOptions(expanded: false, optionsHeight: 150)

        #expect(Self.contentSize(of: resizable).height == 250)

        sizing.toggleOptions(expanded: true, optionsHeight: 150)

        #expect(Self.contentSize(of: resizable).height == 400)
    }
}

// MARK: - Helpers

extension DialogSizingTests {
    /// 窗口内容区的尺寸。
    private static func contentSize(of window: NSWindow) -> CGSize {
        window.contentRect(forFrameRect: window.frame).size
    }

    /// 对话框内容按理想尺寸排出的大小。
    private static func idealSize(of model: Model) -> CGSize {
        NSHostingController(rootView: ProbeDialog(model: model)).sizeThatFits(in: DialogSizing.unconstrained)
    }
}

// MARK: - Model

/// 测试对话框的状态：错误与内容区的行数。
@MainActor
@Observable
private final class Model {
    /// 错误区的文字；为 nil 时错误区收起。
    var error: String? = nil

    /// 内容区的行数。
    var rows = 1
}

// MARK: - ProbeDialog

/// 内容区是若干 30 pt 高的行的对话框。
private struct ProbeDialog: View {
    /// 对话框的状态。
    let model: Model

    /// 骨架的表单版。
    var body: some View {
        DialogLayout(
            title: "Rename",
            message: "Enter a new name.",
            submitTitle: "Rename",
            error: model.error,
            cancel: { },
            submit: { },
            content: {
                VStack(spacing: 0) {
                    ForEach(0 ..< model.rows, id: \.self) { index in
                        Text(verbatim: "Row \(index)")
                            .frame(height: 30)
                    }
                }
            }
        )
    }
}
