import AppKit
import SwiftUI

// MARK: - AppKitContextMenu

/// 给 `List` 的行挂上 AppKit 的右键菜单，菜单在每次弹出时生成；用于菜单项缩进这类 SwiftUI 菜单做不到的样式。
///
/// 右键或 ⌃ 点按这一行的任意位置时，菜单经 List 背后的表格弹出，表格在菜单打开期间给这一行画右键高亮框，与其它行一致。
/// 表格只为挂了 SwiftUI 右键菜单的行给出菜单，所以同一份菜单项也以 ``AppKitMenuItems`` 挂在行上，旁白的 “显示菜单” 打开的是它。
struct AppKitContextMenu: NSViewRepresentable {
    /// 生成菜单。
    let makeMenu: @MainActor () -> NSMenu

    /// 创建监听右键的透明视图。
    func makeNSView(context _: Context) -> RowMenuView {
        RowMenuView()
    }

    /// 每次刷新换上最新的生成方法，菜单按弹出时的状态生成。
    func updateNSView(_ view: RowMenuView, context _: Context) {
        view.makeMenu = makeMenu
    }
}

// MARK: AppKitContextMenu.RowMenuView

extension AppKitContextMenu {
    /// 不接点按的透明视图：在窗口里时监听本窗口的右键与 ⌃ 点按，落在自己所在的行上就弹出菜单并吞掉这次点按。
    final class RowMenuView: NSView {
        /// 生成菜单；还没有设置时不弹出菜单。
        var makeMenu: (@MainActor () -> NSMenu)? = nil

        /// 本地事件监听；不在窗口里时为 nil。
        private var monitor: Any?

        /// 是不是弹出右键菜单的点按：右键，或按住 ⌃ 的左键。
        static func isContextClick(_ event: NSEvent) -> Bool {
            switch event.type {
            case .rightMouseDown: true
            case .leftMouseDown: event.modifierFlags.contains(.control)
            default: false
            }
        }

        /// 停止监听。
        isolated deinit {
            stopMonitoring()
        }

        /// 点按全部穿过去，单击、双击与悬停提示照常交给下面的视图。
        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }

        /// 进入窗口时开始监听本窗口的点按，离开时停止。
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            stopMonitoring()

            guard window != nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(
                matching: [.rightMouseDown, .leftMouseDown]
            ) { [weak self] event in
                let shown = MainActor.assumeIsolated {
                    self?.showMenuIfOnRow(event) ?? false
                }

                return shown ? nil : event
            }
        }

        /// 是否落在本视图所在行上的右键或 ⌃ 点按；点按要在本窗口里，窗口也没有挂着表单。
        func isContextClick(onRowOf table: NSTableView, _ event: NSEvent) -> Bool {
            guard
                Self.isContextClick(event),
                let window,
                event.window === window,
                window.attachedSheet == nil
            else {
                return false
            }

            // 按窗口命中的视图找行：盖在行上的悬浮组标题这类视图不属于这一行
            guard let hit = window.contentView?.superview?.hitTest(event.locationInWindow) else {
                return false
            }

            let row = table.row(for: self)
            return row >= 0 && table.row(for: hit) == row
        }

        /// 弹出菜单的视图：表格为这次点按给出菜单时是表格，表格由此记下点按的行，菜单打开期间给它画高亮框；否则是自己。
        func menuTarget(for event: NSEvent, in table: NSTableView) -> NSView {
            table.menu(for: event) == nil ? self : table
        }
    }
}

// MARK: - Private

extension AppKitContextMenu.RowMenuView {
    /// 所在的表格；不在表格里时为 nil，这时由行上的 SwiftUI 右键菜单处理点按。
    private var enclosingTable: NSTableView? {
        sequence(first: self as NSView, next: \.superview)
            .first { $0 is NSTableView } as? NSTableView
    }

    /// 点按落在本视图所在的行上时弹出菜单，返回是否弹出。
    private func showMenuIfOnRow(_ event: NSEvent) -> Bool {
        guard
            let table = enclosingTable,
            isContextClick(onRowOf: table, event),
            let menu = makeMenu?()
        else {
            return false
        }

        NSMenu.popUpContextMenu(menu, with: event, for: menuTarget(for: event, in: table))
        return true
    }

    /// 移除事件监听。
    private func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        monitor = nil
    }
}

// MARK: - AppKitMenuItems

/// 把 AppKit 菜单的项目画成 SwiftUI 菜单内容：缩进不保留，按住修饰键时的替换项挂在前一项上，打勾的项目画成开关。
struct AppKitMenuItems: View {
    /// 生成菜单；SwiftUI 构建菜单内容时才调用。
    let makeMenu: @MainActor () -> NSMenu

    /// 依次画出各项，替换项随前一项画出。
    var body: some View {
        let items = makeMenu().items

        ForEach(items.indices, id: \.self) { index in
            let item = items[index]
            let next = items.indices.contains(index + 1) ? items[index + 1] : nil

            if item.isSeparatorItem {
                Divider()
            } else if let submenu = item.submenu {
                Menu(item.title) {
                    Self { submenu }
                }
                .disabled(!item.isEnabled)
            } else if !item.isAlternate {
                Self.entry(item, alternate: next)
            }
        }
    }
}

// MARK: - AppKitMenuItems.Private

extension AppKitMenuItems {
    /// 一个菜单项；下一项是它的替换项时，按住替换项的修饰键就换成它。
    @ViewBuilder
    private static func entry(_ item: NSMenuItem, alternate: NSMenuItem?) -> some View {
        if let alternate, alternate.isAlternate {
            button(item)
                .modifierKeyAlternate(modifiers(alternate.keyEquivalentModifierMask)) {
                    button(alternate)
                }
        } else {
            button(item)
        }
    }

    /// 执行菜单项动作的按钮；打勾的项目画成打开的开关。
    @ViewBuilder
    private static func button(_ item: NSMenuItem) -> some View {
        if item.state == .on {
            Toggle(
                item.title,
                isOn: Binding(
                    get: { true },
                    set: { _ in perform(item) }
                )
            )
            .disabled(!item.isEnabled)
        } else {
            Button(item.title) {
                perform(item)
            }
            .disabled(!item.isEnabled)
        }
    }

    /// 像 AppKit 菜单一样把菜单项的动作发给它的目标。
    private static func perform(_ item: NSMenuItem) {
        guard let action = item.action else {
            return
        }

        NSApp.sendAction(action, to: item.target, from: item)
    }

    /// AppKit 的修饰键换成 SwiftUI 的写法。
    private static func modifiers(_ flags: NSEvent.ModifierFlags) -> EventModifiers {
        let pairs: [(NSEvent.ModifierFlags, EventModifiers)] = [
            (.command, .command),
            (.option, .option),
            (.control, .control),
            (.shift, .shift),
        ]

        return pairs.reduce(into: []) { result, pair in
            if flags.contains(pair.0) {
                result.insert(pair.1)
            }
        }
    }
}

// MARK: - View

extension View {
    /// 给 `List` 的行挂上 AppKit 的右键菜单，见 ``AppKitContextMenu``。
    ///
    /// - Parameter makeMenu: 每次弹出时生成菜单。
    func appKitContextMenu(_ makeMenu: @escaping @MainActor () -> NSMenu) -> some View {
        background(AppKitContextMenu(makeMenu: makeMenu))
            .contextMenu {
                AppKitMenuItems(makeMenu: makeMenu)
            }
    }
}
