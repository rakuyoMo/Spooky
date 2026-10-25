import Foundation
import Testing

// MARK: - AppcastCompositionTests

/// `scripts/compose-appcast.swift`：把更新说明嵌进新条目，并从上一份清单带上更稳定的各通道里最新的条目。
///
/// 已安装的 App 只读固定地址的那一份清单：每个通道的用户都要能在里面找到自己通道里最新的版本。
struct AppcastCompositionTests {
    /// 编译一次的合成脚本，各用例共用；放在 `.build` 里，不进版本库。
    private static let composer = Task {
        let directory = ReleaseFixture.package.appending(path: ".build/release-tests")
        let binary = directory.appending(path: "compose-appcast")
        let partial = directory.appending(path: "compose-appcast-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 先编译到临时文件名，再整体换上，其它进程不会读到写了一半的程序
        let result = try await ReleaseFixture.run(
            "/usr/bin/xcrun",
            ["swiftc", "-o", partial.path, ReleaseFixture.package.appending(path: "scripts/compose-appcast.swift").path],
            in: directory
        )

        guard result.status == 0 else {
            throw FixtureError(message: "编译合成脚本失败：\(result.error)")
        }

        try? FileManager.default.removeItem(at: binary)
        try FileManager.default.moveItem(at: partial, to: binary)

        return binary
    }

    /// 稳定版所有用户都会收到，上一份清单里的条目都比它旧，不再带上。
    @Test("稳定版只留新条目")
    func stableKeepsOnlyNewItem() async throws {
        let feed = try await compose(generated: "generated-stable.xml", previous: "previous.xml")

        #expect(feed.items.map(\.build) == [6])
    }

    /// 测试版带上最新的稳定版，选稳定通道的用户仍能收到它；更旧的稳定版与开发版不带。
    @Test("测试版带上最新的稳定版")
    func betaCarriesNewestStable() async throws {
        let feed = try await compose(generated: "generated-beta.xml", previous: "previous.xml")

        #expect(feed.items.map(\.build) == [6, 3])
        #expect(feed.items.map(\.channel) == ["beta", nil])
    }

    /// 开发版带上最新的稳定版与测试版。
    @Test("开发版带上最新的稳定版与测试版")
    func developmentCarriesNewestStableAndBeta() async throws {
        let feed = try await compose(generated: "generated-development.xml", previous: "previous.xml")

        #expect(feed.items.map(\.build) == [6, 3, 4])
        #expect(feed.items.map(\.channel) == ["development", nil, "beta"])
    }

    /// 第一次发布没有上一份清单，只有新条目。
    @Test("没有上一份清单时只有新条目")
    func composesWithoutPreviousFeed() async throws {
        let feed = try await compose(generated: "generated-beta.xml", previous: nil)

        #expect(feed.items.map(\.build) == [6])
    }

    /// 每种语言一份 Markdown 说明，与文件内容逐字相同；`]]>` 与 CRLF 也原样保留为 LF 文本。
    @Test("嵌入每种语言的更新说明")
    func embedsReleaseNotes() async throws {
        let special = "### Fixed\r\n\r\n- Text with ]]> inside.\r\n"
        let feed = try await compose(generated: "generated-stable.xml", previous: nil, englishNotes: special)

        let notes = ReleaseFixture.fixtures.appending(path: "release-notes")
        let descriptions = try #require(feed.items.first?.descriptions)

        #expect(descriptions.map(\.language) == ["en", "zh-Hans", "zh-Hant", "ja", "ko", "de", "fr", "es"])
        #expect(descriptions.allSatisfy { $0.format == "markdown" })
        #expect(descriptions.first?.text == "### Fixed\n\n- Text with ]]> inside.\n")

        for description in descriptions.dropFirst() {
            let expected = try String(contentsOf: notes.appending(path: "\(description.language).md"), encoding: .utf8)
            #expect(description.text == expected)
        }
    }

    /// 私钥与 App 的公钥不配对时安装包没有签名，App 不会安装，不能发布。
    @Test("安装包没有签名时拒绝")
    func rejectsUnsignedArchive() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let appcast = try copyFixture("generated-unsigned.xml", to: directory)
        let original = try Data(contentsOf: appcast)
        let result = try await runComposer(appcast: appcast, notes: ReleaseFixture.fixtures.appending(path: "release-notes"))

        #expect(result.status == 1)
        #expect(result.error.contains("安装包没有 EdDSA 签名"))
        #expect(try Data(contentsOf: appcast) == original)
    }

    /// 缺一种语言的说明时不改动清单。
    @Test("缺少更新说明时不改动清单")
    func rejectsMissingNotes() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let notes = directory.appending(path: "notes")
        try FileManager.default.copyItem(at: ReleaseFixture.fixtures.appending(path: "release-notes"), to: notes)
        try FileManager.default.removeItem(at: notes.appending(path: "fr.md"))

        let appcast = try copyFixture("generated-stable.xml", to: directory)
        let original = try Data(contentsOf: appcast)
        let result = try await runComposer(appcast: appcast, notes: notes)

        #expect(result.status == 1)
        #expect(result.error.contains("fr.md"))
        #expect(try Data(contentsOf: appcast) == original)
    }

    /// 发布检查与清单合成各写了一份语言列表，都要与 App 支持的语言一致。
    @Test("发布脚本的语言列表与 App 一致")
    func languageLists() throws {
        let infoPlist = try Data(contentsOf: ReleaseFixture.package.appending(path: "Sources/Spooky/Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: infoPlist, format: nil) as? [String: Any]
        let declared = try #require(plist?["CFBundleLocalizations"] as? [String])

        let check = try String(contentsOf: ReleaseFixture.package.appending(path: "scripts/check-release.sh"), encoding: .utf8)
        let compose = try String(
            contentsOf: ReleaseFixture.package.appending(path: "scripts/compose-appcast.swift"),
            encoding: .utf8
        )

        // check-release.sh：`for locale in en zh-Hans …; do`
        let checked = try captured(#"for locale in (.+); do"#, in: check)
            .split(separator: " ")
            .map(String.init)

        // compose-appcast.swift：`let languages = ["en", "zh-Hans", …]`
        let composed = try captured(#"let languages = \[(.+)\]"#, in: compose)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) }

        #expect(checked == declared)
        #expect(composed == declared)
    }
}

// MARK: - Helpers

extension AppcastCompositionTests {
    /// 合成后的清单里的一个条目。
    struct Item {
        /// `sparkle:version`。
        let build: Int

        /// `sparkle:channel`，稳定版为 `nil`。
        let channel: String?

        /// 各语言的说明，按清单中的顺序。
        let descriptions: [(language: String, format: String?, text: String)]
    }

    /// 合成后的清单。
    struct Feed {
        /// 按清单中的顺序排列的条目。
        let items: [Item]
    }

    /// 用夹具合成一份清单并读回；可以换掉英文说明的内容。
    private func compose(generated: String, previous: String?, englishNotes: String? = nil) async throws -> Feed {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let notes = directory.appending(path: "notes")
        try FileManager.default.copyItem(at: ReleaseFixture.fixtures.appending(path: "release-notes"), to: notes)

        if let englishNotes {
            try Data(englishNotes.utf8).write(to: notes.appending(path: "en.md"))
        }

        let appcast = try copyFixture(generated, to: directory)
        let previousFeed = try previous.map { try copyFixture($0, to: directory) }
        let result = try await runComposer(appcast: appcast, notes: notes, previous: previousFeed)

        guard result.status == 0 else {
            throw FixtureError(message: "合成失败：\(result.error)")
        }

        return try parse(appcast)
    }

    /// 运行编译好的合成脚本。
    private func runComposer(appcast: URL, notes: URL, previous: URL? = nil) async throws -> CommandResult {
        let binary = try await Self.composer.value
        let arguments = [appcast.path, notes.path] + (previous.map { [$0.path] } ?? [])

        return try await ReleaseFixture.run(binary.path, arguments, in: appcast.deletingLastPathComponent())
    }

    /// 读出清单里的条目、通道、构建号与说明。
    private func parse(_ url: URL) throws -> Feed {
        let namespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"
        let document = try XMLDocument(contentsOf: url, options: .nodeLoadExternalEntitiesNever)
        let elements = try document.nodes(forXPath: "/rss/channel/item").compactMap { $0 as? XMLElement }

        let items = elements.map { element in
            let build = element.elements(forLocalName: "version", uri: namespace).first?.stringValue
            let channel = element.elements(forLocalName: "channel", uri: namespace).first?.stringValue

            let descriptions = element.elements(forName: "description").map {
                (
                    language: $0.attribute(forName: "xml:lang")?.stringValue ?? "",
                    format: $0.attribute(forName: "sparkle:format")?.stringValue,
                    text: $0.stringValue ?? ""
                )
            }

            return Item(build: build.flatMap { Int($0) } ?? 0, channel: channel, descriptions: descriptions)
        }

        return Feed(items: items)
    }

    /// 把夹具里的一份清单拷进目录。
    private func copyFixture(_ name: String, to directory: URL) throws -> URL {
        let destination = directory.appending(path: name)
        try FileManager.default.copyItem(at: ReleaseFixture.fixtures.appending(path: "appcast/\(name)"), to: destination)
        return destination
    }

    /// 本用例独占的临时目录。
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-appcast-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 文本里正则第一个分组匹配到的部分。
    private func captured(_ pattern: String, in text: String) throws -> String {
        let expression = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
        let match = try #require(expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)))
        let range = try #require(Range(match.range(at: 1), in: text))

        return String(text[range])
    }
}
