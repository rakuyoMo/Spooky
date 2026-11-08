import Foundation
import Testing

@testable import Spooky

// MARK: - WhatsNewTests

/// What's New：打包的各版本说明按版本号从新到旧列出并按语言挑选；已读记录决定蓝点，新功能卡片只在新版本第一次启动时出现。
@MainActor
struct WhatsNewTests {
    /// 版本号按数值比较，`0.12.0` 排在 `0.10.0` 与 `0.9.0` 前面，不按字符串排；
    /// 每个版本各自挑语言：有用户的语言就用它，没有时用英文；一份支持语言的说明都没有的版本不列。
    @Test("条目按版本号从新到旧，按用户的语言挑选说明")
    func entryOrderAndLanguage() throws {
        let directory = try Self.notesDirectory([
            "0.12.0": ["en": "twelve", "ja": "十二"],
            "0.10.0": ["en": "ten"],
            "0.9.0": ["en": "nine", "zh-Hans": "九"],
            "0.8.0": ["notes": "没有语言"],
        ])

        defer { try? FileManager.default.removeItem(at: directory) }

        let entries = WhatsNewEntry.entries(in: directory, preferences: ["ja"])

        #expect(
            entries == [
                WhatsNewEntry(version: "0.12.0", notes: "十二"),
                WhatsNewEntry(version: "0.10.0", notes: "ten"),
                WhatsNewEntry(version: "0.9.0", notes: "nine"),
            ]
        )

        // 没有说明目录时没有条目
        #expect(WhatsNewEntry.entries(in: nil).isEmpty)
        #expect(WhatsNewEntry.entries(in: directory.appending(path: "missing")).isEmpty)
    }

    /// 已读记录决定蓝点：没有记录时当前版本以外的版本都记为已读，已有记录时启动不改动它，选中一条就记为已读；
    /// 卡片的 Learn More… 把当前版本记为已读并关掉卡片，× 只关掉卡片；
    /// Developer 菜单的 Show What's New Card 让关掉的卡片重新出现，没有当前版本的说明时仍不出现。
    @Test("已读记录与卡片的操作")
    func readVersionsAndCardActions() throws {
        let (learnDefaults, learnDirectory) = try Self.defaults()
        let (defaults, directory) = try Self.defaults()

        defer {
            try? FileManager.default.removeItem(at: learnDirectory)
            try? FileManager.default.removeItem(at: directory)
        }

        // Learn More…：当前版本记为已读，卡片关掉
        let learn = WhatsNewState(entries: Self.entries, currentVersion: "0.12.0", defaults: learnDefaults)
        learn.start()

        #expect(learn.readVersions == ["0.10.0", "0.9.0"])
        #expect(Self.entries.filter(learn.isUnread).map(\.version) == ["0.12.0"])

        learn.learnMore()

        #expect(!learn.showsCard)
        #expect(!Self.entries.contains(where: learn.isUnread))
        #expect(learnDefaults.stringArray(forKey: WhatsNewState.readVersionsKey) == ["0.12.0", "0.10.0", "0.9.0"])

        // ×：只关掉卡片，当前版本仍带蓝点
        let state = WhatsNewState(entries: Self.entries, currentVersion: "0.12.0", defaults: defaults)
        state.start()
        state.dismissCard()

        #expect(!state.showsCard)
        #expect(state.isUnread(Self.entries[0]))
        #expect(defaults.stringArray(forKey: WhatsNewState.readVersionsKey) == ["0.10.0", "0.9.0"])

        // 选中一条就记为已读
        state.selection = "0.12.0"

        #expect(defaults.stringArray(forKey: WhatsNewState.readVersionsKey) == ["0.12.0", "0.10.0", "0.9.0"])
        #expect(!Self.entries.contains(where: state.isUnread))

        // 重新显示关掉的卡片
        #expect(state.hasCurrentNotes)

        state.showCardAgain()

        #expect(state.showsCard)
        #expect(defaults.string(forKey: WhatsNewState.cardVersionKey) == "0.12.0")

        // 没有当前版本的说明：菜单项禁用，直接调用也不显示
        let missing = WhatsNewState(entries: Self.entries, currentVersion: "0.13.0", defaults: defaults)

        #expect(!missing.hasCurrentNotes)

        missing.showCardAgain()

        #expect(!missing.showsCard)

        // 已有一份记录（这里是空的）时，下次启动不再补写
        defaults.set([String](), forKey: WhatsNewState.readVersionsKey)

        let existing = WhatsNewState(entries: Self.entries, currentVersion: "0.12.0", defaults: defaults)
        existing.start()

        #expect(existing.readVersions.isEmpty)
        #expect(try #require(defaults.stringArray(forKey: WhatsNewState.readVersionsKey)).isEmpty)
    }

    /// 卡片只在打包了当前版本的说明、且这个版本还没显示过卡片时出现；出现后立即记下版本号，下次启动不再出现。
    @Test("新功能卡片的出现条件")
    func cardCondition() throws {
        let (defaults, directory) = try Self.defaults()

        defer { try? FileManager.default.removeItem(at: directory) }

        // 没有当前版本的说明
        let missing = WhatsNewState(entries: Self.entries, currentVersion: "0.13.0", defaults: defaults)
        missing.start()

        #expect(!missing.showsCard)
        #expect(defaults.string(forKey: WhatsNewState.cardVersionKey) == nil)

        // 上次显示卡片的是同一个版本
        defaults.set("0.12.0", forKey: WhatsNewState.cardVersionKey)

        let same = WhatsNewState(entries: Self.entries, currentVersion: "0.12.0", defaults: defaults)
        same.start()

        #expect(!same.showsCard)

        // 上次显示卡片的是旧版本
        defaults.set("0.10.0", forKey: WhatsNewState.cardVersionKey)

        let upgraded = WhatsNewState(entries: Self.entries, currentVersion: "0.12.0", defaults: defaults)
        upgraded.start()

        #expect(upgraded.showsCard)
        #expect(defaults.string(forKey: WhatsNewState.cardVersionKey) == "0.12.0")

        // 从没显示过卡片
        defaults.removeObject(forKey: WhatsNewState.cardVersionKey)

        let fresh = WhatsNewState(entries: Self.entries, currentVersion: "0.12.0", defaults: defaults)
        fresh.start()

        #expect(fresh.showsCard)
        #expect(defaults.string(forKey: WhatsNewState.cardVersionKey) == "0.12.0")

        // 下次启动
        let relaunched = WhatsNewState(entries: Self.entries, currentVersion: "0.12.0", defaults: defaults)
        relaunched.start()

        #expect(!relaunched.showsCard)
    }
}

// MARK: - Helpers

extension WhatsNewTests {
    /// 三个版本的条目，新的在前。
    private static let entries = [
        WhatsNewEntry(version: "0.12.0", notes: "twelve"),
        WhatsNewEntry(version: "0.10.0", notes: "ten"),
        WhatsNewEntry(version: "0.9.0", notes: "nine"),
    ]

    /// 临时目录里的独立偏好域与这个目录；用例结束时删掉目录。
    private static func defaults() throws -> (UserDefaults, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.whatsnew." + UUID().uuidString)

        return (try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path)), directory)
    }

    /// 在临时目录里按 “版本 → 语言 → 内容” 写出说明，每份是 `<版本>/<语言>.md`。
    private static func notesDirectory(_ notes: [String: [String: String]]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-notes-" + UUID().uuidString)

        for (version, files) in notes {
            let folder = directory.appending(path: version)

            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            for (language, content) in files {
                try Data(content.utf8).write(to: folder.appending(path: language + ".md"))
            }
        }

        return directory
    }
}
