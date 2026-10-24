import Foundation

// MARK: - ReferenceError

/// 引用管理在执行写入前发现的问题，以及需要额外说明的 Git 失败。
public enum ReferenceError: Error, Sendable {
    /// 分支、标签或远端名不合法：为空、以 “-” 开头、含控制字符、含 “@{”，或与 HEAD、完整对象哈希混淆。
    case invalidName(String)

    /// refspec 不符合 Git 的规则。
    case invalidRefspec(String)

    /// 远端地址为空、以 “-” 开头或含控制字符。
    case invalidURL(String)

    /// 分支有上游没有的提交，只能合并或变基，不能快进。
    case diverged(branch: String, upstream: String)

    /// 当前分支随工作区一起更新，要用 Pull，不能直接快进。
    case currentBranch(String)

    /// 远端已有同名分支，重命名远端分支不能覆盖它。
    case remoteBranchExists(String, remote: String)

    /// 远端地址换算不出网页地址，如本机路径或不认识的协议。
    case noWebAddress(String)

    /// 普通删除时部分分支未完全合并；带上这些分支的完整引用名与 Git 原文，供强制删除。
    case unmergedBranches([String], GitError)
}

// MARK: - Name Validation

extension RepositoryReferences {
    /// 远端地址不经 Git 校验：Git 只在连接时解析，这里只拒绝会被当作选项或截断命令的写法。
    public static func validate(url: String) throws {
        let trimmed = url.trimmingCharacters(in: .whitespaces)

        guard
            !trimmed.isEmpty, trimmed == url, !url.hasPrefix("-"),
            !url.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
        else {
            throw ReferenceError.invalidURL(url)
        }
    }

    /// 分支、远端名、标签名与 refspec 的公共前置检查：Git 校验之前先拒绝选项形式、控制字符与引用表达式。
    ///
    /// 名称还不能写成完整对象哈希或 HEAD：这类名字与提交、当前分支混淆，Git 只给警告不拒绝。
    static func isPlausibleName(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("-"), !name.contains("@{"), name != "HEAD" else {
            return false
        }

        // 32 以下与 127 是控制字符，Git 的引用名同样不接受
        guard !name.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
            return false
        }

        let hex = name.utf8.allSatisfy { (48 ... 57).contains($0) || (97 ... 102).contains($0) }
        return !(hex && [40, 64].contains(name.count))
    }

    /// 标签名按 `refs/tags/<名称>` 的完整引用名交给 Git 校验。
    public func validate(tag name: String) async throws {
        guard Self.isPlausibleName(name) else {
            throw ReferenceError.invalidName(name)
        }

        try await checkFormat(["refs/tags/" + name], rejecting: name)
    }

    /// 远端名的规则与 Git 相同：`refs/remotes/<名称>/test` 必须是合法引用名，名称可以含斜杠与点。
    ///
    /// 另外不接受 “=”：远端名会写进 `-c remote.<名称>.…=` 形式的命令行配置，“=” 会改变配置键。
    public func validate(remote name: String) async throws {
        guard Self.isPlausibleName(name), name != ".", name != "..", !name.contains("=") else {
            throw ReferenceError.invalidName(name)
        }

        try await checkFormat(["refs/remotes/" + name + "/test"], rejecting: name)
    }

    /// refspec 可带开头的 “+”，两侧以第一个冒号分开；每个非空侧都要是合法的引用名模式，两侧的 “*” 个数相同。
    ///
    /// fetch 的目标侧不能为空；push 的来源侧可以为空，表示删除远端引用。
    ///
    /// - Parameters:
    ///   - refspec: 要校验的 refspec。
    ///   - push: 是否为 push refspec。
    public func validate(refspec: String, push: Bool) async throws {
        let body = refspec.hasPrefix("+") ? String(refspec.dropFirst()) : refspec
        let sides = body.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let source = sides[0]
        let destination = sides.count == 2 ? sides[1] : ""
        let filled = [source, destination].filter { !$0.isEmpty }

        // 两侧都空、多出冒号、fetch 缺目标或 push 只有冒号时都不合法
        let shapeIsValid = !source.isEmpty || (push && !destination.isEmpty)
        let destinationIsValid = push || !destination.isEmpty
        let starCounts = Set(filled.map { side in side.count { $0 == "*" } })

        guard
            shapeIsValid,
            destinationIsValid,
            !destination.contains(":"),
            starCounts.count <= 1,
            filled.allSatisfy(Self.isPlausibleRefspecSide)
        else {
            throw ReferenceError.invalidRefspec(refspec)
        }

        for side in filled {
            try await checkFormat(["--allow-onelevel", "--refspec-pattern", side], rejecting: refspec) {
                ReferenceError.invalidRefspec($0)
            }
        }
    }

    /// 以 `check-ref-format` 校验；Git 判为不合法时换成说明名称的错误，其余失败照常抛出。
    ///
    /// 普通模式以 1 退出，`--branch` 模式以 128 退出，两者都表示名字不合法。
    func checkFormat(
        _ arguments: [String],
        rejecting value: String,
        error: (String) -> ReferenceError = { .invalidName($0) }
    ) async throws {
        let result = try await runner.execute(["check-ref-format"] + arguments, acceptedExitCodes: [0, 1, 128])

        guard result.exitCode == 0 else {
            throw error(value)
        }
    }
}

// MARK: - Private

extension RepositoryReferences {
    /// refspec 一侧的前置检查：允许 HEAD 与单个 “*”，其余与名称相同。
    private static func isPlausibleRefspecSide(_ side: String) -> Bool {
        side == "HEAD" || isPlausibleName(side.replacingOccurrences(of: "*", with: "x"))
    }
}
