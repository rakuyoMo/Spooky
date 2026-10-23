import Foundation

// MARK: - IndexFile

/// 暂存区里的一个文件，供工作区列表补出未改动与 assume-unchanged 的文件
public struct IndexFile: Sendable, Equatable {
    /// 文件路径，相对仓库根目录
    public var path: String

    /// 是否标记了 assume-unchanged：Git 不再检查它在工作区里的改动
    public var assumeUnchanged: Bool

    /// 创建索引条目
    public init(path: String, assumeUnchanged: Bool) {
        self.path = path
        self.assumeUnchanged = assumeUnchanged
    }
}

extension GitRunner {
    /// 暂存区里的全部文件；冲突文件的多个 stage 只列一次
    public func indexFiles() async throws -> [IndexFile] {
        try IndexFile.parse(lsFilesVerbose: try await run(["ls-files", "-z", "-v"]))
    }

    /// 被忽略的文件；整个被忽略的目录只列一项，路径以 `/` 结尾，不展开其中的文件
    public func ignoredFiles() async throws -> [String] {
        let output = try await run([
            "ls-files",
            "-z",
            "--others",
            "--ignored",
            "--exclude-standard",
            "--directory",
            "--no-empty-directory",
        ])

        return try IndexFile.paths(nulTerminated: output)
    }
}

extension IndexFile {
    /// 解析 `git ls-files -z -v`：每条记录是 “标记字母 + 空格 + 路径”，小写字母表示 assume-unchanged
    ///
    /// 冲突文件的每个 stage 各占一条记录，按路径去重并保留首次出现的顺序。
    static func parse(lsFilesVerbose output: Data) throws -> [IndexFile] {
        var seen = Set<String>()
        var files: [IndexFile] = []

        for record in try paths(nulTerminated: output) {
            // 标记只有一个 ASCII 字母，后面固定跟一个空格，路径里的空格原样保留
            guard
                let tag = record.unicodeScalars.first,
                tag.isASCII, CharacterSet.letters.contains(tag),
                record.dropFirst().first == " ",
                record.count > 2
            else {
                throw RepositoryReadError.malformedOutput("ls-files")
            }

            let path = String(record.dropFirst(2))

            guard seen.insert(path).inserted else {
                continue
            }

            files.append(IndexFile(path: path, assumeUnchanged: CharacterSet.lowercaseLetters.contains(tag)))
        }

        return files
    }

    /// 按 NUL 切分以 NUL 结尾的记录；截断的输出不能当作完整清单
    static func paths(nulTerminated output: Data) throws -> [String] {
        guard !output.isEmpty else {
            return []
        }

        guard output.last == 0 else {
            throw RepositoryReadError.malformedOutput("ls-files")
        }

        return output
            .dropLast()
            .split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }
    }
}
