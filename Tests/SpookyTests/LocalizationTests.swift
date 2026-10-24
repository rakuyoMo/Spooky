import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 各支持语言的资源完整性、占位参数、英文回退与资源键的使用情况。
struct LocalizationTests {
    /// 包目录，也是仓库根目录：本文件位于 `Tests/SpookyTests/` 下，向上三级。
    private static let package = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// 由枚举或固定列表拼出的资源键；界面新增动态拼接时在这里登记。
    private static var dynamicKeys: [String] {
        var keys: [String] = []

        for kind in RemoteConnectionError.Kind.allCases {
            keys += ["remoteError." + kind.rawValue, "remoteError." + kind.rawValue + ".help"]
        }

        keys += RemoteConnectionState.allCases.map { "connection." + $0.rawValue }
        keys += FailureKind.allCases.map { "failure.kind." + $0.rawValue }
        keys += ["background", "added", "deleted"].map { "themes." + $0 }

        for action in ["stage", "unstage", "discard"] {
            keys += ["Chunk", "Line", "Lines"].map { "working." + action + $0 }
        }

        // 忽略与排除子菜单的各项由同一组后缀拼出
        for file in ["ignore", "exclude"] {
            keys += [".item", ".items", ".name.single", ".name", ".type.single", ".type", ".custom"]
                .map { "files." + file + $0 }
        }

        return keys
    }

    /// 任一语言缺少键、空译文或格式参数变化都会失败。
    @Test("本地化键集合和格式参数一致", arguments: AppLocalization.languages)
    func completeResources(language: String) throws {
        let english = try strings("en")
        let translated = try strings(language)
        let pattern = try NSRegularExpression(pattern: "%[0-9.]*(?:l)?[@dfiu]")
        #expect(Set(translated.keys) == Set(english.keys))

        for (key, value) in translated {
            #expect(!value.isEmpty, "译文不能为空：\(language) / \(key)")
            #expect(value != key)
            let base = try #require(english[key])
            let expected = try pattern.matches(in: base, range: NSRange(base.startIndex..., in: base))
                .map { try #require(Range($0.range, in: base)) }
                .map { String(base[$0]) }
            let actual = try pattern.matches(in: value, range: NSRange(value.startIndex..., in: value))
                .map { try #require(Range($0.range, in: value)) }
                .map { String(value[$0]) }
            #expect(actual == expected, "格式参数不一致：\(language) / \(key)")
        }
    }

    /// 空状态、仓库标签和错误提示在每种语言里都有各不相同的实际译文。
    @Test("主要界面文案有对应译文")
    func translatedSurfaces() throws {
        for key in ["repositories.empty.title", "workspace.title", "error.notRepository"] {
            let values = try AppLocalization.languages.map { try #require(strings($0)[key]) }
            #expect(Set(values).count == AppLocalization.languages.count)
        }

        // 意大利文不在支持语言之列，应回退到英文
        #expect(Bundle.preferredLocalizations(
            from: AppLocalization.languages,
            forPreferences: ["it-IT"]
        ).first == "en")
    }

    /// 外部错误原文保持原样，面向用户的说明、类别与仓库位置来自本地化资源。
    @Test("错误说明本地化且保留原文")
    func errorPresentation() {
        let location = RepositoryLocation.remote(host: "spooky-test", path: "/tmp/仓 库")
        let failure = AppFailure(error: StatusParseError(record: "broken Git output"), opening: false, location: location)
        #expect(failure.title == AppLocalization.text("error.parse"))
        #expect(failure.message == AppLocalization.text("error.refreshHelp"))
        #expect(failure.details == "broken Git output")
        #expect(failure.kind == .output)
        #expect(failure.context.contains(AppLocalization.text("failure.kind.output")))
        #expect(failure.context.contains("spooky-test:/tmp/仓 库"))
    }

    /// 界面新增资源键时，所有语言的资源都漏写也必须被检测出来。
    @Test("Swift 界面引用的资源键全部存在")
    func referencedKeysExist() throws {
        let sources = Self.package.appending(path: "Sources/Spooky")

        // 界面源码分在各功能子目录中，逐层列出
        let files = try FileManager.default.subpathsOfDirectory(atPath: sources.path)
            .map { sources.appending(path: $0) }
            .filter { $0.pathExtension == "swift" }

        let pattern = try NSRegularExpression(
            pattern:
            #""((?:app|action|menu|repositories|workspace|history|loading|branch|status|detail|error|remote|settings|callback|terminal|working|sync|merge|activity|dialog|failure|recovery|files|fileHistory|blame|showFile|diff|text|themes|stash|conflict|commit|profiles|editor|signing|signature|tree|export|patch|compare|revision)\.[A-Za-z.]+)""#
        )
        let english = try strings("en")

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)

            for match in pattern.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
                let range = try #require(Range(match.range(at: 1), in: content))
                let key = String(content[range])
                if key.hasSuffix(".") { continue }
                #expect(english[key] != nil, "缺少界面资源键：\(key)")
            }
        }
    }

    /// 资源里不能留下界面用不到的键：源码里有同名字符串字面量，或属于登记的动态键。
    @Test("资源键都被界面使用")
    func resourceKeysAreUsed() throws {
        let referenced = try sourceLiterals().union(Self.dynamicKeys)

        // 对话框的说明文字由基础键拼接 ".help" 得到，基础键被使用即可
        let unused = try strings("en").keys.filter { key in
            let base = key.hasSuffix(".help") ? String(key.dropLast(".help".count)) : key
            return !referenced.contains(key) && !referenced.contains(base)
        }

        #expect(unused.isEmpty, "资源键没有被界面使用：\(unused.sorted())；动态拼接的键需要登记在 dynamicKeys")
    }

    /// 动态拼出的错误、连接状态与操作资源键同样必须覆盖所有支持语言。
    @Test("动态拼接的资源键覆盖全部支持语言")
    func dynamicResources() throws {
        for language in AppLocalization.languages {
            let values = try strings(language)

            for key in Self.dynamicKeys {
                #expect(values[key] != nil, "缺少动态资源键：\(language) / \(key)")
            }
        }
    }

    /// 权限弹窗读取各语言的 InfoPlist.strings：每种语言都要覆盖 Info.plist 里的全部用途说明，且不多出键。
    @Test("权限说明覆盖全部支持语言", arguments: AppLocalization.languages)
    func usageDescriptions(language: String) throws {
        let usageKeys = try Set(infoPlist().keys.filter { $0.hasSuffix("UsageDescription") })
        let url = Self.package.appending(path: "Sources/Spooky/Resources/\(language).lproj/InfoPlist.strings")
        let data = try Data(contentsOf: url)
        let values = try #require(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String]
        )

        #expect(!usageKeys.isEmpty)
        #expect(Set(values.keys) == usageKeys)
        #expect(values.values.allSatisfy { !$0.isEmpty })
    }

    /// 支持语言在 Info.plist 与两个打包脚本里各写了一份，必须与 `AppLocalization.languages` 一致。
    @Test("支持语言列表在 Info.plist 与打包脚本中一致")
    func languageLists() throws {
        let declared = try #require(infoPlist()["CFBundleLocalizations"] as? [String])
        #expect(Set(declared) == Set(AppLocalization.languages))

        let pattern = try NSRegularExpression(pattern: "^for locale in (.+); do$", options: .anchorsMatchLines)

        for script in ["scripts/build-app.sh", "scripts/bundle.sh"] {
            let url = Self.package.appending(path: script)
            let content = try String(contentsOf: url, encoding: .utf8)
            let match = try #require(pattern.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)))
            let range = try #require(Range(match.range(at: 1), in: content))
            let locales = content[range].split(separator: " ").map(String.init)

            #expect(Set(locales) == Set(AppLocalization.languages), "语言列表不一致：\(script)")
        }
    }

    /// 读取 App 的 Info.plist 源文件。
    private func infoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: Self.package.appending(path: "Sources/Spooky/Info.plist"))
        return try #require(PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any])
    }

    /// App 源码中的全部字符串字面量，用来判断资源键是否被引用。
    private func sourceLiterals() throws -> Set<String> {
        let sources = Self.package.appending(path: "Sources/Spooky")

        // 界面源码分在各功能子目录中，逐层列出
        let files = try FileManager.default.subpathsOfDirectory(atPath: sources.path)
            .map { sources.appending(path: $0) }
            .filter { $0.pathExtension == "swift" }

        let pattern = try NSRegularExpression(pattern: #""((?:[^"\\\n]|\\.)*)""#)
        var literals: Set<String> = []

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)

            for match in pattern.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
                let range = try #require(Range(match.range(at: 1), in: content))
                literals.insert(String(content[range]))
            }
        }

        return literals
    }

    /// 读取已构建资源包中的字典，验证随产品交付的实际文件。
    private func strings(_ language: String) throws -> [String: String] {
        // SwiftPM 把语言目录名转成小写，Bundle 的资源查找在部分系统上区分大小写，所以直接列出目录比对
        let resources = try #require(AppLocalization.bundle.resourceURL)
        let directories = try FileManager.default.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)
        let directory = try #require(
            directories.first { $0.lastPathComponent.caseInsensitiveCompare(language + ".lproj") == .orderedSame }
        )
        let url = directory.appending(path: "Localizable.strings")
        let data = try Data(contentsOf: url)
        let values = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try #require(values as? [String: String])
    }
}
