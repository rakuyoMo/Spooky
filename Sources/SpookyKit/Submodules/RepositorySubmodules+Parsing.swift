import Foundation

// MARK: - Parsing

extension RepositorySubmodules {
    /// 解析 `config -z --get-regexp ^submodule\.` 的输出，按段名第一次出现的顺序列出各段。
    ///
    /// 每条记录是 “键、换行、值、NUL”，没有值的布尔键只有 “键、NUL”；键形如 `submodule.<名称>.<变量>`，
    /// 名称可以含句点，按最后一个句点切开。没有名称的键（如 `submodule.recurse`）不属于任何子模块。
    static func parseSettings(_ data: Data) throws -> [(name: String, settings: SubmoduleSettings)] {
        guard data.isEmpty || data.last == 0 else {
            throw RepositoryReadError.malformedOutput("config")
        }

        var names: [String] = []
        var settings: [String: SubmoduleSettings] = [:]

        for record in data.split(separator: 0, omittingEmptySubsequences: false).dropLast() {
            let newline = record.firstIndex(of: 10)
            let key = String(decoding: record[..<(newline ?? record.endIndex)], as: UTF8.self)
            let value = newline.map { String(decoding: record[record.index(after: $0)...], as: UTF8.self) }

            guard key.hasPrefix("submodule.") else {
                throw RepositoryReadError.malformedOutput("config")
            }

            let rest = key.dropFirst("submodule.".count)

            guard let dot = rest.lastIndex(of: "."), dot > rest.startIndex else {
                continue
            }

            let name = String(rest[..<dot])

            if settings[name] == nil {
                names.append(name)
                settings[name] = SubmoduleSettings()
            }

            // 变量名由 Git 转成小写；空值与没有设置一样
            let text = value.flatMap { $0.isEmpty ? nil : $0 }

            switch rest[rest.index(after: dot)...] {
            case "path": settings[name]?.path = text
            case "url": settings[name]?.url = text
            case "fetchrecursesubmodules": settings[name]?.fetchRecurseSubmodules = value == nil ? "true" : text
            case "ignore": settings[name]?.ignore = text
            case "update": settings[name]?.update = text
            default: break
            }
        }

        return names.compactMap { name in settings[name].map { (name, $0) } }
    }

    /// 解析 `ls-files -s -z` 的输出，只留下子模块指针：路径对应暂存区里的提交，处于冲突中的为 nil。
    ///
    /// 每条记录是 “模式 对象 阶段、制表符、路径、NUL”。
    static func parseGitlinks(_ data: Data) throws -> [String: String?] {
        guard data.isEmpty || data.last == 0 else {
            throw RepositoryReadError.malformedOutput("ls-files")
        }

        var gitlinks: [String: String?] = [:]

        for record in data.split(separator: 0, omittingEmptySubsequences: false).dropLast() {
            guard let tab = record.firstIndex(of: 9), tab < record.endIndex - 1 else {
                throw RepositoryReadError.malformedOutput("ls-files")
            }

            let fields = String(decoding: record[..<tab], as: UTF8.self).split(separator: " ")

            guard fields.count == 3 else {
                throw RepositoryReadError.malformedOutput("ls-files")
            }

            guard fields[0] == Self.gitlinkMode else {
                continue
            }

            let path = String(decoding: record[record.index(after: tab)...], as: UTF8.self)

            // 阶段 0 是正常的指针，1–3 是冲突的三方
            gitlinks[path] = fields[2] == "0" ? String(fields[1]) : .some(nil)
        }

        return gitlinks
    }

    /// 解析 `submodule status` 的输出。
    ///
    /// 每行是 “状态字符、提交、空格、路径”，已检出时后面还有 “ (描述)”。路径原样输出、可以含有换行，
    /// 所以按已知路径的最长匹配切分，而不是按行切分。
    ///
    /// - Parameters:
    ///   - data: 命令的标准输出。
    ///   - paths: 查询的子模块路径。
    static func parseStatus(_ data: Data, paths: [String]) throws -> [String: StatusRecord] {
        let bytes = [UInt8](data)
        let candidates = paths.map { (path: $0, bytes: Array($0.utf8)) }.sorted { $0.bytes.count > $1.bytes.count }
        var records: [String: StatusRecord] = [:]
        var index = 0

        while index < bytes.count {
            let state: SubmoduleState =
                switch bytes[index] {
                case UInt8(ascii: " "): .clean
                case UInt8(ascii: "-"): .uninitialized
                case UInt8(ascii: "+"): .updated
                case UInt8(ascii: "U"): .unmerged
                default: throw RepositoryReadError.malformedOutput("submodule")
                }

            // 提交的长度随对象格式变化，读到空格为止
            let hashStart = index + 1
            index = hashStart

            while index < bytes.count, bytes[index].isHexDigit {
                index += 1
            }

            guard index > hashStart, index < bytes.count, bytes[index] == UInt8(ascii: " ") else {
                throw RepositoryReadError.malformedOutput("submodule")
            }

            let commit = String(decoding: bytes[hashStart ..< index], as: UTF8.self)
            index += 1

            guard let match = candidates.first(where: { Self.matches($0.bytes, in: bytes, at: index) }) else {
                throw RepositoryReadError.malformedOutput("submodule")
            }

            index += match.bytes.count

            // 描述里不会有换行，跳到行尾即可
            guard let newline = bytes[index...].firstIndex(of: 10) else {
                throw RepositoryReadError.malformedOutput("submodule")
            }

            index = newline + 1
            records[match.path] = StatusRecord(state: state, commit: commit)
        }

        return records
    }

    /// 解析 `for-each-ref --format=%(refname)%00%(HEAD)` 的输出，分支在前，各自按名称排序。
    static func parseRevisions(_ data: Data) throws -> [SubmoduleRevision] {
        let revisions = try data.split(separator: 10).map { line in
            let fields = line.split(separator: 0, omittingEmptySubsequences: false)

            guard fields.count == 2, !fields[0].isEmpty else {
                throw RepositoryReadError.malformedOutput("for-each-ref")
            }

            return SubmoduleRevision(
                reference: String(decoding: fields[0], as: UTF8.self),
                isCurrent: fields[1].elementsEqual([UInt8(ascii: "*")])
            )
        }

        return revisions.sorted { first, second in
            guard first.isTag == second.isTag else { return !first.isTag }
            return first.name.localizedStandardCompare(second.name) == .orderedAscending
        }
    }

    /// 按 Git 的规则把以 `./`、`../` 开头的相对地址换算成绝对地址；其它写法原样返回，去不掉一级时为 nil。
    ///
    /// 每个 `../` 去掉基准地址的最后一级：先按 `/` 去，没有 `/` 时按 scp 写法的 `:` 去，此时结果以 `:` 连接。
    ///
    /// - Parameters:
    ///   - url: `.gitmodules` 里的地址。
    ///   - base: 父仓库默认远端的地址；没有远端时是父仓库工作区的绝对路径。
    static func resolvedURL(_ url: String, base: String) -> String? {
        guard url.hasPrefix("./") || url.hasPrefix("../") else {
            return url
        }

        var remote = base.hasSuffix("/") ? String(base.dropLast()) : base

        // 基准地址本身是相对路径时补上 “./”，保证它总能逐级去掉
        let isRelative = Self.isLocalPath(remote) && !remote.hasPrefix("/")
        if isRelative, !remote.hasPrefix("./"), !remote.hasPrefix("../") {
            remote = "./" + remote
        }

        var rest = Substring(url)
        var separatesWithColon = false

        while true {
            if rest.hasPrefix("../") {
                rest = rest.dropFirst(3)

                if let slash = remote.lastIndex(of: "/") {
                    remote = String(remote[..<slash])
                } else if let colon = remote.lastIndex(of: ":") {
                    remote = String(remote[..<colon])
                    separatesWithColon = true
                } else if isRelative || remote == "." {
                    return nil
                } else {
                    remote = "."
                }
            } else if rest.hasPrefix("./") {
                rest = rest.dropFirst(2)
            } else {
                break
            }
        }

        var resolved = remote + (separatesWithColon ? ":" : "/") + rest

        if rest.hasSuffix("/") {
            resolved.removeLast()
        }

        return resolved.hasPrefix("./") ? String(resolved.dropFirst(2)) : resolved
    }

    /// 地址是本机路径而不是 scp 写法或网址：没有冒号，或第一个斜杠在第一个冒号之前。
    private static func isLocalPath(_ url: String) -> Bool {
        guard let colon = url.firstIndex(of: ":") else {
            return true
        }

        return url.firstIndex(of: "/").map { $0 < colon } ?? false
    }

    /// 输出在这个位置是不是这条路径，且路径后面紧跟换行或 “ (”。
    private static func matches(_ path: [UInt8], in bytes: [UInt8], at index: Int) -> Bool {
        let end = index + path.count

        guard !path.isEmpty, end < bytes.count, bytes[index ..< end].elementsEqual(path) else {
            return false
        }

        return bytes[end] == 10
            || (bytes[end] == UInt8(ascii: " ") && end + 1 < bytes.count && bytes[end + 1] == UInt8(ascii: "("))
    }
}

// MARK: - UInt8

extension UInt8 {
    /// 是十六进制数字的小写或大写写法。
    fileprivate var isHexDigit: Bool {
        (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(self)
            || (UInt8(ascii: "a") ... UInt8(ascii: "f")).contains(self)
            || (UInt8(ascii: "A") ... UInt8(ascii: "F")).contains(self)
    }
}
