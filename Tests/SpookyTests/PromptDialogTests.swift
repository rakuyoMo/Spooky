import AppKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - PromptDialogTests

/// 仓库窗口与仓库管理里的询问：强制删除分支、子模块的三种询问、停止跟踪已忽略的文件、外部工具的覆盖、
/// 删除书签与应用身份档案都是骨架的确认版，核对随输入变化的标题与说明、主按钮、取消、备选按钮与勾选框。
@MainActor
struct PromptDialogTests {
    /// 仓库窗口里的询问。
    ///
    /// 强制删除分支的标题按分支个数取单复数，说明写出这些分支，主按钮是 Force Delete；子模块的强制删除同样是 Force Delete；
    /// 强制添加子模块与停止跟踪已忽略的文件用备选底栏；子模块自动更新的取消写 Do Not Update，内容区是 “总是自动更新” 的勾选框；
    /// 外部工具改写的文件已在别处改过时，询问的主按钮是 Overwrite。
    @Test("仓库窗口里的询问")
    func windowPrompts() {
        let session = RepositorySession()

        let branchCases = [
            (["topic"], "branch.error.delete"),
            (["topic", "other"], "branch.error.deleteMultiple"),
        ]

        for (branches, title) in branchCases {
            let dialog = Self.forceDeleteBranchesPrompt(branches, in: session)

            #expect(dialog.title == AppLocalization.text(title))
            #expect(dialog.message.contains(branches.joined(separator: ", ")))
            #expect(Self.buttons(of: dialog) == Self.texts("action.cancel", "branch.forceDelete.submit"))
            #expect(dialog.checkbox == nil)
        }

        // 子模块
        let deletion = RepositoryWindowController.forceDeleteSubmodulePrompt(
            SubmoduleDeletionOffer(submodule: Self.submodule, keepsWorkingTree: false),
            in: session
        ) { }

        let addition = RepositoryWindowController.forceAddSubmodulePrompt(
            SubmoduleAdditionOffer(url: "https://example.com/lib.git", path: "lib"),
            in: session
        ) { }

        let update = RepositoryWindowController.autoUpdateSubmodulesPrompt([Self.submodule], in: session) { }

        #expect(Self.buttons(of: deletion) == Self.texts("action.cancel", "submodule.forceDelete.submit"))

        #expect(
            Self.buttons(of: addition)
                == Self.texts("action.cancel", "submodule.forceAdd.overwrite", "submodule.forceAdd.reuse")
        )

        #expect(update.message.hasSuffix("\n\nlib"))
        #expect(Self.buttons(of: update) == Self.texts("submodule.autoUpdate.skip", "submodule.autoUpdate.update"))
        #expect(update.checkbox == AppLocalization.text("submodule.autoUpdate.always"))

        // 工作区
        let untrack = RepositoryWindowController.untrackIgnoredPrompt(
            .gitignore,
            patterns: ["a.txt"],
            tracked: [StatusEntry(kind: .tracked, path: "a.txt", unstaged: .modified)],
            in: session
        ) { }

        let location = RepositoryLocation.local(path: "/temporary/prompt-" + UUID().uuidString)
        let overwrite = RepositorySession.overwritePrompt("a.txt", in: location) { } overwrite: { }

        #expect(
            Self.buttons(of: untrack)
                == Self.texts("action.cancel", "files.untrackIgnored.skip", "files.untrack")
        )

        #expect(Self.buttons(of: overwrite) == Self.texts("action.cancel", "externalTool.overwrite"))
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
        #expect(Self.buttons(of: deletion) == Self.texts("action.cancel", "bookmarks.delete.submit"))

        let profile = manager.applyProfilePrompt(
            UserProfile(title: "Work", name: "Spooky Test", email: "spooky@example.invalid"),
            to: .local(path: "/temporary/prompt-" + UUID().uuidString)
        ) { }

        #expect(Self.buttons(of: profile) == Self.texts("action.cancel", "profiles.apply.submit"))
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
        await until { window.attachedSheet != nil }

        return try #require(window.attachedSheet)
    }

    /// 强制删除这几个本地分支的询问，删除时报的是分支名不合法。
    private static func forceDeleteBranchesPrompt(
        _ branches: [String],
        in session: RepositorySession
    ) -> ConfirmationDialog {
        let offer = ForceDeletionOffer(
            branches: branches.map { "refs/heads/" + $0 },
            deletingUpstream: false,
            failure: .invalidName("topic")
        )

        let location = RepositoryLocation.local(path: "/temporary/prompt-" + UUID().uuidString)
        let failure = AppFailure(error: offer.failure, opening: false, location: location, writing: true)

        return RepositoryWindowController.forceDeleteBranchesPrompt(offer, failure: failure, in: session) { }
    }

    /// 底栏自左向右的按钮标题：取消、备选按钮（如果有）与主按钮。
    private static func buttons(of dialog: ConfirmationDialog) -> [String] {
        [dialog.cancelTitle] + [dialog.alternate?.title].compactMap(\.self) + [dialog.submitTitle]
    }

    /// 这几个资源键的文字。
    private static func texts(_ keys: String...) -> [String] {
        keys.map { AppLocalization.text($0) }
    }
}
