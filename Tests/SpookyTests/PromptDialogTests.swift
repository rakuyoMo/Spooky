import AppKit
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - PromptDialogTests

/// 仓库窗口与仓库管理里的询问：强制删除分支、子模块的三种询问、停止跟踪已忽略的文件、外部工具的覆盖、
/// 删除书签与应用身份档案都是骨架的确认版，核对标题、主按钮、取消、备选按钮与勾选框；提交信息含注释的询问挂成 sheet。
@MainActor
struct PromptDialogTests {
    /// 强制删除分支：标题按分支个数取单复数，主按钮是 Delete，说明写出这些分支。
    @Test("强制删除分支的询问")
    func forceDeleteBranch() {
        let location = RepositoryLocation.local(path: "/temporary/prompt-" + UUID().uuidString)

        let cases = [
            (["topic"], "branch.error.delete"),
            (["topic", "other"], "branch.error.deleteMultiple"),
        ]

        for (branches, title) in cases {
            let offer = ForceDeletionOffer(
                branches: branches.map { "refs/heads/" + $0 },
                deletingUpstream: false,
                failure: .invalidName("topic")
            )

            let failure = AppFailure(error: offer.failure, opening: false, location: location, writing: true)

            let dialog = RepositoryWindowController.forceDeleteBranchesPrompt(
                offer,
                failure: failure,
                in: RepositorySession()
            ) { }

            #expect(dialog.title == AppLocalization.text(title))
            #expect(dialog.message.contains(branches.joined(separator: ", ")))
            #expect(Self.buttons(of: dialog) == [
                "action.cancel",
                "branch.forceDelete.submit",
            ].map { AppLocalization.text($0) })
            #expect(dialog.checkbox == nil)
        }
    }

    /// 子模块：强制删除是 Force Delete；强制添加用备选底栏，Overwrite 是备选、Reuse Git Directory 是主按钮；
    /// 自动更新的取消写 Do Not Update，内容区是 “总是自动更新” 的勾选框。
    @Test("子模块的三种询问")
    func submodulePrompts() {
        let session = RepositorySession()

        let deletion = RepositoryWindowController.forceDeleteSubmodulePrompt(
            SubmoduleDeletionOffer(submodule: Self.submodule, keepsWorkingTree: false),
            in: session
        ) { }

        #expect(deletion.title == AppLocalization.text("submodule.delete"))
        #expect(Self.buttons(of: deletion) == [
            "action.cancel",
            "submodule.forceDelete.submit",
        ].map { AppLocalization.text($0) })

        let addition = RepositoryWindowController.forceAddSubmodulePrompt(
            SubmoduleAdditionOffer(url: "https://example.com/lib.git", path: "lib"),
            in: session
        ) { }

        #expect(addition.title == AppLocalization.text("submodule.forceAdd"))
        #expect(Self.buttons(of: addition) == [
            "action.cancel",
            "submodule.forceAdd.overwrite",
            "submodule.forceAdd.reuse",
        ].map { AppLocalization.text($0) })

        let update = RepositoryWindowController.autoUpdateSubmodulesPrompt([Self.submodule], in: session) { }

        #expect(update.title == AppLocalization.text("submodule.autoUpdate"))
        #expect(update.message.hasSuffix("\n\nlib"))
        #expect(Self.buttons(of: update) == [
            "submodule.autoUpdate.skip",
            "submodule.autoUpdate.update",
        ].map { AppLocalization.text($0) })
        #expect(update.checkbox == AppLocalization.text("submodule.autoUpdate.always"))
    }

    /// 停止跟踪已忽略的文件用备选底栏：Skip Untrack 是备选、Untrack 是主按钮；外部工具改写的文件已在别处改过时，
    /// 询问的主按钮是 Overwrite。
    @Test("工作区里的询问")
    func workingCopyPrompts() {
        let location = RepositoryLocation.local(path: "/temporary/prompt-" + UUID().uuidString)
        let tracked = [StatusEntry(kind: .tracked, path: "a.txt", unstaged: .modified)]

        let untrack = RepositoryWindowController.untrackIgnoredPrompt(
            .gitignore,
            patterns: ["a.txt"],
            tracked: tracked,
            in: RepositorySession()
        ) { }

        #expect(untrack.title == AppLocalization.text("files.untrackIgnored.title"))
        #expect(Self.buttons(of: untrack) == [
            "action.cancel",
            "files.untrackIgnored.skip",
            "files.untrack",
        ].map { AppLocalization.text($0) })

        let overwrite = RepositorySession.overwritePrompt("a.txt", in: location) { } overwrite: { }

        #expect(overwrite.title == AppLocalization.text("externalTool.fileChanged"))
        #expect(Self.buttons(of: overwrite) == [
            "action.cancel",
            "externalTool.overwrite",
        ].map { AppLocalization.text($0) })
    }

    /// 提交信息含注释时，会话发起的询问由仓库窗口挂成 sheet。
    @Test("提交信息含注释的询问挂成 sheet")
    func commentsPromptSheet() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let window = try #require(fixture.controller.window)
        fixture.controller.session.onCommentPrompt?(false) { _ in }

        let comments = try await Self.attachedSheet(of: window)
        #expect(comments.contentViewController is NSHostingController<CommitCommentsDialog>)

        window.endSheet(comments)
        try await FileViewsTests.wait { window.attachedSheet == nil }
    }

    /// 仓库管理：删除书签的标题按个数取写法、主按钮是 Delete；应用身份档案的主按钮是 Use Profile。
    @Test("仓库管理里的询问")
    func managerPrompts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-prompts-" + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defer { try? FileManager.default.removeItem(at: directory) }

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let manager = RepositoryManagerController(bookmarks: bookmarks, session: RepositorySession())

        let targets = [
            bookmarks.add(.local(path: "/temporary/prompt-" + UUID().uuidString)),
            bookmarks.add(.local(path: "/temporary/prompt-" + UUID().uuidString)),
        ].compactMap(bookmarks.bookmark)

        let deletion = manager.deleteBookmarksPrompt(targets) { }

        #expect(deletion.title == AppLocalization.text("bookmarks.delete.titleMultiple", 2))
        #expect(Self.buttons(of: deletion) == [
            "action.cancel",
            "bookmarks.delete.submit",
        ].map { AppLocalization.text($0) })

        let profile = manager.applyProfilePrompt(
            UserProfile(title: "Work", name: "Spooky Test", email: "spooky@example.invalid"),
            to: .local(path: "/temporary/prompt-" + UUID().uuidString)
        ) { }

        #expect(profile.title == AppLocalization.text("profiles.apply"))
        #expect(Self.buttons(of: profile) == [
            "action.cancel",
            "profiles.apply.submit",
        ].map { AppLocalization.text($0) })
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

    /// 等窗口挂上 sheet。
    static func attachedSheet(of window: NSWindow) async throws -> NSWindow {
        try await FileViewsTests.wait { window.attachedSheet != nil }
        return try #require(window.attachedSheet)
    }

    /// 底栏自左向右的按钮标题：取消、备选按钮（如果有）与主按钮。
    private static func buttons(of dialog: ConfirmationDialog) -> [String] {
        [dialog.cancelTitle] + [dialog.alternate?.title].compactMap(\.self) + [dialog.submitTitle]
    }
}
