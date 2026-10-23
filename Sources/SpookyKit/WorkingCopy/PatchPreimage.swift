import Foundation

// MARK: - PatchPreimage

/// 补丁里一个文件的前像：生成补丁时该文件的对象哈希，应用前据此核对文件是否还是那个版本
struct PatchPreimage: Sendable, Equatable {
    /// 应用前的文件路径，相对仓库根目录；重命名与复制取原路径
    let path: String

    /// `index` 行记录的前像哈希，可能是缩写
    let hash: String
}

extension PatchPreimage {
    /// 从 git 风格补丁的文件头读取前像
    ///
    /// 只读取 `diff --git` 与第一个块头之间的文件头，块内以 `---` 开头的删除行不会被误当作路径。
    /// 新增文件、子模块与没有 `index` 行或文本路径的段没有可核对的前像，不列出。
    static func preimages(in patch: Data) -> [PatchPreimage] {
        var preimages: [PatchPreimage] = []
        var section: Section? = nil

        for line in String(decoding: patch, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("diff --git ") {
                if let preimage = section?.preimage { preimages.append(preimage) }
                section = Section()
                continue
            }

            // 块头或二进制补丁开始后，本段的文件头已经结束
            if line.hasPrefix("@@ ") || line == "GIT binary patch" {
                section?.inHeader = false
            }

            guard section?.inHeader ?? false else {
                continue
            }

            section?.read(header: String(line))
        }

        if let preimage = section?.preimage { preimages.append(preimage) }
        return preimages
    }

    /// 解析文件头里的路径：带引号的按 C 风格反转义，不带引号的去掉 Git 为含空格路径补的行尾 Tab
    static func headerPath(_ value: String) -> String? {
        guard value.hasPrefix("\"") else {
            return value.hasSuffix("\t") ? String(value.dropLast()) : value
        }

        return unquoted(value)
    }

    /// 反转义 Git 的 C 风格引号路径，八进制转义按原始字节拼回 UTF-8；格式不完整时为 nil
    static func unquoted(_ value: String) -> String? {
        var bytes: [UInt8] = []
        var iterator = Array(value.utf8).dropFirst().makeIterator()

        while let byte = iterator.next() {
            switch byte {
            // 结束引号之后不应再有内容，Git 只会补一个 Tab
            case UInt8(ascii: "\""):
                return String(decoding: bytes, as: UTF8.self)

            case UInt8(ascii: "\\"):
                guard let escaped = iterator.next() else { return nil }
                guard let decoded = unescaped(escaped, rest: &iterator) else { return nil }
                bytes.append(decoded)

            default:
                bytes.append(byte)
            }
        }

        return nil
    }

    /// 单个转义序列对应的字节；八进制转义继续读取后两位
    private static func unescaped(
        _ escaped: UInt8,
        rest: inout IndexingIterator<ArraySlice<UInt8>>
    ) -> UInt8? {
        let simple: [UInt8: UInt8] = [
            UInt8(ascii: "a"): 7,
            UInt8(ascii: "b"): 8,
            UInt8(ascii: "t"): 9,
            UInt8(ascii: "n"): 10,
            UInt8(ascii: "v"): 11,
            UInt8(ascii: "f"): 12,
            UInt8(ascii: "r"): 13,
            UInt8(ascii: "\""): UInt8(ascii: "\""),
            UInt8(ascii: "\\"): UInt8(ascii: "\\"),
        ]

        if let byte = simple[escaped] {
            return byte
        }

        // 三位八进制，首位已读出
        let digits = [escaped, rest.next(), rest.next()]
        let values = digits.compactMap { $0 }.filter { (48 ... 55).contains($0) }.map { Int($0) - 48 }

        guard values.count == 3 else {
            return nil
        }

        let value = values[0] * 64 + values[1] * 8 + values[2]
        return value <= 255 ? UInt8(value) : nil
    }
}

// MARK: PatchPreimage.Section

extension PatchPreimage {
    /// 一个 `diff --git` 段的文件头状态
    private struct Section {
        /// 还在文件头里；遇到块头或二进制补丁后为 false
        var inHeader = true

        /// `index` 行的前像哈希
        var hash: String? = nil

        /// 前像是子模块，工作区里没有可计算哈希的文件
        var submodule = false

        /// `rename from` 或 `copy from` 给出的原路径
        var source: String? = nil

        /// `---` 行给出的旧路径，已去掉第一级前缀；新增文件为 nil
        var oldPath: String? = nil

        /// 本段可核对的前像；新增文件的前像哈希全为 0
        var preimage: PatchPreimage? {
            guard
                let hash, !submodule,
                !hash.allSatisfy({ $0 == "0" }),
                let path = source ?? oldPath
            else { return nil }

            return PatchPreimage(path: path, hash: hash)
        }

        /// 吸收一行文件头
        mutating func read(header line: String) {
            if line.hasPrefix("index ") {
                readIndex(line.dropFirst(6))
            } else if line.hasPrefix("rename from ") {
                source = PatchPreimage.headerPath(String(line.dropFirst(12)))
            } else if line.hasPrefix("copy from ") {
                source = PatchPreimage.headerPath(String(line.dropFirst(10)))
            } else if line.hasPrefix("--- "), line != "--- /dev/null" {
                // git apply 默认按 -p1 去掉第一级目录，这里取同样的路径
                oldPath = PatchPreimage.headerPath(String(line.dropFirst(4)))
                    .flatMap { path in path.firstIndex(of: "/").map { String(path[path.index(after: $0)...]) } }
            }
        }

        /// `index <前像>..<后像>[ <模式>]`；模式为 160000 时前像是子模块提交
        private mutating func readIndex(_ value: Substring) {
            let fields = value.split(separator: " ")
            let hashes = fields.first?.components(separatedBy: "..") ?? []

            guard
                hashes.count == 2,
                let old = hashes.first,
                !old.isEmpty,
                old.allSatisfy(\.isHexDigit)
            else { return }

            hash = old.lowercased()
            submodule = fields.count > 1 && fields[1] == "160000"
        }
    }
}
