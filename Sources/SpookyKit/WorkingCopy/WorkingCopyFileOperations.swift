import Foundation

// MARK: - IgnoreFile

/// 忽略规则写入的位置
public enum IgnoreFile: Sendable {
    /// 仓库根目录的 `.gitignore`，随仓库提交共享
    case gitignore

    /// git 目录下的 `info/exclude`，只在这份仓库里生效，不随提交共享
    case exclude
}

// MARK: - IgnorePatternScope

/// 由所选文件生成忽略规则的方式
public enum IgnorePatternScope: Sendable {
    /// 只匹配所选的这几项
    case items

    /// 匹配所有同名的文件或目录
    case name

    /// 匹配所有扩展名相同的文件
    case type
}

// MARK: - WorkingCopyFileError

/// 工作区文件操作在交给 Git 之前就能判断的失败
public enum WorkingCopyFileError: Error, Sendable, Equatable {
    /// 补丁要修改的文件已经不是生成补丁时的版本，关联值是这些文件的路径
    case patchPreimageMismatch([String])

    /// 移动的目标位置已经有文件，不覆盖
    case destinationExists
}

// MARK: - File Operations

extension WorkingCopyOperations {
    /// 停止跟踪：从暂存区移除，工作区里的文件保留；提交后这些文件在版本库里表现为删除
    ///
    /// - Parameter paths: 仓库内的相对路径，按字面匹配；目录连同其中的文件一起移除。
    public func untrack(_ paths: [String]) async throws {
        guard !paths.isEmpty else { return }

        // -f 让有改动的文件也能移除，--ignore-unmatch 让不在暂存区的路径不算失败
        _ = try await runner.run(
            ["--literal-pathspecs", "rm", "-q", "-f", "-r", "--cached", "--ignore-unmatch"]
                + Self.pathInputOptions,
            input: Self.pathInput(Array(Set(paths)))
        )
    }

    /// 删除工作区里的文件与目录：本机移到废纸篓，服务器上永久删除；调用方必须先获得用户确认
    ///
    /// 只改动工作区，已跟踪文件的删除留待暂存，与在 Finder 或终端里删除文件的结果相同。
    ///
    /// - Parameter paths: 仓库内的相对路径；以 `/` 结尾的是整个未跟踪或被忽略的目录。
    /// - Returns: 本机文件在废纸篓里的位置；服务器文件永久删除，没有可找回的位置。
    @discardableResult
    public func delete(_ paths: [String]) async throws -> [URL] {
        guard !paths.isEmpty else { return [] }

        let files = RepositoryFiles(runner: runner)
        let root = runner.location.path

        return try await runner.writeTransaction {
            guard runner.remote != nil else {
                #warning("TODO: 核实删除已跟踪文件后是否同时暂存删除，目前只把文件移到废纸篓、删除留待暂存；只影响本机删除之后的暂存状态")
                return try files.moveToTrash(paths.map { root + "/" + $0 })
            }

            // SFTP 的 rm 只删除文件；整个目录交给 git clean，嵌套的仓库会被 git 跳过
            let directories = paths.filter { $0.hasSuffix("/") }
            try await files.remove(paths.filter { !$0.hasSuffix("/") }.map { root + "/" + $0 })

            if !directories.isEmpty {
                _ = try await runner.run(
                    ["--literal-pathspecs", "clean", "-q", "-f", "-d", "-x", "--"] + directories
                )
            }

            return []
        }
    }

    /// 移动或重命名一个文件；目标已存在时失败，不覆盖
    ///
    /// - Parameters:
    ///   - path: 原路径，相对仓库根目录。
    ///   - destination: 新路径，相对仓库根目录，所在目录必须已存在。
    ///   - tracked: 文件在暂存区里时经 `git mv` 移动，否则直接移动工作区文件。
    public func move(_ path: String, to destination: String, tracked: Bool) async throws {
        // 规范等价的两个路径指向同一个文件
        guard path != destination else { return }

        guard tracked else {
            let root = runner.location.path
            try await RepositoryFiles(runner: runner).move(root + "/" + path, to: root + "/" + destination)
            return
        }

        // 只改大小写时，不区分大小写的文件系统会把目标当作已存在，需要 -f
        let caseOnly = path.lowercased() == destination.lowercased()
        _ = try await runner.run(["mv"] + (caseOnly ? ["-f"] : []) + ["--", path, destination])
    }

    /// 设置或清除 assume-unchanged 标记；路径必须都在暂存区里，否则整批不生效
    ///
    /// - Parameters:
    ///   - paths: 仓库内的相对路径，经 NUL 分隔的标准输入传入。
    ///   - assumeUnchanged: 为 true 时设置标记，Git 不再检查这些文件在工作区里的改动。
    public func setAssumeUnchanged(_ paths: [String], _ assumeUnchanged: Bool) async throws {
        guard !paths.isEmpty else { return }

        _ = try await runner.run(
            ["update-index", assumeUnchanged ? "--assume-unchanged" : "--no-assume-unchanged", "-z", "--stdin"],
            input: Self.pathInput(Array(Set(paths)))
        )
    }

    /// 把规则追加到忽略文件末尾，已有的同一条规则不重复写入；文件不存在时新建
    ///
    /// - Parameters:
    ///   - patterns: 要追加的规则，每条一行。
    ///   - file: 写入仓库根目录的 `.gitignore`，或只在本仓库生效的 `info/exclude`。
    public func addIgnorePatterns(_ patterns: [String], to file: IgnoreFile) async throws {
        guard !patterns.isEmpty else { return }

        let files = RepositoryFiles(runner: runner)

        try await runner.writeTransaction {
            let path = try await ignoreFilePath(file)
            let existing = try await files.read([path])[path] ?? Data()

            // 服务器上列出的文件名可能是 NFD，比较前统一成 NFC；CRLF 文件的行尾 CR 不参与比较
            let lines = Set(
                String(decoding: existing, as: UTF8.self)
                    .split(separator: "\n")
                    .map { String($0.hasSuffix("\r") ? $0.dropLast() : $0).precomposedStringWithCanonicalMapping }
            )

            var additions: [String] = []

            for pattern in patterns where !lines.contains(pattern.precomposedStringWithCanonicalMapping) {
                if !additions.contains(pattern) { additions.append(pattern) }
            }

            guard !additions.isEmpty else {
                return
            }

            // 原文件末尾没有换行时先补一个，新规则从新的一行开始
            var data = existing
            if !data.isEmpty, data.last != 10 { data.append(10) }
            data.append(Data((additions.joined(separator: "\n") + "\n").utf8))

            // info 目录不存在时先建出来
            if file == .exclude {
                let directory = path.lastIndex(of: "/").map { String(path[..<$0]) } ?? path
                try await files.createDirectory(directory)
            }

            try await files.write(data, to: path)
        }
    }

    /// 把补丁应用到工作区：先由 Git 预检，再核对补丁记录的前像与当前文件一致，都通过才写入
    ///
    /// 补丁内容经标准输入交给工作区所在机器上的 `git apply`，本机补丁文件的路径不交给 Git。
    /// 任何一步失败都不改动工作区，Git 的原始输出保留在错误里。
    ///
    /// - Parameter patch: 补丁文件的原始字节。
    public func applyPatch(_ patch: Data) async throws {
        try await runner.writeTransaction {
            _ = try await runner.run(["apply", "--check", "-"], input: patch)
            try await verifyPreimages(PatchPreimage.preimages(in: patch))
            _ = try await runner.run(["apply", "-"], input: patch)
        }
    }
}

// MARK: - Ignore Patterns

extension WorkingCopyOperations {
    /// 文件名的扩展名：最后一个 “.” 之后的部分；没有 “.” 或只以 “.” 开头的隐藏文件没有扩展名
    public static func pathExtension(of name: String) -> String {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return ""
        }

        return String(name[name.index(after: dot)...])
    }

    /// 由所选文件生成忽略规则，规则里的通配符与特殊字符都转义成字面值
    ///
    /// - Parameters:
    ///   - paths: 仓库内的相对路径；以 `/` 结尾的是目录。
    ///   - scope: 只匹配这几项、匹配同名项，或匹配同扩展名的文件。
    /// - Returns: 去重后的规则；含换行的路径无法写成规则，没有扩展名的文件不产生类型规则。
    public static func ignorePatterns(for paths: [String], scope: IgnorePatternScope) -> [String] {
        var patterns: [String] = []

        for path in paths where !path.contains("\n") && !path.contains("\r") {
            let directory = path.hasSuffix("/")
            let trimmed = directory ? String(path.dropLast()) : path
            let name = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
            let pattern: String?

            switch scope {
            case .items:
                #warning("TODO: 核实 Ignore This Item 写入的规则格式，目前以 “/” 开头、只匹配仓库根目录下的这一项；只影响忽略与排除规则的写法")

                // 以 “/” 开头只匹配仓库根目录下的这一项
                pattern = "/" + escapedPattern(trimmed) + (directory ? "/" : "")

            case .name:
                // 名字规则从行首开始，开头的 # 与 ! 会被当作注释与取反，同样转义
                let escaped = escapedPattern(name)
                let literal = escaped.hasPrefix("#") || escaped.hasPrefix("!") ? "\\" + escaped : escaped
                pattern = literal + (directory ? "/" : "")

            case .type:
                let suffix = pathExtension(of: name)
                pattern = directory || suffix.isEmpty ? nil : "*." + escapedPattern(suffix)
            }

            if let pattern, !patterns.contains(pattern) {
                patterns.append(pattern)
            }
        }

        return patterns
    }

    /// 把文本转义成只匹配自身的规则：通配符与反斜杠前加反斜杠，行尾空格同样转义
    private static func escapedPattern(_ text: String) -> String {
        var result = ""

        for character in text {
            if "\\*?[".contains(character) { result.append("\\") }
            result.append(character)
        }

        // 行尾空格会被 Git 忽略，逐个转义
        let trailing = result.reversed().prefix { $0 == " " }.count
        if trailing > 0 {
            result = String(result.dropLast(trailing)) + String(repeating: "\\ ", count: trailing)
        }

        return result
    }
}

// MARK: - Private

extension WorkingCopyOperations {
    /// 忽略文件在工作区所在机器上的绝对路径；`info/exclude` 由 Git 定位，链接工作树也指向公共目录
    private func ignoreFilePath(_ file: IgnoreFile) async throws -> String {
        switch file {
        case .gitignore:
            return runner.location.path + "/.gitignore"

        case .exclude:
            let output = try await runner.run(["rev-parse", "--path-format=absolute", "--git-path", "info/exclude"])
            let path = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

            guard !path.isEmpty, !path.contains("\n") else {
                throw RepositoryReadError.malformedOutput("rev-parse")
            }

            return path
        }
    }

    /// 当前文件的对象哈希必须以补丁记录的前像哈希开头；文件缺失或内容变化时列出这些文件
    private func verifyPreimages(_ preimages: [PatchPreimage]) async throws {
        guard !preimages.isEmpty else {
            return
        }

        let hashes = try await currentHashes(preimages.map(\.path))
        let mismatched = zip(preimages, hashes)
            .filter { preimage, hash in !(hash?.hasPrefix(preimage.hash) ?? false) }
            .map(\.0.path)

        guard mismatched.isEmpty else {
            throw WorkingCopyFileError.patchPreimageMismatch(mismatched)
        }
    }

    /// 按 Git 的清理规则计算工作区文件的对象哈希，与 diff 的 `index` 行一致；缺失的文件为 nil
    private func currentHashes(_ paths: [String]) async throws -> [String?] {
        let batch = try await runner.execute(["hash-object", "--"] + paths, acceptedExitCodes: [0, 128])
        let lines = String(decoding: batch.standardOutput, as: UTF8.self).split(separator: "\n").map(String.init)

        if batch.exitCode == 0, lines.count == paths.count {
            return lines
        }

        // 有文件打不开时整批失败，逐个重算以找出缺失的文件
        var hashes: [String?] = []

        for path in paths {
            let single = try await runner.execute(["hash-object", "--", path], acceptedExitCodes: [0, 128])
            let hash = String(decoding: single.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
            hashes.append(single.exitCode == 0 && !hash.isEmpty ? hash : nil)
        }

        return hashes
    }
}
