// 合成这一版的更新清单：把每种语言的更新说明嵌进 generate_appcast 生成的条目，
// 再从上一份清单带上比这一版更稳定的各通道里最新的条目
//
// 由 scripts/appcast.sh 调用；改写会让清单原有的签名失效，之后须用 sign_update 重签
// 用法：swift scripts/compose-appcast.swift <appcast.xml> <说明目录> [<上一份更新清单>]

import Foundation

/// Sparkle 的 XML 命名空间，`sparkle:` 前缀的元素属于它
let sparkleNamespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"

/// App 支持的语言，按写进清单的顺序排列
///
/// 语言代码与 `Sources/Spooky/Resources/` 下的 `.lproj` 同名，既是说明的文件名，也是元素的 `xml:lang`：
/// Sparkle 在同名元素里按用户的语言偏好挑出一个
let languages = ["en", "zh-Hans", "zh-Hant", "ja", "ko", "de", "fr", "es"]

/// 通道从最稳定到最不稳定的顺序，稳定版的条目不带 `sparkle:channel`
///
/// 后面的通道接收前面所有通道的条目，所以较新的条目会让同一通道及其后各通道里较旧的条目失去作用
let channels: [String?] = [nil, "beta", "development"]

// 参数依次为清单路径、说明目录，以及可选的上一份清单
let arguments = CommandLine.arguments

guard arguments.count == 3 || arguments.count == 4 else {
    fail("用法：swift scripts/compose-appcast.swift <appcast.xml> <说明目录> [<上一份更新清单>]")
}

composeAppcast(
    appcastPath: arguments[1],
    notesDirectory: arguments[2],
    previousFeedPath: arguments.count == 4 ? arguments[3] : nil
)

// MARK: - Composing

/// 嵌入说明、带上更稳定通道的条目，校验后写回原文件
func composeAppcast(appcastPath: String, notesDirectory: String, previousFeedPath: String?) {
    // 1. 先读入全部说明，缺一份就在改动清单之前退出
    let notes = languages.map { readNotes(at: "\(notesDirectory)/\($0).md") }

    // 2. 读入 generate_appcast 生成的清单，取出其中唯一的条目
    let document = readDocument(at: appcastPath)

    guard
        let channel = try? document.nodes(forXPath: "/rss/channel").first as? XMLElement,
        let items = try? channel.nodes(forXPath: "item"),
        items.count == 1,
        let item = items.first as? XMLElement
    else {
        fail("\(appcastPath) 须恰好包含一个 <item>")
    }

    // generate_appcast 遇到私钥与 App 里的公钥不配对时只给出警告、不签安装包，这样的条目 App 不会安装
    let enclosure = item.elements(forName: "enclosure").first

    guard enclosure?.attribute(forLocalName: "edSignature", uri: sparkleNamespace) != nil else {
        fail("安装包没有 EdDSA 签名：私钥与 App 的 SUPublicEDKey 不配对")
    }

    // 3. 每种语言一份说明，`en` 在前
    for (language, content) in zip(languages, notes) {
        item.addChild(descriptionElement(language: language, content: content))
    }

    // 4. 测试与开发版本的清单带上更稳定的各通道里最新的条目，选了这些通道的用户仍能收到它们
    if let previousFeedPath {
        let previousItems = carriedItems(from: readDocument(at: previousFeedPath), below: rank(of: item))

        for previousItem in previousItems {
            channel.addChild(previousItem)
        }
    }

    // 5. 按缩进格式序列化，确认解析结果与读入的说明一致后再落盘
    let data = document.xmlData(options: .nodePrettyPrint)

    verifyDescriptions(in: data, expected: notes)

    do {
        try data.write(to: URL(fileURLWithPath: appcastPath), options: .atomic)
    } catch {
        fail("写入 \(appcastPath) 失败：\(error.localizedDescription)")
    }
}

/// 上一份清单里比这一版更稳定的每个通道各取构建号最大的一个条目，复制一份
///
/// 同一通道与更不稳定的通道里的条目都比这一版旧，选了这些通道的用户会收到这一版，不再带上
func carriedItems(from previousFeed: XMLDocument, below newRank: Int) -> [XMLElement] {
    guard let items = try? previousFeed.nodes(forXPath: "/rss/channel/item") as? [XMLElement] else {
        fail("无法读取上一份清单里的条目")
    }

    return (0 ..< newRank).compactMap { channelRank in
        let newest = items
            .filter { rank(of: $0) == channelRank }
            .max { buildNumber(of: $0) < buildNumber(of: $1) }

        return newest?.copy() as? XMLElement
    }
}

// MARK: - Helpers

/// 条目所在通道在 `channels` 里的位置；遇到不认识的通道报错退出
func rank(of item: XMLElement) -> Int {
    let channel = item.elements(forLocalName: "channel", uri: sparkleNamespace).first?.stringValue

    guard let rank = channels.firstIndex(of: channel) else {
        fail("条目的通道 “\(channel ?? "")” 不是 beta 或 development")
    }

    return rank
}

/// 条目的构建号，即 `sparkle:version`
func buildNumber(of item: XMLElement) -> Int {
    let version = item.elements(forLocalName: "version", uri: sparkleNamespace).first?.stringValue

    guard let build = version.flatMap({ Int($0) }) else {
        fail("条目的 sparkle:version 须为整数，实际为 “\(version ?? "")”")
    }

    return build
}

/// 读入一份清单，不加载外部实体
func readDocument(at path: String) -> XMLDocument {
    do {
        return try XMLDocument(contentsOf: URL(fileURLWithPath: path), options: .nodeLoadExternalEntitiesNever)
    } catch {
        fail("读取 \(path) 失败：\(error.localizedDescription)")
    }
}

/// 读取一份说明，换行统一为 LF
///
/// XML 解析时会把 CRLF 与单独的 CR 统一成 LF，NSXMLDocument 却不统一 CDATA 里的换行；
/// 先统一成 LF，清单里的说明不随解析器是否照做而变，写盘前的校验也按统一后的文本比对
func readNotes(at path: String) -> String {
    let content: String

    do {
        content = try String(contentsOfFile: path, encoding: .utf8)
    } catch {
        fail("读取 \(path) 失败：\(error.localizedDescription)")
    }

    // 先换 CRLF，再换剩下的单独 CR，CRLF 不会变成两个换行
    return content
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
}

/// 某种语言的内嵌说明：`<description xml:lang="…" sparkle:format="markdown">`，说明文本放在 CDATA 里
func descriptionElement(language: String, content: String) -> XMLElement {
    let element = XMLElement(name: "description")

    element.addAttribute(attribute(name: "xml:lang", value: language))
    element.addAttribute(attribute(name: "sparkle:format", value: "markdown"))

    element.setChildren(cdataNodes(for: content))
    return element
}

/// 按 Sparkle 读清单的方式解析序列化结果，确认新条目里每种语言恰好一份说明，且与读入的说明逐字节相同
func verifyDescriptions(in data: Data, expected notes: [String]) {
    guard
        let parsed = try? XMLDocument(data: data, options: .nodeLoadExternalEntitiesNever),
        let descriptions = try? parsed.nodes(forXPath: "/rss/channel/item[1]/description") as? [XMLElement]
    else {
        fail("无法解析改写后的清单")
    }

    for (language, content) in zip(languages, notes) {
        let matches = descriptions.filter {
            $0.attribute(forName: "xml:lang")?.stringValue == language
        }

        guard matches.count == 1, matches.first?.stringValue == content else {
            fail("改写后的清单里，\(language) 的说明与读入的文本不一致")
        }
    }
}

/// 把文本拆成一组 CDATA 节点，依次拼接即为原来的文本
///
/// CDATA 段里不能出现 `]]>`：文本里每出现一次，就从 `]]` 与 `>` 之间断开，分进前后两段
func cdataNodes(for content: String) -> [XMLNode] {
    var segments = content.components(separatedBy: "]]>")

    // 每个断开处，前一段补回 `]]`，后一段补回 `>`
    for index in segments.indices.dropLast() {
        segments[index] += "]]"
        segments[index + 1] = ">" + segments[index + 1]
    }

    return segments.map {
        let node = XMLNode(kind: .text, options: .nodeIsCDATA)
        node.stringValue = $0
        return node
    }
}

/// 按名称原样创建的属性节点，`xml:lang`、`sparkle:format` 这类带前缀的名称照原样写进清单
func attribute(name: String, value: String) -> XMLNode {
    let attribute = XMLNode(kind: .attribute)
    attribute.name = name
    attribute.stringValue = value
    return attribute
}

/// 向标准错误输出中文报错，并以非零状态退出
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("错误：\(message)\n".utf8))
    exit(1)
}
