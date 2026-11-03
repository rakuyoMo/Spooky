import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - EmptyStateViewTests

/// 空状态：标题、说明与按钮行相隔 8，标题 18 pt、中心比容器中心低 32，说明为空时仍留一行；背景是铺满容器的 `contentBackground` 材质；
/// 按钮是工具栏样式、标题为次要标签色。
///
/// 文字与按钮的位置经辅助功能接口读取，进程没有辅助功能权限时跳过这几项。
@MainActor
struct EmptyStateViewTests {
    /// 容器的宽与高。
    private static let size = CGSize(width: 480, height: 400)

    /// 标题中心比容器中心低 32，说明在标题下方 8，按钮行在说明下方 8。
    @Test("位置与间距", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func layout() throws {
        let elements = Self.elements {
            EmptyStateView(title: "Title", message: "Message", symbol: "doc") {
                EmptyStateButton("Action") { }
            }
        }

        let title = try #require(Self.text("Title", in: elements))
        let message = try #require(Self.text("Message", in: elements))
        let button = try #require(elements.first { $0.role == "AXButton" })

        #expect(abs(title.frame.midY - Self.containerCenter - 32) <= 1)
        #expect(abs(message.frame.minY - title.frame.maxY - 8) <= 1)
        #expect(abs(button.frame.minY - message.frame.maxY - 8) <= 2)
        #expect(abs(button.frame.midX - Self.size.width / 2) <= 1)
    }

    /// 标题是 18 pt：文字的高度等于 18 pt 系统字体的行高。
    @Test("标题字号", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func titleFont() throws {
        let elements = Self.elements(withButton: false) {
            EmptyStateView(title: "Title", message: "Message", symbol: nil)
        }

        let title = try #require(Self.text("Title", in: elements))
        let lineHeight = NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: 18))

        #expect(abs(title.frame.height - lineHeight) <= 1)
    }

    /// 没有图标时标题仍在同一位置；说明为空时留出一行 13 pt 文字的高度，按钮行在这一行下方 8。
    @Test("没有图标与说明", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func omittedParts() throws {
        let elements = Self.elements {
            EmptyStateView(title: "Title", message: "", symbol: nil) {
                EmptyStateButton("Action") { }
            }
        }

        let title = try #require(Self.text("Title", in: elements))
        let button = try #require(elements.first { $0.role == "AXButton" })
        let lineHeight = NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: 13))

        #expect(abs(title.frame.midY - Self.containerCenter - 32) <= 1)
        #expect(abs(button.frame.minY - title.frame.maxY - 8 - lineHeight - 8) <= 2)
    }

    /// 按钮是工具栏样式，标题为次要标签色；`disabled` 让按钮不可用。
    @Test("按钮样式")
    func buttonStyle() throws {
        let hosting = Self.hosting {
            EmptyStateView(title: "Title", message: "", symbol: nil) {
                EmptyStateButton("Enabled") { }
                EmptyStateButton("Disabled") { }
                    .disabled(true)
            }
        }

        let buttons = Self.subviews(NSButton.self, in: hosting)
        let enabled = try #require(buttons.first { $0.title == "Enabled" })
        let disabled = try #require(buttons.first { $0.title == "Disabled" })
        let color = enabled.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor

        #expect(enabled.bezelStyle == .toolbar)
        #expect(color == .secondaryLabelColor)
        #expect(enabled.isEnabled)
        #expect(!disabled.isEnabled)
    }

    /// 按下按钮执行它的动作。
    @Test("按钮动作")
    func buttonAction() throws {
        var pressed = false

        let hosting = Self.hosting {
            EmptyStateView(title: "Title", message: "", symbol: nil) {
                EmptyStateButton("Action") { pressed = true }
            }
        }

        let button = try #require(Self.subviews(NSButton.self, in: hosting).first)
        button.performClick(nil)

        #expect(pressed)
    }

    /// 背景是 `contentBackground` 材质，铺满整个容器。
    @Test("背景材质")
    func background() throws {
        let hosting = Self.hosting {
            EmptyStateView(title: "Title", message: "", symbol: "doc")
        }

        let background = try #require(Self.subviews(NSVisualEffectView.self, in: hosting).first)

        #expect(background.material == .contentBackground)
        #expect(background.convert(background.bounds, to: hosting).size == Self.size)
    }
}

// MARK: - Safe Area

extension EmptyStateViewTests {
    /// 窗口内容延伸到工具栏下面时，空状态的背景同样铺到工具栏下面，占满整个内容视图的高度。
    @Test("延伸到工具栏下面")
    func underToolbar() throws {
        let window = NSWindow(
            contentRect: NSRect(origin: CGPoint(x: -3000, y: -3000), size: Self.size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.toolbar = NSToolbar(identifier: "empty-state-tests")

        let hosting = NSHostingView(rootView: EmptyStateView(title: "Title", message: "", symbol: "doc"))
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        defer { window.close() }

        let background = try #require(Self.subviews(NSVisualEffectView.self, in: hosting).first)

        #expect(hosting.safeAreaInsets.top > 0)
        #expect(abs(background.convert(background.bounds, to: hosting).height - hosting.bounds.height) <= 0.5)
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
    private static func elements(
        withButton: Bool = true,
        @ViewBuilder of content: () -> some View
    ) -> [AccessibilityProbe.Element] {
        AccessibilityProbe.elements(
            width: size.width,
            until: { elements in
                text("Title", in: elements) != nil
                    && (!withButton || elements.contains { $0.role == "AXButton" })
            }
        ) {
            content()
                .frame(height: size.height)
        }
    }

    /// 放进固定大小、排好版的视图。
    private static func hosting(@ViewBuilder of content: () -> some View) -> NSView {
        let hosting = NSHostingView(rootView: content().frame(width: size.width, height: size.height))
        hosting.frame.size = size
        hosting.layoutSubtreeIfNeeded()

        return hosting
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
