import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 五种语言的资源完整性、占位参数和英文回退。
struct LocalizationTests {
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
            let expected = pattern.matches(in: base, range: NSRange(base.startIndex..., in: base))
                .map { (base as NSString).substring(with: $0.range) }
            let actual = pattern.matches(in: value, range: NSRange(value.startIndex..., in: value))
                .map { (value as NSString).substring(with: $0.range) }
            #expect(actual == expected, "格式参数不一致：\(language) / \(key)")
        }
    }

    /// 空状态、仓库标签和错误提示都必须有五种实际译文。
    @Test("主要界面文案有对应译文")
    func translatedSurfaces() throws {
        for key in ["repositories.empty.title", "workspace.title", "error.notRepository"] {
            let values = try AppLocalization.languages.map { try #require(strings($0)[key]) }
            #expect(Set(values).count == 5)
        }

        #expect(Bundle.preferredLocalizations(
            from: AppLocalization.languages,
            forPreferences: ["fr-FR"]
        ).first == "en")
    }

    /// 外部错误原文保持原样，面向用户的说明来自本地化资源。
    @Test("错误说明本地化且保留原文")
    func errorPresentation() {
        let failure = AppFailure(error: StatusParseError(record: "broken Git output"), opening: false)
        #expect(failure.title == AppLocalization.text("error.parse"))
        #expect(failure.message == AppLocalization.text("error.refreshHelp"))
        #expect(failure.details == "broken Git output")
    }

    /// 界面新增资源键时，五种资源都漏写也必须被检测出来。
    @Test("Swift 界面引用的资源键全部存在")
    func referencedKeysExist() throws {
        let package = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = package.appending(path: "Sources/Spooky")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        let pattern = try NSRegularExpression(
            pattern: #""((?:app|action|menu|repositories|workspace|history|loading|branch|status|detail|error|remote|settings|callback|terminal|working)\.[A-Za-z.]+)""#
        )
        let english = try strings("en")

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)

            for match in pattern.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
                let key = (content as NSString).substring(with: match.range(at: 1))
                if key.hasSuffix(".") { continue }
                #expect(english[key] != nil, "缺少界面资源键：\(key)")
            }
        }
    }

    /// 动态拼出的错误和连接状态资源键同样必须覆盖所有支持语言。
    @Test("远端状态与修复方向的五语资源")
    func remoteResources() throws {
        for language in AppLocalization.languages {
            let values = try strings(language)

            for kind in RemoteConnectionError.Kind.allCases {
                #expect(values["remoteError." + kind.rawValue] != nil)
                #expect(values["remoteError." + kind.rawValue + ".help"] != nil)
            }

            for state in RemoteConnectionState.allCases {
                #expect(values["connection." + state.rawValue] != nil)
            }

            for key in ["background", "added", "deleted"] {
                #expect(values["themes." + key] != nil)
            }

            for operation in ["merge", "squash", "rebase", "cherryPick", "revert"] {
                #expect(values["working.operation." + operation] != nil)
            }

            for action in ["stage", "unstage", "discard"] {
                for selection in ["Chunk", "Line", "Lines"] {
                    #expect(values["working." + action + selection] != nil)
                }
            }
        }
    }

    /// 读取已构建资源包中的字典，验证随产品交付的实际文件。
    private func strings(_ language: String) throws -> [String: String] {
        let directory = try #require(AppLocalization.bundle.url(forResource: language, withExtension: "lproj"))
        let url = directory.appending(path: "Localizable.strings")
        let data = try Data(contentsOf: url)
        let values = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try #require(values as? [String: String])
    }
}
