import AppKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky

// MARK: - SettingsWindowTests

/// 设置窗口与设置页里的原生控件：打开时的焦点、弹出菜单的图标、Editor 随折行方式停用的组合框、Environment 的变量表与输入框的可见边框。
@MainActor
struct SettingsWindowTests {
    /// General 页的组合框是第一个可输入的控件；窗口打开时焦点不能落进去，否则一打开就在编辑阈值。
    @Test("打开设置窗口时焦点不在输入框里")
    func noInitialFocus() throws {
        let controller = SettingsWindowController()
        defer { controller.close() }

        controller.showWindow(nil)

        let window = try #require(controller.window)
        #expect(window.firstResponder === window)
    }

    /// 弹出菜单拿到的图标是 16 × 16 pt；改的是新取的一份，系统再给出的图标仍是原来的尺寸。
    @Test("菜单图标按 16 × 16 pt 取，不改动系统给出的图标")
    func menuIcon() {
        let path = NSHomeDirectory()
        let icon = NSWorkspace.shared.menuIcon(forFile: path)

        #expect(icon.size == NSSize(width: 16, height: 16))
        #expect(NSWorkspace.shared.icon(forFile: path).size != icon.size)
    }

    /// 正文的字数上限只在硬折行时生效：软折行时它的组合框停用，换成硬折行后可用；标题的字数上限不受影响。
    @Test("Editor 页软折行时停用正文字数上限")
    func editorBodyLimitFollowsWrapping() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.editor." + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defer { try? FileManager.default.removeItem(at: directory) }

        defaults.set(CommitEditorSettings.Wrapping.soft.rawValue, forKey: CommitEditorSettings.wrappingKey)

        let window = Self.host(EditorSettingsView().defaultAppStorage(defaults))
        defer { window.close() }

        let boxes = Self.subviews(NSComboBox.self, in: try #require(window.contentView))
        try #require(boxes.count == 2)
        #expect(boxes[0].isEnabled)
        #expect(!boxes[1].isEnabled)

        defaults.set(CommitEditorSettings.Wrapping.hard.rawValue, forKey: CommitEditorSettings.wrappingKey)
        await until { boxes[1].isEnabled }
    }

    /// 两张变量表都是行高 24 pt、变量名一列 260 pt、行间画实线；在自定义变量表里结束编辑一个格子，整张表立即保存；
    /// 按 Tab 移到同一行另一格的编辑不被随后的同步打断。
    @Test("Environment 的变量表：网格、列宽与编辑后保存")
    func environmentTables() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.environment-table." + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defer { try? FileManager.default.removeItem(at: directory) }

        let preferences = LocalExecutionPreferences(
            defaults: defaults,
            readLoginShell: { ["EDITOR": "nano"] },
            apply: { _ in }
        )
        preferences.saveCustomVariables([CustomEnvironmentVariable(name: "TOKEN", value: "旧值")])
        preferences.setUsesLoginShell(true)

        let window = Self.host(EnvironmentSettingsView(preferences: preferences))
        defer { window.close() }

        let content = try #require(window.contentView)
        let custom = AppLocalization.text("settings.environment.custom")

        // 登录 shell 的变量读完、自定义变量随页面出现载入后，两张表都有一行
        await until {
            let tables = Self.subviews(NSTableView.self, in: content)
            return tables.count == 2 && tables.allSatisfy { $0.numberOfRows == 1 }
        }

        let tables = Self.subviews(NSTableView.self, in: content)

        for table in tables {
            #expect(table.gridStyleMask == .solidHorizontalGridLineMask)
            #expect(table.rowHeight == 24)
            #expect(table.tableColumns.first?.width == 260)
        }

        // 改写自定义变量的值，结束编辑即写进偏好
        let table = try #require(tables.first { $0.accessibilityLabel() == custom })
        let cell = try #require(table.view(atColumn: 1, row: 0, makeIfNecessary: true) as? NSTableCellView)
        let field = try #require(cell.textField)

        field.stringValue = "新值"

        let notification = Notification(name: NSControl.textDidEndEditingNotification, object: field)
        (table.delegate as? NSTextFieldDelegate)?.controlTextDidEndEditing?(notification)

        #expect(preferences.customVariables.map(\.value) == ["新值"])

        // 改写变量名后按 Tab 进入同一行的值：变量名先写回，表格接着编辑值，
        // 之后带着新变量名的同步不能重载这一行，否则值的编辑被打断、输入的值丢失
        let coordinator = try #require(table.delegate as? EnvironmentTableCoordinator)
        let nameCell = try #require(table.view(atColumn: 0, row: 0, makeIfNecessary: true) as? NSTableCellView)
        let nameField = try #require(nameCell.textField)

        nameField.stringValue = "SECRET"
        coordinator.controlTextDidEndEditing(
            Notification(name: NSControl.textDidEndEditingNotification, object: nameField)
        )

        table.editColumn(1, row: 0, with: nil, select: true)

        coordinator.update(
            EnvironmentTable(
                variables: [EnvironmentTable.Variable(name: "SECRET", value: "新值")],
                label: custom
            )
        )

        #expect(preferences.customVariables.map(\.name) == ["SECRET"])

        // 字段编辑器仍属于这一行值的格子
        let valueCell = try #require(table.view(atColumn: 1, row: 0, makeIfNecessary: false) as? NSTableCellView)
        let valueField = try #require(valueCell.textField)

        #expect((window.firstResponder as? NSTextView)?.delegate === valueField)
    }

    /// 输入框的边框画在布局框上：第一个输入框的边框就在表单的上边距处，每个高 24 pt，
    /// 相邻两个的可见间隔正好是行距；边框伸出布局框时，间隔会比行距小。
    @Test("Git Config 页姓名与邮箱输入框的可见边框")
    func identityFieldBorders() throws {
        let hosting = NSHostingView(
            rootView: SettingsForm(layout: .gitConfig) {
                GitIdentityRows(model: GlobalGitConfigModel())
            }
        )

        hosting.appearance = NSAppearance(named: .aqua)
        hosting.frame.size = hosting.fittingSize
        hosting.layoutSubtreeIfNeeded()

        let fields = Self.subviews(NSTextField.self, in: hosting).filter(\.isEditable)
        try #require(fields.count == 2)

        let bitmap = try #require(Self.render(hosting))
        let borders = try fields.map {
            try #require(Self.drawnRows(of: $0, in: hosting, bitmap: bitmap))
        }

        #expect(borders[0].lowerBound == SettingsFormLayout.verticalMargin)
        #expect(borders.map { $0.upperBound - $0.lowerBound } == [24, 24])
        #expect(borders[1].lowerBound - borders[0].upperBound == SettingsFormLayout.rowSpacing)
    }
}

// MARK: - Helpers

extension SettingsWindowTests {
    /// 把页面放进不显示的窗口并完成一次布局，原生控件随之建立；窗口由调用方持有到测试结束。
    private static func host(_ view: some View) -> NSWindow {
        let hosting = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        return window
    }

    /// 按 2 倍像素画出排好版的视图；没有窗口时视图外是透明的。
    private static func render(_ view: NSView) -> NSBitmapImageRep? {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(view.bounds.width) * 2,
            pixelsHigh: Int(view.bounds.height) * 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let bitmap else {
            return nil
        }

        bitmap.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: bitmap)

        return bitmap
    }

    /// 输入框画出的纵向范围：沿输入框中间的一列，从中心向上下找到透明处为止，单位是根视图的点。
    private static func drawnRows(
        of field: NSTextField,
        in root: NSView,
        bitmap: NSBitmapImageRep
    ) -> Range<CGFloat>? {
        let frame = field.convert(field.bounds, to: root)
        let x = Int(frame.midX * 2)

        let drawn = { (row: Int) in
            (0 ..< bitmap.pixelsHigh).contains(row)
                && (bitmap.colorAt(x: x, y: row)?.alphaComponent ?? 0) > 0
        }

        // 根视图是翻转的，像素的行号与纵坐标同样自上而下
        let center = Int(frame.midY * 2)

        guard drawn(center) else {
            return nil
        }

        let top = (0 ... center).reversed().first { !drawn($0 - 1) } ?? center
        let bottom = (center ..< bitmap.pixelsHigh).first { !drawn($0 + 1) } ?? center

        return CGFloat(top) / 2 ..< CGFloat(bottom + 1) / 2
    }

    /// 视图层级里给定类型的全部视图，按深度优先的顺序。
    private static func subviews<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + subviews(Element.self, in: child)
        }
    }
}
