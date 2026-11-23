import Foundation

// MARK: - SSHHostAlias

/// SSH 配置里的一个主机别名：`Host` 行的名称，与这一段里的地址、用户名、端口和私钥路径。
///
/// 选项为空字符串时，这一段里没有对应的那一行。
public struct SSHHostAlias: Equatable, Sendable {
    /// 别名的字段。
    public enum Field: Sendable {
        /// `Host` 行的名称。
        case alias

        /// 服务器的地址。
        case hostName

        /// 登录的用户名。
        case user

        /// SSH 端口。
        case port

        /// 私钥的路径。
        case identityFile
    }

    /// `Host` 行的名称。
    public var alias: String

    /// `HostName` 的值：服务器的地址。
    public var hostName: String

    /// `User` 的值：登录的用户名。
    public var user: String

    /// `Port` 的值：SSH 端口。
    public var port: String

    /// `IdentityFile` 的值：私钥的路径。
    public var identityFile: String

    /// 第一个值不能写进配置的字段；都能写时为 nil。
    ///
    /// - 别名：能交给 SSH 连接，在 `Host` 行里是一个名称而不是通配符
    /// - 地址与用户名：不含空白
    /// - 端口：1–65535 的整数；写错的端口会让 SSH 拒绝整份配置
    /// - 私钥路径：可以含空格，不含换行等控制字符
    public var invalidField: Field? {
        if !Self.isConnectable(alias) || Self.isPattern(alias) || Self.hasControlCharacter(alias) {
            return .alias
        }

        if hostName.contains(where: \.isWhitespace) || Self.hasControlCharacter(hostName) {
            return .hostName
        }

        if user.contains(where: \.isWhitespace) || Self.hasControlCharacter(user) {
            return .user
        }

        if !port.isEmpty, !Self.isPort(port) {
            return .port
        }

        return Self.hasControlCharacter(identityFile) ? .identityFile : nil
    }

    /// 创建别名。
    ///
    /// - Parameters:
    ///   - alias: `Host` 行的名称。
    ///   - hostName: 服务器的地址。
    ///   - user: 登录的用户名。
    ///   - port: SSH 端口。
    ///   - identityFile: 私钥的路径。
    public init(
        alias: String,
        hostName: String = "",
        user: String = "",
        port: String = "",
        identityFile: String = ""
    ) {
        self.alias = alias
        self.hostName = hostName
        self.user = user
        self.port = port
        self.identityFile = identityFile
    }
}

// MARK: SSHHostAlias + Rules

extension SSHHostAlias {
    /// 名称能否作为主机别名交给 SSH 连接：不为空，不以 `-` 开头，不含空白、`@`、`:`、`/` 与 NUL。
    ///
    /// 单引号属于合法数据；选项、用户和端口不在别名中拆解。
    static func isConnectable(_ name: String) -> Bool {
        !name.isEmpty
            && !name.hasPrefix("-")
            && !name.contains(where: { $0.isWhitespace || $0.isNewline })
            && !name.contains("@")
            && !name.contains(":")
            && !name.contains("/")
            && !name.utf8.contains(0)
    }

    /// `Host` 行里的这个名称是否是模式：带通配符 `*`、`?`，或以表示排除的 `!` 开头。
    static func isPattern(_ name: String) -> Bool {
        name.hasPrefix("!") || name.contains("*") || name.contains("?")
    }

    /// 是否是 1–65535 的十进制整数。
    private static func isPort(_ value: String) -> Bool {
        guard value.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(value) else {
            return false
        }

        return (1 ... 65_535).contains(number)
    }

    /// 值里有没有换行、制表符等控制字符。
    private static func hasControlCharacter(_ value: String) -> Bool {
        value.unicodeScalars.contains { $0.properties.generalCategory == .control }
    }
}

// MARK: - SSHConfigFile

/// SSH 配置文件的全文，以及其中主机别名的增删改。
///
/// 修改只动涉及的那几行：别名只换 `Host` 行里的名称，选项只换它那一行的值；
/// 其它主机、注释、空行与这一段里别的选项逐字保留。
public struct SSHConfigFile: Equatable, Sendable {
    /// 文件的全文。
    public private(set) var text: String

    /// 能在设置里管理的别名，按文件里的先后：`Host` 行只有一个名称、这个名称不是模式的段。
    ///
    /// 几个名称共用的段、带通配符的段与 `Match` 段不在其中，修改时原样保留。
    /// 同一个选项在段里出现几次时取第一行：地址、用户名与端口 SSH 生效的就是它；私钥路径后面的几行 SSH 也会用，修改时原样保留。
    public var aliases: [SSHHostAlias] {
        let lines = Self.lines(of: text)

        return Self.blocks(in: lines).map { block in
            var alias = SSHHostAlias(alias: block.name)

            for option in Option.allCases {
                guard
                    let line = Self.line(of: option, in: block.body, lines: lines),
                    let value = SSHConfigLine(lines[line])?.arguments.first?.value
                else { continue }

                alias[keyPath: option.path] = value
            }

            return alias
        }
    }

    /// 以全文创建配置。
    ///
    /// - Parameter text: 文件的全文，默认是空文件。
    public init(text: String = "") {
        self.text = text
    }

    /// 文件里有没有 `Host` 行用了这个名称，几个名称共用的 `Host` 行也算。
    ///
    /// - Parameters:
    ///   - name: 要查的名称。
    ///   - index: 编辑中的别名在 `aliases` 里的位置，不和它自己比较；新增时为 nil。
    public func containsHost(named name: String, except index: Int? = nil) -> Bool {
        let lines = Self.lines(of: text)
        let blocks = Self.blocks(in: lines)
        let skipped = index.flatMap { blocks.indices.contains($0) ? blocks[$0].host : nil }

        return lines.indices.contains { line in
            guard line != skipped, let parsed = SSHConfigLine(lines[line]), parsed.keyword == "host" else {
                return false
            }

            return parsed.arguments.contains { $0.value == name }
        }
    }

    /// 加一个别名，只写有值的选项，与前后的内容各隔一个空行。
    ///
    /// SSH 的每个选项取先读到的值：新的一段写在第一个适用于多个主机的段之前，那一段的值不会盖过它；
    /// 紧贴在那一段上方的注释留给那一段。没有这样的段时写在文件末尾。
    ///
    /// - Parameter alias: 要添加的别名。
    /// - Returns: 新别名在 `aliases` 里的位置。
    @discardableResult
    public mutating func add(_ alias: SSHHostAlias) -> Int {
        var lines = Self.lines(of: text)

        // 最后一项为空表示文件以换行结尾，写在末尾的一段从它的位置写起
        let end = lines[lines.count - 1].isEmpty ? lines.count - 1 : lines.count
        var position = end

        if let general = lines.indices.first(where: { Self.isGeneral(lines[$0]) }) {
            position = general

            while position > 0, Self.isComment(lines[position - 1]) {
                position -= 1
            }
        }

        var block = ["Host " + Self.formatted(alias.alias)]

        for option in Option.allCases where !alias[keyPath: option.path].isEmpty {
            block.append(Self.indentation + option.name + " " + Self.formatted(alias[keyPath: option.path]))
        }

        let host = position > 0 && !Self.isBlank(lines[position - 1]) ? position + 1 : position

        if host > position {
            block.insert("", at: 0)
        }

        // 后面还有内容时隔一个空行；写在没有以换行结尾的文件末尾时补上换行
        if position < end || position == lines.count {
            block.append("")
        }

        lines.insert(contentsOf: block, at: position)
        text = lines.joined(separator: "\n")

        return Self.blocks(in: lines).firstIndex { $0.host == host } ?? 0
    }

    /// 修改一个别名：名称只换 `Host` 行里的那一个词，选项各自只改自己那一行。
    ///
    /// 选项已有这一行时只换它的值，行里的缩进、写法与行尾注释照旧；值没变的行不动。
    /// 没有这一行时按地址、用户名、端口、私钥路径的先后插入，缩进与段里已有的配置相同；新值为空时删掉这一行。
    ///
    /// - Parameters:
    ///   - index: 别名在 `aliases` 里的位置；超出范围时不改动。
    ///   - alias: 新的值。
    public mutating func replace(at index: Int, with alias: SSHHostAlias) {
        var lines = Self.lines(of: text)
        let blocks = Self.blocks(in: lines)

        guard blocks.indices.contains(index) else {
            return
        }

        let host = blocks[index].host
        lines[host] = Self.replacingFirstArgument(of: lines[host], with: alias.alias)

        for option in Option.allCases {
            Self.set(option, to: alias[keyPath: option.path], inBlockAt: host, of: &lines)
        }

        text = lines.joined(separator: "\n")
    }

    /// 删除一个别名：从 `Host` 行到这一段最后一条配置，之间的注释一并删掉；段前与段后的注释留下。
    ///
    /// - Parameter index: 别名在 `aliases` 里的位置；超出范围时不改动。
    public mutating func remove(at index: Int) {
        var lines = Self.lines(of: text)
        let blocks = Self.blocks(in: lines)

        guard blocks.indices.contains(index) else {
            return
        }

        let host = blocks[index].host
        let last = blocks[index].body.last { SSHConfigLine(lines[$0]) != nil } ?? host

        lines.removeSubrange(host ... last)

        // 删掉之后前后都是空行，或后面的空行成了文件的开头时，去掉后面的空行
        while host < lines.count, Self.isBlank(lines[host]), host == 0 || Self.isBlank(lines[host - 1]) {
            lines.remove(at: host)
        }

        text = lines.joined(separator: "\n")
    }
}

// MARK: SSHConfigFile + Files

extension SSHConfigFile {
    /// 当前用户的 SSH 配置文件 `~/.ssh/config`。
    public static var userFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".ssh/config")
    }

    /// 读出配置文件；文件不存在时是空的配置，不是 UTF-8 文本时抛出。
    ///
    /// - Parameter url: 配置文件的位置。
    public init(contentsOf url: URL) throws {
        do {
            self.init(text: try String(contentsOf: url, encoding: .utf8))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            self.init()
        }
    }

    /// 把全文写回配置文件：先写进同目录的临时文件再替换，中途出错时原文件不变。
    ///
    /// 位置是符号链接时替换它最终指向的文件；已有文件的权限位照旧。
    /// 新文件只有本人可读写，所在的目录不存在时一并建出、只有本人可进：SSH 不接受别人可写的配置。
    ///
    /// - Parameter url: 配置文件的位置。
    public func write(to url: URL) throws {
        let manager = FileManager.default
        let target = url.resolvingSymlinksInPath()
        let permissions = try? manager.attributesOfItem(atPath: target.path)[.posixPermissions]

        try manager.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        try Data(text.utf8).write(to: target, options: .atomic)
        try manager.setAttributes([.posixPermissions: permissions ?? 0o600], ofItemAtPath: target.path)
    }
}

// MARK: SSHConfigFile + Lines

extension SSHConfigFile {
    /// 设置里管理的四个选项，按写进配置的先后。
    private enum Option: CaseIterable {
        /// 服务器的地址。
        case hostName

        /// 登录的用户名。
        case user

        /// SSH 端口。
        case port

        /// 私钥的路径。
        case identityFile

        /// 写进配置的关键字。
        var name: String {
            switch self {
            case .hostName: "HostName"
            case .user: "User"
            case .port: "Port"
            case .identityFile: "IdentityFile"
            }
        }

        /// 别名里对应的值。
        var path: WritableKeyPath<SSHHostAlias, String> {
            switch self {
            case .hostName: \.hostName
            case .user: \.user
            case .port: \.port
            case .identityFile: \.identityFile
            }
        }
    }

    /// 一个能管理的 `Host` 段在各行里的位置。
    private struct Block {
        /// `Host` 行的行号。
        let host: Int

        /// `Host` 行唯一的名称。
        let name: String

        /// 段里 `Host` 行之后的各行，到下一个 `Host` 或 `Match` 行之前。
        let body: Range<Int>
    }

    /// 新写的选项行的缩进。
    private static let indentation = "    "

    /// 能管理的段，按文件里的先后：`Host` 行只有一个名称，且这个名称不是模式。
    private static func blocks(in lines: [String]) -> [Block] {
        lines.indices.compactMap { index in
            guard
                let line = SSHConfigLine(lines[index]),
                line.keyword == "host",
                line.arguments.count == 1,
                !SSHHostAlias.isPattern(line.arguments[0].value)
            else { return nil }

            return Block(host: index, name: line.arguments[0].value, body: body(after: index, in: lines))
        }
    }

    /// `Host` 行之后属于这一段的各行：到下一个 `Host` 或 `Match` 行之前，没有时到文件末尾。
    private static func body(after host: Int, in lines: [String]) -> Range<Int> {
        let end = lines[(host + 1)...].firstIndex { line in
            SSHConfigLine(line).map { $0.keyword == "host" || $0.keyword == "match" } ?? false
        }

        return host + 1 ..< (end ?? lines.count)
    }

    /// 这一行是否开始一个适用于多个主机的段：`Match` 行，或名称里有模式的 `Host` 行。
    private static func isGeneral(_ line: String) -> Bool {
        guard let parsed = SSHConfigLine(line) else {
            return false
        }

        return parsed.keyword == "match"
            || parsed.keyword == "host" && parsed.arguments.contains { SSHHostAlias.isPattern($0.value) }
    }

    /// 段里第一条带参数的这个选项所在的行；没有时为 nil。
    private static func line(of option: Option, in body: Range<Int>, lines: [String]) -> Int? {
        body.first { index in
            SSHConfigLine(lines[index]).map { $0.keyword == option.name.lowercased() && !$0.arguments.isEmpty } ?? false
        }
    }

    /// 把段里的一个选项改成新值：已有这一行时只换它的值，没有时按选项的先后插入；新值为空时删掉这一行。
    private static func set(_ option: Option, to value: String, inBlockAt host: Int, of lines: inout [String]) {
        let body = Self.body(after: host, in: lines)
        let existing = line(of: option, in: body, lines: lines)

        guard !value.isEmpty else {
            if let existing {
                lines.remove(at: existing)
            }

            return
        }

        if let existing {
            lines[existing] = replacingFirstArgument(of: lines[existing], with: value)
            return
        }

        // 接在排在它前面、段里已有的选项之后；都没有时紧跟 Host 行
        let anchor = Option.allCases
            .prefix { $0 != option }
            .compactMap { line(of: $0, in: body, lines: lines) }
            .max() ?? host

        // 缩进与段里已有的配置相同
        let indentation = body
            .first { SSHConfigLine(lines[$0]) != nil }
            .map { String(lines[$0].prefix { $0 == " " || $0 == "\t" }) }

        lines.insert((indentation ?? Self.indentation) + option.name + " " + formatted(value), at: anchor + 1)
    }

    /// 把一行的第一个参数换成新值，其余的字符原样保留；值没变或这一行没有参数时原样返回。
    private static func replacingFirstArgument(of line: String, with value: String) -> String {
        guard let argument = SSHConfigLine(line)?.arguments.first, argument.value != value else {
            return line
        }

        var line = line
        line.replaceSubrange(argument.range, with: formatted(value))

        return line
    }

    /// 把值写成配置里的一个参数：含空格、制表符、引号、反斜杠、`#` 或 `=` 时用双引号括起来，
    /// 里面的双引号与反斜杠前加反斜杠。
    private static func formatted(_ value: String) -> String {
        guard value.unicodeScalars.contains(where: { " \t\"'\\#=".unicodeScalars.contains($0) }) else {
            return value
        }

        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return "\"" + escaped + "\""
    }

    /// 按换行符切出各行；行尾的回车留在行里，以换行结尾的全文最后多出一个空行，拼回去与原文逐字节相同。
    private static func lines(of text: String) -> [String] {
        text.utf8
            .split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
            .map { String(Substring($0)) }
    }

    /// 是否是注释行。
    private static func isComment(_ line: String) -> Bool {
        line.drop(while: \.isWhitespace).hasPrefix("#")
    }

    /// 是否是只有空白的行。
    private static func isBlank(_ line: String) -> Bool {
        line.allSatisfy(\.isWhitespace)
    }
}
