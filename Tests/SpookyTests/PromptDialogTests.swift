import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - PromptDialogTests

/// 仓库窗口与仓库管理里的询问：强制删除分支、子模块的三种询问、停止跟踪已忽略的文件、外部工具的覆盖、
/// 删除书签与应用身份档案都以骨架的确认版挂成 sheet，核对标题、主按钮、取消、备选按钮与勾选框。
@MainActor
struct PromptDialogTests {
    /// 强制删除分支：标题按分支个数取单复数，主按钮是 Delete，说明写出这些分支。
    @Test("强制删除分支的询问")
    func forceDeleteBranch() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let window = try #require(controller.window)

        for (branches, title) in [(["topic"], "branch.error.delete"), (["topic", "other"], "branch.error.deleteMultiple")] {
            let offer = ForceDeletionOffer(
                branches: branches.map { "refs/heads/" + $0 },
                deletingUpstream: false,
                failure: .invalidName("topic")
            )

            let failure = AppFailure(error: offer.failure, opening: false, location: fixture.location, writing: true)
            controller.presentReferenceRequest(.forceDelete(offer, failure))

            let dialog = try await Self.confirmation(on: window)

            #expect(dialog.title == AppLocalization.text(title))
            #expect(dialog.message.contains(branches.joined(separator: ", ")))
            #expect(Self.buttons(of: dialog) == ["action.cancel", "branch.forceDelete.submit"].map { AppLocalization.text($0) })
            #expect(dialog.checkbox == nil)
        }
    }

    /// 子模块：强制删除是 Force Delete；强制添加用备选底栏，Overwrite 是备选、Reuse Git Directory 是主按钮；
    /// 自动更新的取消写 Do Not Update，内容区是 “总是自动更新” 的勾选框。
    @Test("子模块的三种询问")
    func submodulePrompts() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let window = try #require(controller.window)

        controller.presentSubmoduleRequest(.forceDelete(SubmoduleDeletionOffer(
            submodule: Self.submodule,
            keepsWorkingTree: false
        )))

        let deletion = try await Self.confirmation(on: window)
        #expect(deletion.title == AppLocalization.text("submodule.delete"))
        #expect(Self.buttons(of: deletion) == ["action.cancel", "submodule.forceDelete.submit"].map { AppLocalization.text($0) })

        controller.presentSubmoduleRequest(.forceAdd(SubmoduleAdditionOffer(url: "https://example.com/lib.git", path: "lib")))

        let addition = try await Self.confirmation(on: window)
        #expect(addition.title == AppLocalization.text("submodule.forceAdd"))
        #expect(Self.buttons(of: addition) == [
            "action.cancel",
            "submodule.forceAdd.overwrite",
            "submodule.forceAdd.reuse",
        ].map { AppLocalization.text($0) })

        controller.presentSubmoduleRequest(.autoUpdate([Self.submodule]))

        let update = try await Self.confirmation(on: window)
        #expect(update.title == AppLocalization.text("submodule.autoUpdate"))
        #expect(update.message.hasSuffix("\n\nlib"))
        #expect(Self.buttons(of: update) == [
            "submodule.autoUpdate.skip",
            "submodule.autoUpdate.update",
        ].map { AppLocalization.text($0) })
        #expect(update.checkbox == AppLocalization.text("submodule.autoUpdate.always"))
    }

    /// 停止跟踪已忽略的文件用备选底栏：Skip Untrack 是备选、Untrack 是主按钮；外部工具改写的文件已在别处改过时，
    /// 询问的主按钮是 Overwrite；提交信息含注释的询问同样挂成 sheet。
    @Test("工作区里的询问")
    func workingCopyPrompts() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let session = controller.session
        let window = try #require(controller.window)

        try Data("changed\n".utf8).write(to: fixture.directory.appending(path: "a.txt"))
        session.refresh(full: true)
        await session.waitForRefresh()

        let tracked = session.status?.entries ?? []
        controller.presentFileRequest(.untrackIgnored(.gitignore, patterns: ["a.txt"], tracked: tracked))

        let untrack = try await Self.confirmation(on: window)
        #expect(untrack.title == AppLocalization.text("files.untrackIgnored.title"))
        #expect(Self.buttons(of: untrack) == [
            "action.cancel",
            "files.untrackIgnored.skip",
            "files.untrack",
        ].map { AppLocalization.text($0) })

        session.confirmOverwrite("a.txt") { }

        let overwrite = try await Self.confirmation(on: window)
        #expect(overwrite.title == AppLocalization.text("externalTool.fileChanged"))
        #expect(Self.buttons(of: overwrite) == ["action.cancel", "externalTool.overwrite"].map { AppLocalization.text($0) })

        session.onCommentPrompt?(false) { _ in }

        let comments = try await Self.attachedSheet(of: window)
        #expect(comments.contentViewController is NSHostingController<CommitCommentsDialog>)
        try await Self.endSheet(comments, on: window)
    }

    /// 仓库管理：删除书签的标题按个数取写法、主按钮是 Delete；应用身份档案的主按钮是 Use Profile。
    @Test("仓库管理里的询问")
    func managerPrompts() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let window = try #require(controller.window)
        let bookmarks = fixture.coordinator.bookmarks
        let manager = RepositoryManagerController(bookmarks: bookmarks, session: controller.session)
        manager.window = controller

        let first = bookmarks.add(fixture.location)
        let second = bookmarks.add(.local(path: "/temporary/prompt-" + UUID().uuidString))

        manager.confirmDelete([first, second])

        let deletion = try await Self.confirmation(on: window)
        #expect(deletion.title == AppLocalization.text("bookmarks.delete.titleMultiple", 2))
        #expect(Self.buttons(of: deletion) == ["action.cancel", "bookmarks.delete.submit"].map { AppLocalization.text($0) })

        // 详情区读完仓库概况才能写入身份
        manager.selection = [first]
        try await FileViewsTests.wait { manager.canEditDetail }

        manager.applyProfile(UserProfile(title: "Work", name: "Spooky Test", email: "spooky@example.invalid"))

        let profile = try await Self.confirmation(on: window)
        #expect(profile.title == AppLocalization.text("profiles.apply"))
        #expect(Self.buttons(of: profile) == ["action.cancel", "profiles.apply.submit"].map { AppLocalization.text($0) })

        manager.selection = []
    }
}

// MARK: - Helpers

extension PromptDialogTests {
    /// 路径为 `lib` 的已检出子模块。
    private static let submodule = Submodule(
        name: "lib",
        path: "lib",
        shared: SubmoduleSettings(path: "lib", url: "https://example.com/lib.git"),
        local: nil,
        pointer: "1",
        checkedOut: "1",
        state: .clean,
        problem: nil,
        needsSynchronizing: false
    )

    /// 底栏自左向右的按钮标题：取消、备选按钮（如果有）与主按钮。
    private static func buttons(of dialog: ConfirmationDialog) -> [String] {
        [dialog.cancelTitle] + [dialog.alternate?.title].compactMap(\.self) + [dialog.submitTitle]
    }

    /// 等窗口挂上确认对话框，取出它的内容后关掉这个 sheet。
    private static func confirmation(on window: NSWindow) async throws -> ConfirmationDialog {
        let sheet = try await attachedSheet(of: window)
        let controller = try #require(sheet.contentViewController as? NSHostingController<ConfirmationDialog>)

        try await endSheet(sheet, on: window)
        return controller.rootView
    }

    /// 等窗口挂上 sheet。
    private static func attachedSheet(of window: NSWindow) async throws -> NSWindow {
        try await FileViewsTests.wait { window.attachedSheet != nil }
        return try #require(window.attachedSheet)
    }

    /// 关掉 sheet，等它从窗口上收起，下一个询问才能挂上来。
    private static func endSheet(_ sheet: NSWindow, on window: NSWindow) async throws {
        window.endSheet(sheet)
        try await FileViewsTests.wait { window.attachedSheet == nil }
    }
}
