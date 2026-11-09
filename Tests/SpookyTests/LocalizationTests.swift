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
        keys += ThemesSettingsView.colorWellKeys.map { "themes." + $0 }
        keys += ThemeTokenList.keys.map { "themes.token." + $0 }

        for action in ["stage", "unstage", "discard"] {
            keys += ["Chunk", "Line", "Lines"].map { "working." + action + $0 }
        }

        // 忽略与排除子菜单的各项由同一组后缀拼出
        for file in ["ignore", "exclude"] {
            keys += [".item", ".items", ".name.single", ".name", ".type.single", ".type", ".custom"]
                .map { "files." + file + $0 }
        }

        // 重置的三档，与交互式变基各动作确认 sheet 的问题与按钮
        keys += ResetMode.allCases.map { "rewrite.reset." + $0.rawValue }

        for action in ["squash", "fixup", "edit", "drop", "move", "autosquash", "rebaseOnto"] {
            keys += [".confirm", ".button"].map { "rewrite." + action + $0 }
        }

        keys += ["squash", "fixup", "drop", "move", "rebaseOnto"].map { "rewrite." + $0 + ".confirm.one" }

        // 克隆进度的阶段名
        keys += CloneProgress.Phase.allCases.map { "clone.phase." + $0.key }

        // 请求视图按选中远端的服务在 pr. 与 mr. 两组叫法之间选
        for prefix in ["pr.", "mr."] {
            keys += [
                "title", "show.menu", "create.menu", "create.title", "create.message", "create.submit", "edit.title",
                "edit.message", "edit.submit", "edit.menu", "accept.title", "accept.message", "accept.submit",
                "close.title", "close.message", "close.submit", "comment.message", "checkout.title", "checkout.menu",
                "empty.title", "empty.message", "noSelection", "noAccount.message", "fetchHead.title",
                "forBranch.create", "forBranch.show", "filter.with", "filter.without",
                "load.title", "loadDetail.title", "description.title", "comment.title", "editComment.title",
                "replyComment.title", "deleteComment.title", "deleteComment.message", "editDescription.title",
                "editDescription.message", "archive.merged",
            ].map { prefix + $0 }
        }

        // 新仓库的可见性
        keys += HostingVisibility.allCases.map { "publish.visibility." + $0.rawValue }

        // 合并方式与 GitLab 项目的合并策略
        keys += PullRequestMergeMethod.allCases.map { "pullRequests.method." + $0.rawValue }
        keys += ["merge", "rebase_merge", "ff"].map { "pullRequests.strategy." + $0 }

        // Activity 里 Remote 行的标题：传输方向加进行时或过去时，各有不带与带远端名的两种
        for transfer in ActivityTransfer.allCases {
            for tense in ["ing", "ed"] {
                let key = "activity." + transfer.rawValue + tense
                keys += [key, key + "Named"]
            }
        }

        // 计数文案另有单数的 .one 键
        let countedKeys = [
            "history.summary.files",
            "history.summary.additions",
            "history.summary.deletions",
            "history.changes",
        ]

        for key in countedKeys {
            keys += [key, key + ".one"]
        }

        for kind in ["chunks", "insertions", "deletions"] {
            keys += ["diff.summary." + kind, "diff.summary." + kind + ".one"]
        }

        keys += ["regular", "executable", "symbolicLink", "directory", "submodule", "none"]
            .map { "diff.summary.mode." + $0 }

        return keys
    }

    /// 读取 App 的 Info.plist 源文件。
    static func infoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: Self.package.appending(path: "Sources/Spooky/Info.plist"))

        return try #require(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
    }

    /// 提取位置与转换类型，跳过字面百分号；无编号的参数按消费顺序编号。
    static func formatSignature(_ value: String) throws -> [Int: Set<String>] {
        let pattern = try NSRegularExpression(
            pattern: #"%(?:%|(?:([1-9][0-9]*)\$)?[-+ #0]*[0-9]*(?:\.[0-9]+)?"#
                + #"(hh|ll|[hlLqztj])?([@diuoxXfFeEgGaAcCsSp]))"#
        )

        var next = 1
        var signature: [Int: Set<String>] = [:]

        for match in pattern.matches(in: value, range: NSRange(value.startIndex..., in: value)) {
            guard let type = Range(match.range(at: 3), in: value) else { continue }

            let position = Range(match.range(at: 1), in: value).flatMap { Int(value[$0]) }
            let length = Range(match.range(at: 2), in: value).map { String(value[$0]) } ?? ""

            signature[position ?? next, default: []].insert(length + value[type])

            if position == nil { next += 1 }
        }

        return signature
    }

    /// 任一语言缺少键、空译文或格式参数变化都会失败；动态拼出的资源键同样要有译文；
    /// 空状态、仓库标签和错误提示在每种语言里都有各不相同的实际译文，不支持的语言回退到英文。
    @Test("各支持语言的资源完整，格式参数一致")
    func completeResources() throws {
        let english = try strings("en")

        for language in AppLocalization.languages {
            let translated = try strings(language)

            #expect(Set(translated.keys) == Set(english.keys), "键集合不一致：\(language)")

            for (key, value) in translated {
                let base = try #require(english[key])

                #expect(!value.isEmpty, "译文不能为空：\(language) / \(key)")
                #expect(value != key)
                #expect(try Self.formatSignature(value) == Self.formatSignature(base), "格式参数不一致：\(language) / \(key)")
            }
        }

        // 各语言的键集合与英文相同，动态键在英文里齐全即覆盖全部语言
        for key in Self.dynamicKeys {
            #expect(english[key] != nil, "缺少动态资源键：\(key)")
        }

        // 主要界面文案的译文各不相同
        for key in ["bookmarks.noRepository.title", "workspace.title", "error.notRepository"] {
            let values = try AppLocalization.languages.map { try #require(strings($0)[key]) }

            #expect(Set(values).count == AppLocalization.languages.count, "\(key)")
        }

        // 意大利文不在支持语言之列，应回退到英文
        let fallback = Bundle.preferredLocalizations(
            from: AppLocalization.languages,
            forPreferences: ["it-IT"]
        )

        #expect(fallback.first == "en")
    }

    /// 格式参数按实际位置比较，允许译文调换次序但不能缺参或改变类型。
    @Test("本地化位置参数签名")
    func positionalFormats() throws {
        let expected = try Self.formatSignature("%1$@ %2$ld")

        #expect(try Self.formatSignature("%2$ld %1$@") == expected)
        #expect(try Self.formatSignature("%@ %ld") == expected)
        #expect(try Self.formatSignature("%% %1$@ %2$ld %%") == expected)

        for invalid in ["%1$@", "%2$ld", "%1$@ %3$ld", "%1$@ %2$d", "%1$@ %2$@"] {
            #expect(try Self.formatSignature(invalid) != expected)
        }

        #expect(try Self.formatSignature("%2$08.2f %1$@") == Self.formatSignature("%@ %f"))
    }

    /// 外部错误原文保持原样，面向用户的说明、类别与仓库位置来自本地化资源。
    @Test("错误说明本地化且保留原文")
    func errorPresentation() {
        let location = RepositoryLocation.remote(host: "spooky-test", path: "/tmp/仓 库")

        let failure = AppFailure(
            error: StatusParseError(record: "broken Git output"),
            opening: false,
            location: location
        )

        #expect(failure.title == AppLocalization.text("error.parse"))
        #expect(failure.message == AppLocalization.text("error.refreshHelp"))
        #expect(failure.details == "broken Git output")
        #expect(failure.kind == .output)
        #expect(failure.context.contains(AppLocalization.text("failure.kind.output")))
        #expect(failure.context.contains("spooky-test:/tmp/仓 库"))
    }

    /// 界面新增资源键时，所有语言的资源都漏写也必须被检测出来；
    /// 资源里也不能留下界面用不到的键：源码里有同名字符串字面量，或属于登记的动态键。
    @Test("界面引用的资源键都存在，资源键都被界面使用")
    func sourceKeys() throws {
        let contents = try sourceContents()
        let english = try strings("en")

        // 形如 “前缀.名称” 的字符串字面量都是资源键
        let prefixes = [
            "app", "action", "menu", "repositories", "workspace", "history", "review", "loading", "branch",
            "status", "detail", "error", "remote", "settings", "callback", "terminal", "working", "sync", "merge",
            "activity", "dialog", "failure", "recovery", "files", "fileHistory", "blame", "showFile", "diff", "text",
            "themes", "stash", "conflict", "commit", "profiles", "editor", "signing", "signature", "tree", "export",
            "patch", "compare", "revision", "sidebar", "tag", "rewrite", "reference", "undo", "reflog",
        ]

        let keyPattern = try NSRegularExpression(
            pattern: #""((?:"# + prefixes.joined(separator: "|") + #")\.[A-Za-z.]+)""#
        )

        for content in contents {
            for match in keyPattern.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
                let range = try #require(Range(match.range(at: 1), in: content))
                let key = String(content[range])

                if key.hasSuffix(".") { continue }

                #expect(english[key] != nil, "缺少界面资源键：\(key)")
            }
        }

        // 对话框的说明文字由基础键拼接 ".help" 得到，基础键被使用即可
        let referenced = try literals(in: contents).union(Self.dynamicKeys)

        let unused = english.keys.filter { key in
            let base = key.hasSuffix(".help") ? String(key.dropLast(".help".count)) : key

            return !referenced.contains(key) && !referenced.contains(base)
        }

        #expect(unused.isEmpty, "资源键没有被界面使用：\(unused.sorted())；动态拼接的键需要登记在 dynamicKeys")
    }

    /// 权限弹窗与 Finder 读取各语言的 InfoPlist.strings：每种语言都要覆盖 Info.plist 里的全部用途说明、
    /// 文稿类型与导出类型的名称，且不多出键；支持语言在 Info.plist 与两个打包脚本里各写了一份，
    /// 必须与 `AppLocalization.languages` 一致。
    @Test("Info.plist 的译文与支持语言列表")
    func infoPlistStrings() throws {
        let plist = try Self.infoPlist()
        let usageKeys = Set(plist.keys.filter { $0.hasSuffix("UsageDescription") })

        // 文稿类型与导出类型的名称以英文原文作键
        let documentTypes = plist["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        let exportedTypes = plist["UTExportedTypeDeclarations"] as? [[String: Any]] ?? []

        let typeNames = Set(
            documentTypes.compactMap { $0["CFBundleTypeName"] as? String }
                + exportedTypes.compactMap { $0["UTTypeDescription"] as? String }
        )

        #expect(!usageKeys.isEmpty)
        #expect(!typeNames.isEmpty)

        for language in AppLocalization.languages {
            let url = Self.package.appending(path: "Sources/Spooky/Resources/\(language).lproj/InfoPlist.strings")
            let data = try Data(contentsOf: url)

            let values = try #require(
                PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String]
            )

            #expect(Set(values.keys) == usageKeys.union(typeNames), "\(language)")
            #expect(values.values.allSatisfy { !$0.isEmpty }, "\(language)")
        }

        // 支持语言列表
        let declared = try #require(plist["CFBundleLocalizations"] as? [String])

        #expect(Set(declared) == Set(AppLocalization.languages))

        let pattern = try NSRegularExpression(pattern: "^for locale in (.+); do$", options: .anchorsMatchLines)

        for script in ["scripts/build-app.sh", "scripts/bundle.sh"] {
            let content = try String(contentsOf: Self.package.appending(path: script), encoding: .utf8)
            let match = try #require(
                pattern.firstMatch(in: content, range: NSRange(content.startIndex..., in: content))
            )
            let range = try #require(Range(match.range(at: 1), in: content))
            let locales = content[range].split(separator: " ").map(String.init)

            #expect(Set(locales) == Set(AppLocalization.languages), "语言列表不一致：\(script)")
        }
    }

    /// App 源码各文件的内容：界面源码分在各功能子目录中，逐层列出。
    private func sourceContents() throws -> [String] {
        let sources = Self.package.appending(path: "Sources/Spooky")

        return try FileManager.default.subpathsOfDirectory(atPath: sources.path)
            .map { sources.appending(path: $0) }
            .filter { $0.pathExtension == "swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
    }

    /// 源码中的全部字符串字面量，用来判断资源键是否被引用。
    private func literals(in contents: [String]) throws -> Set<String> {
        let pattern = try NSRegularExpression(pattern: #""((?:[^"\\\n]|\\.)*)""#)

        var literals: Set<String> = []

        for content in contents {
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
