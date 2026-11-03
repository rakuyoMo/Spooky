import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ConfirmationTests

/// 会话里的确认：标题是名词短语，主按钮写动作；丢弃的说明在一个文件时点名它；
/// 丢弃块与行在本机仓库同样带 “Do not ask me again”，与 General 页的警告是同一项。
@MainActor
struct ConfirmationTests {
    /// 各确认用到的资源键的英文：丢弃三种、删除储藏、恢复文件与移除 LFS 规则的标题与主按钮，
    /// 以及服务器上永久删除、远端设置、Reflog、续载提交与身份的确认。
    @Test("英文的标题与主按钮")
    func englishTexts() throws {
        let english = try Self.english()

        let expected = [
            "working.discard.title": "Discard Local Changes",
            "working.discard": "Discard Changes",
            "working.discardAll.title": "Discard All Local Changes",
            "working.discardAll.submit": "Discard All Changes",
            "working.discardContent.title": "Discard Diff Content?",
            "stash.delete": "Delete Stash",
            "stash.deleteStashes": "Delete Stashes",
            "fileHistory.restoreTitle": "Restore Files in Working Copy",
            "fileHistory.restore.submit": "Restore",
            "files.delete.title": "Delete Permanently",
            "files.delete": "Delete",
            "lfs.remove.title": "Remove Tracked File Pattern",
            "lfs.remove": "Remove",
            "remote.pushURL.unset": "Unset Push URL",
            "remote.pushURL.unset.submit": "Unset",
            "remote.refspec.deleteFetch": "Delete Fetch Refspec",
            "remote.refspec.deletePush": "Delete Push Refspec",
            "remote.action.delete": "Delete",
            "reflog.restore.title": "Restore Branch",
            "reflog.restore.submit": "Restore",
            "history.reveal.slow": "Load More Commits",
            "history.reveal.slow.submit": "Load",
            "profiles.apply": "Use User Profile",
            "profiles.apply.submit": "Use Profile",
            "quickActions.setGlobalUser": "Set as Global User",
            "quickActions.setGlobalUser.submit": "Set",
        ]

        for (key, value) in expected {
            #expect(english.localizedString(forKey: key, value: nil, table: nil) == value, "\(key)")
        }

        // 一个文件时说明点名它，多个时写文件数
        let single = String(
            format: english.localizedString(forKey: "working.discard.message.single", value: nil, table: nil),
            "a b.txt",
            "/repo"
        )

        let multiple = String(
            format: english.localizedString(forKey: "working.discard.message", value: nil, table: nil),
            2,
            "/repo"
        )

        #expect(single.hasPrefix("Discard changes in “a b.txt” in /repo."))
        #expect(multiple.hasPrefix("Discard changes in 2 files in /repo."))
    }

    /// 接住会话发出的确认请求核对标题与主按钮；丢弃全部与丢弃所选的标题不同，这些确认都没有 “Do not ask me again”。
    @Test("会话发出的确认")
    func requests() async throws {
        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let root = try await fixture.head()

        // 两个储藏与一处改动
        for content in ["first\n", "second\n"] {
            try fixture.write(content)
            _ = try await fixture.runner.run(["stash", "push", "-q", "-m", content])
        }

        try fixture.write("changed\n")
        await fixture.refresh()

        let entries = try #require(session.status?.entries)
        let stashes = session.stashes.entries
        try #require(stashes.count == 2)

        var requests: [ConfirmationRequest] = []
        session.onConfirm = { requests.append($0) }

        let profile = UserProfile(title: "工作", name: "工作 名字", email: "work@example.invalid")

        session.discard(entries)
        session.discard(entries, all: true)

        session.deleteStashes([stashes[0]])
        session.deleteStashes(stashes)

        session.restoreFile("a b.txt", at: root)
        session.untrackLFS("*.psd")

        session.confirmUnsetPushURL(of: "origin")
        session.confirmRemoveRefspec("+refs/heads/*:refs/remotes/origin/*", from: "origin", push: false)
        session.confirmRemoveRefspec("refs/heads/main", from: "origin", push: true)

        session.applyProfile(profile)
        session.applyGlobalProfile(profile)

        let expected: [(title: String, submit: String)] = [
            ("working.discard.title", "working.discard"),
            ("working.discardAll.title", "working.discardAll.submit"),
            ("stash.delete", "stash.delete"),
            ("stash.deleteStashes", "stash.deleteStashes"),
            ("fileHistory.restoreTitle", "fileHistory.restore.submit"),
            ("lfs.remove.title", "lfs.remove"),
            ("remote.pushURL.unset", "remote.pushURL.unset.submit"),
            ("remote.refspec.deleteFetch", "remote.action.delete"),
            ("remote.refspec.deletePush", "remote.action.delete"),
            ("profiles.apply", "profiles.apply.submit"),
            ("quickActions.setGlobalUser", "quickActions.setGlobalUser.submit"),
        ]

        #expect(requests.map(\.title) == expected.map { AppLocalization.text($0.title) })
        #expect(requests.map(\.submitTitle) == expected.map { AppLocalization.text($0.submit) })
        #expect(requests.allSatisfy { $0.suppression == nil })
    }

    /// 一个文件时说明点名文件名，多个时写文件数；本机、服务器移进废纸篓与服务器永久删除各一例。
    @Test("丢弃的说明")
    func discardMessages() {
        let local = RepositoryLocation.local(path: "/tmp/仓 库")
        let server = RepositoryLocation.remote(host: "spooky-test", path: "/tmp/仓 库")
        let one = [StatusEntry(kind: .unchanged, path: "目录/文件 [x].txt")]
        let two = one + [StatusEntry(kind: .unchanged, path: "b.txt")]

        let cases: [(RepositoryLocation, FileRemoval, single: String, multiple: String)] = [
            (local, .trash, "working.discard.message.single", "working.discard.message"),
            (server, .trash, "working.discard.remote.single", "working.discard.remote"),
            (server, .permanent, "working.discard.remotePermanent.single", "working.discard.remotePermanent"),
        ]

        for (location, removal, single, multiple) in cases {
            let named = RepositorySession.discardMessage(one, in: location, removal: removal)
            let counted = RepositorySession.discardMessage(two, in: location, removal: removal)

            #expect(named == AppLocalization.text(single, "文件 [x].txt", location.displayPath))
            #expect(counted == AppLocalization.text(multiple, 2, location.displayPath))
        }
    }

    /// 本机仓库丢弃块与行同样带 “Do not ask me again”，对应 General 页的警告；这项警告关掉以后直接丢弃，不再询问。
    @Test("本机仓库丢弃块与行可以不再询问")
    func discardChunks() async throws {
        let confirmation = ServerConfirmation.discardChunks
        let saved = UserDefaults.standard.object(forKey: confirmation.key)
        defer { UserDefaults.standard.set(saved, forKey: confirmation.key) }

        UserDefaults.standard.removeObject(forKey: confirmation.key)

        let fixture = try await UndoSessionTests.Fixture()
        defer { fixture.remove() }

        let session = fixture.session

        try fixture.write("base\nadded\n")
        await fixture.refresh()

        // 选中文件，等工作区一侧的 Diff 读完
        let entry = try #require(session.status?.entries.first)
        let row = StatusRowID(path: entry.path, kind: entry.kind)
        session.selectedID = row
        session.selectedIDs = [row]
        try await FileViewsTests.wait { session.diffSnapshot?.diff != nil }

        let file = try #require(session.diffSnapshot?.diff?.files.first)
        let hunk = try #require(file.hunks.first)
        let changes = hunk.lines.filter(\.isChange)
        let line = try #require(changes.first)

        var requests: [ConfirmationRequest] = []
        session.onConfirm = { requests.append($0) }

        session.apply(file: file.id, hunk: hunk.id, lines: [line.id], discard: true)

        let request = try #require(requests.first)
        #expect(request.title == AppLocalization.text("working.discardContent.title"))
        #expect(request.submitTitle == AppLocalization.text("working.discard"))
        #expect(request.suppression == .discardChunks)

        // 在确认对话框里勾选不再提醒之后
        confirmation.isEnabled = false

        try await fixture.perform {
            session.apply(file: file.id, hunk: hunk.id, lines: [line.id], discard: true)
        }
        #expect(requests.count == 1)
        #expect(try fixture.read() == "base\n")
    }
}

// MARK: - Helpers

extension ConfirmationTests {
    /// 英文资源，与系统语言无关。
    static func english() throws -> Bundle {
        try #require(
            AppLocalization.bundle
                .url(forResource: "en", withExtension: "lproj")
                .flatMap(Bundle.init(url:))
        )
    }
}
