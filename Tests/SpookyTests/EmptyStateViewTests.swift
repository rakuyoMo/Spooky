import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - EmptyStateViewTests

/// 空状态：标题、说明与按钮行相隔 8，标题 18 pt、中心比容器中心低 32，说明为空时仍留一行；背景是铺满容器的 `contentBackground` 材质；
/// 按钮是工具栏样式、标题为次要标签色。
///
/// 文字与按钮的位置经辅助功能接口读取，进程没有辅助功能权限时跳过这一项。
@MainActor
struct EmptyStateViewTests {
    /// 容器的宽与高。
    private static let size = CGSize(width: 480, height: 400)

    /// 标题是 18 pt，中心比容器中心低 32，说明在标题下方 8，按钮行在说明下方 8；
    /// 没有图标时标题仍在同一位置，说明为空时留出一行 13 pt 文字的高度，按钮行在这一行下方 8。
    @Test("位置、间距与标题字号", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func layout() async throws {
        let full = await Self.elements {
            EmptyStateView(title: "Title", message: "Message", symbol: "doc") {
                EmptyStateButton("Action") { }
            }
        }

        let title = try #require(Self.text("Title", in: full))
        let message = try #require(Self.text("Message", in: full))
        let button = try #require(full.first { $0.role == "AXButton" })
        let titleHeight = NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: 18))

        #expect(abs(title.frame.height - titleHeight) <= 1)
        #expect(abs(title.frame.midY - Self.containerCenter - 32) <= 1)
        #expect(abs(message.frame.minY - title.frame.maxY - 8) <= 1)
        #expect(abs(button.frame.minY - message.frame.maxY - 8) <= 2)
        #expect(abs(button.frame.midX - Self.size.width / 2) <= 1)

        // 没有图标与说明
        let omitted = await Self.elements {
            EmptyStateView(title: "Title", message: "", symbol: nil) {
                EmptyStateButton("Action") { }
            }
        }

        let bareTitle = try #require(Self.text("Title", in: omitted))
        let bareButton = try #require(omitted.first { $0.role == "AXButton" })
        let lineHeight = NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: 13))

        #expect(abs(bareTitle.frame.midY - Self.containerCenter - 32) <= 1)
        #expect(abs(bareButton.frame.minY - bareTitle.frame.maxY - 8 - lineHeight - 8) <= 2)
    }

    /// 按钮是工具栏样式，标题为次要标签色，`disabled` 让按钮不可用，按下执行它的动作；
    /// 窗口内容延伸到工具栏下面时，`contentBackground` 材质的背景同样铺到工具栏下面，占满整个容器。
    @Test("按钮与背景")
    func buttonsAndBackground() throws {
        var pressed = false

        let window = NSWindow(
            contentRect: NSRect(origin: CGPoint(x: -3000, y: -3000), size: Self.size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.toolbar = NSToolbar(identifier: "empty-state-tests")
        defer { window.close() }

        let hosting = NSHostingView(
            rootView: EmptyStateView(title: "Title", message: "", symbol: "doc") {
                EmptyStateButton("Enabled") { pressed = true }
                EmptyStateButton("Disabled") { }
                    .disabled(true)
            }
        )

        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        // 按钮
        let buttons = Self.subviews(NSButton.self, in: hosting)
        let enabled = try #require(buttons.first { $0.title == "Enabled" })
        let disabled = try #require(buttons.first { $0.title == "Disabled" })
        let color = enabled.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor

        #expect(enabled.bezelStyle == .toolbar)
        #expect(color == .secondaryLabelColor)
        #expect(enabled.isEnabled)
        #expect(!disabled.isEnabled)

        enabled.performClick(nil)

        #expect(pressed)

        // 背景
        let background = try #require(Self.subviews(NSVisualEffectView.self, in: hosting).first)

        #expect(background.material == .contentBackground)
        #expect(hosting.safeAreaInsets.top > 0)
        #expect(background.convert(background.bounds, to: hosting).size == Self.size)
    }
}

// MARK: - Helpers

extension EmptyStateViewTests {
    /// 容器中心在窗口坐标里的纵坐标：辅助功能接口读到的位置从窗口左上角算起，含标题栏。
    private static var containerCenter: CGFloat {
        let content = NSRect(origin: .zero, size: size)
        let titleBar = NSWindow.frameRect(forContentRect: content, styleMask: [.titled]).height - size.height

        return titleBar + size.height / 2
    }

    /// 把空状态放进固定大小的容器，读出其中的元素；等到标题与按钮都读到为止。
    private static func elements(@ViewBuilder of content: () -> some View) async -> [AccessibilityProbe.Element] {
        await AccessibilityProbe.elements(
            width: size.width,
            until: { elements in
                text("Title", in: elements) != nil && elements.contains { $0.role == "AXButton" }
            }
        ) {
            content()
                .frame(height: size.height)
        }
    }

    /// 文字是给定内容的静态文字元素。
    private static func text(
        _ value: String,
        in elements: [AccessibilityProbe.Element]
    ) -> AccessibilityProbe.Element? {
        elements.first { $0.role == "AXStaticText" && $0.value == value }
    }

    /// 视图树里给定类型的全部子视图。
    private static func subviews<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + subviews(Element.self, in: child)
        }
    }
}
