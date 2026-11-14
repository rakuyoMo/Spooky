import AppKit

// MARK: - ReferenceFilterMenu

/// 选择引用的菜单：顶部是过滤框，接着是当前的引用（打勾）、分隔线，再是其它引用；输入文字时只留名字含这段文字的项。
///
/// Branches Review 的基准分支与 Reflog 的引用共用。
@MainActor
final class ReferenceFilterMenu: NSObject {
    /// 菜单里的一项引用。
    struct Entry: Equatable {
        /// 完整引用名，选中时交回。
        let id: String

        /// 菜单里显示的名称。
        let title: String
    }

    /// 弹出按钮用的菜单。
    let menu = NSMenu()

    /// 当前引用的菜单项；没有时是不可选的占位项。
    private(set) var currentItem: NSMenuItem? = nil

    /// 选了另一项引用，参数是它的完整引用名。
    var select: (String) -> Void = { _ in }

    /// 菜单顶部的过滤框。
    let field = NSSearchField()

    /// 上次建菜单时的引用与当前项，没变时不重建。
    private var built: [String]? = nil

    /// 建出带过滤框的空菜单。
    override init() {
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false

        field.delegate = self
        field.placeholderString = AppLocalization.text("sidebar.filter")
        field.sendsSearchStringImmediately = true
    }

    /// 按引用与当前项重建菜单；与上次相同时不动。
    ///
    /// - Parameters:
    ///   - entries: 全部引用，按显示顺序。
    ///   - current: 当前的引用。
    ///   - emptyTitle: 没有当前引用时占位项的标题。
    func rebuild(entries: [Entry], current: Entry?, emptyTitle: String) {
        let key = [current?.id ?? ""] + entries.map(\.id)

        guard key != built else {
            return
        }

        built = key
        menu.removeAllItems()
        menu.addItem(fieldItem())

        // 当前引用在过滤框下面，与其它引用用分隔线隔开
        if let current {
            currentItem = entryItem(current)
        } else {
            currentItem = NSMenuItem(title: emptyTitle, action: nil, keyEquivalent: "")
            currentItem?.isEnabled = false
        }

        if let currentItem {
            menu.addItem(currentItem)
        }

        menu.addItem(.separator())

        for entry in entries where entry.id != current?.id {
            menu.addItem(entryItem(entry))
        }
    }

    /// 只留名字含这段文字的项，不分大小写；文字为空时全部显示，有文字时分隔线隐藏。
    ///
    /// - Parameter text: 过滤框里的文字。
    func filter(_ text: String) {
        for item in menu.items where item.view == nil {
            if item.isSeparatorItem {
                item.isHidden = !text.isEmpty
            } else {
                item.isHidden = !text.isEmpty && !item.title.localizedCaseInsensitiveContains(text)
            }
        }
    }

    /// 选中一项引用。
    @objc
    private func choose(_ item: NSMenuItem) {
        guard let id = item.representedObject as? String else {
            return
        }

        select(id)
    }
}

// MARK: NSMenuDelegate

extension ReferenceFilterMenu: NSMenuDelegate {
    /// 打开菜单时让过滤框拿到键盘输入；菜单跟踪期间只跑事件跟踪模式。
    func menuWillOpen(_: NSMenu) {
        RunLoop.main.perform(inModes: [.eventTracking]) { [field] in
            field.window?.makeFirstResponder(field)
        }
    }

    /// 关闭菜单后清空过滤文字，下次打开时列出全部引用。
    func menuDidClose(_: NSMenu) {
        field.stringValue = ""
        filter("")
    }
}

// MARK: NSSearchFieldDelegate

extension ReferenceFilterMenu: NSSearchFieldDelegate {
    /// 每输入一个字就重新过滤。
    func controlTextDidChange(_: Notification) {
        filter(field.stringValue)
    }
}

// MARK: - Private

extension ReferenceFilterMenu {
    /// 放过滤框的菜单项，左右留出与菜单文字对齐的边距。
    private func fieldItem() -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        field.frame = NSRect(x: 12, y: 4, width: 196, height: 22)
        field.autoresizingMask = [.width]
        container.addSubview(field)

        let item = NSMenuItem()
        item.view = container

        return item
    }

    /// 一项引用的菜单项。
    private func entryItem(_ entry: Entry) -> NSMenuItem {
        let item = NSMenuItem(title: entry.title, action: #selector(choose(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = entry.id

        return item
    }
}
