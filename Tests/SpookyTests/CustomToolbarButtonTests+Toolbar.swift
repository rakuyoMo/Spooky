import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Toolbar

extension CustomToolbarButtonTests {
    /// 设置里建的按钮要出现在自定义面板里，放进工具栏后点按与溢出菜单都运行它的脚本；
    /// 编辑后工具栏跟着改，删除后同一标识的每个窗口都只移除这一项：工具栏按位置同步删除，删错一项就会连带删掉别的按钮。
    @Test("工具栏里的自定义按钮：面板列出、标签截短、点按运行，编辑后重写，删除后从共用标识的窗口里移除")
    func toolbarItems() async throws {
        let store = CustomToolbarButtonStore(defaults: MemoryDefaults())
        let fixture = try await NavigationTests.makeWindow(isolatesToolbar: true, toolbarButtons: store)
        defer { fixture.close() }

        let output = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: output) }

        let result = output.appending(path: "result.txt")
        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)

        let run = CustomToolbarButton(
            symbol: "hammer",
            name: "Run",
            script: #"print -r -- "$SPOOKY_BRANCH|$SPOOKY_HEAD" > "# + GitRunner.shellQuoted(result.path)
        )

        let long = CustomToolbarButton(name: String(repeating: "Deploy to production ", count: 5), script: "true")

        store.save(run)
        store.save(long)

        // 自定义面板在内置项之后按添加的先后列出
        let identifiers = [run, long].map(RepositoryToolbar.identifier(of:))

        #expect(Array(controller.toolbarAllowedItemIdentifiers(toolbar).suffix(2)) == identifiers)

        for identifier in identifiers {
            toolbar.insertItem(withItemIdentifier: identifier, at: toolbar.items.count)
        }

        let runItem = try #require(toolbar.items.first { $0.itemIdentifier == identifiers[0] })
        let longItem = try #require(toolbar.items.first { $0.itemIdentifier == identifiers[1] })

        // 放得下的名称原样作标签；放不下时截短，提示写完整的名称；窗口显示仓库时可用
        #expect(runItem.label == "Run")
        #expect(longItem.label == RepositoryToolbar.customButtonLabel(long.name))
        #expect(longItem.label != long.name)
        #expect(longItem.toolTip == long.name)
        #expect(controller.validateUserInterfaceItem(runItem))

        // 点按与溢出菜单里的一项都运行脚本，脚本拿到窗口里仓库的分支与 HEAD
        let branch = try #require(controller.session.status?.branch)
        let expected = (branch.head ?? "") + "|" + (branch.oid ?? "") + "\n"

        for sender in [runItem, runItem.menuFormRepresentation] as [Any?] {
            try? FileManager.default.removeItem(at: result)
            controller.runCustomButton(sender)

            await until { (try? String(contentsOf: result, encoding: .utf8)) == expected }
        }

        // 编辑后标签与提示跟着改
        var renamed = run
        renamed.name = "Build"
        store.save(renamed)

        await until { runItem.label == "Build" }

        #expect(runItem.toolTip == "Build")

        try await expectRemoval(of: long, from: fixture, store: store)
    }
}

// MARK: - Steps

extension CustomToolbarButtonTests {
    /// 第二个窗口与它共用工具栏标识；删除一个按钮后，两个窗口都只少了这一项。
    private func expectRemoval(
        of button: CustomToolbarButton,
        from fixture: NavigationTests.WindowFixture,
        store: CustomToolbarButtonStore
    ) async throws {
        let identifier = RepositoryToolbar.identifier(of: button)
        let first = try #require(fixture.controller.window?.toolbar)

        let second = RepositoryWindowController(
            coordinator: fixture.coordinator,
            toolbarIdentifier: NSToolbar.Identifier(fixture.toolbarIdentifier),
            toolbarButtons: store
        )

        defer {
            second.session.close()
            second.window?.close()
        }

        let toolbars = [first, try #require(second.window?.toolbar)]

        // 删除前两个窗口里都有这个按钮，记下删除后各自应有的排布
        for toolbar in toolbars {
            try #require(toolbar.items.contains { $0.itemIdentifier == identifier })
        }

        let remaining = toolbars.map { $0.items.map(\.itemIdentifier).filter { $0 != identifier } }

        store.remove(button.id)

        await until { toolbars.allSatisfy { !$0.items.contains { $0.itemIdentifier == identifier } } }

        #expect(toolbars.map { $0.items.map(\.itemIdentifier) } == remaining)
    }
}
