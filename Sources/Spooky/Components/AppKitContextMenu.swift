import AppKit
import SwiftUI

// MARK: - AppKitContextMenu

/// 给 SwiftUI 视图挂上 AppKit 的右键菜单，菜单在每次弹出时生成；用于菜单项缩进这类 SwiftUI 菜单做不到的样式。
///
/// 盖在视图上的透明视图只接右键与 ⌃ 点按，其余点按、悬停与拖动照常交给下面的视图。
struct AppKitContextMenu: NSViewRepresentable {
    /// 生成菜单。
    let makeMenu: @MainActor () -> NSMenu

    /// 创建接右键的透明视图。
    func makeNSView(context _: Context) -> MenuHostView {
        MenuHostView()
    }

    /// 每次刷新换上最新的生成方法，菜单按弹出时的状态生成。
    func updateNSView(_ view: MenuHostView, context _: Context) {
        view.makeMenu = makeMenu
    }
}

// MARK: AppKitContextMenu.MenuHostView

extension AppKitContextMenu {
    /// 接右键的透明视图。
    final class MenuHostView: NSView {
        /// 生成菜单；还没有设置时不弹出菜单。
        var makeMenu: (@MainActor () -> NSMenu)? = nil

        /// 是不是弹出右键菜单的点按：右键，或按住 ⌃ 的左键。
        static func isContextClick(_ event: NSEvent) -> Bool {
            switch event.type {
            case .rightMouseDown, .rightMouseUp: true
            case .leftMouseDown, .leftMouseUp: event.modifierFlags.contains(.control)
            default: false
            }
        }

        /// 只在右键与 ⌃ 点按时接住事件，其余事件穿过去。
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent, Self.isContextClick(event) else {
                return nil
            }

            return super.hitTest(point)
        }

        /// 右键与 ⌃ 点按时弹出的菜单。
        override func menu(for _: NSEvent) -> NSMenu? {
            makeMenu?()
        }
    }
}

// MARK: - View

extension View {
    /// 挂上 AppKit 的右键菜单，见 ``AppKitContextMenu``。
    ///
    /// - Parameter makeMenu: 每次弹出时生成菜单。
    func appKitContextMenu(_ makeMenu: @escaping @MainActor () -> NSMenu) -> some View {
        overlay(AppKitContextMenu(makeMenu: makeMenu))
    }
}
