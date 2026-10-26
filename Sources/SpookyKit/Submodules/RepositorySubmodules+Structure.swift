import Foundation

// MARK: - Structure

extension RepositorySubmodules {
    /// 移动子模块到工作区里的新路径，`.gitmodules` 的路径随之更新并暂存；可以同时把名称改成新路径。
    ///
    /// - Parameters:
    ///   - submodule: 配置完整的子模块。
    ///   - newPath: 新的相对路径，上级目录不存在时先建出来。
    ///   - renamesSubmodule: 同时把子模块名称改成新路径。
    public func move(_ submodule: Submodule, to newPath: String, renamesSubmodule: Bool) async throws {
        try await runner.writeTransaction {
            let toplevel = try await toplevel()

            // git mv 不建目标的上级目录
            if let slash = newPath.lastIndex(of: "/") {
                try await RepositoryFiles(runner: runner).createDirectory(toplevel + "/" + newPath[..<slash])
            }

            _ = try await runner.run(["--literal-pathspecs", "mv", "--", submodule.path, newPath])

            if renamesSubmodule, newPath != submodule.name {
                try await rename(name: submodule.name, path: newPath, to: newPath, toplevel: toplevel)
            }
        }
    }

    /// 修改子模块名称：改两处配置里的段名，并把父仓库 Git 目录里的子模块 Git 目录搬到新名称下。
    ///
    /// - Parameters:
    ///   - submodule: 配置完整的子模块。
    ///   - newName: 新名称。
    /// - Throws: 新名称已被别的子模块或 Git 目录占用时抛出 ``SubmoduleError/nameInUse(_:)``。
    public func rename(_ submodule: Submodule, to newName: String) async throws {
        try await runner.writeTransaction {
            try await rename(name: submodule.name, path: submodule.path, to: newName, toplevel: try await toplevel())
        }
    }

    /// 删除子模块；本地配置里的段一并删除，父仓库 Git 目录里的子模块 Git 目录保留，重新添加时可以复用。
    ///
    /// - Parameters:
    ///   - submodule: 子模块，配置不完整的同样可以删除。
    ///   - keepsWorkingTree: 只删除配置与指针，保留工作区里的文件。
    ///   - force: 子模块里有本地改动时仍然删除。
    /// - Throws: 有本地改动且没有强制时抛出 ``SubmoduleError/localModifications``。
    public func delete(_ submodule: Submodule, keepsWorkingTree: Bool, force: Bool) async throws {
        try await runner.writeTransaction {
            let path = submodule.path

            // 子模块里的改动与未跟踪文件由这里检查；之后的 git rm 带 -f，刚添加还没提交的子模块同样能删除
            if !keepsWorkingTree, !force, try await hasLocalModifications(at: path, toplevel: try await toplevel()) {
                throw SubmoduleError.localModifications
            }

            switch submodule.problem {
            case nil where keepsWorkingTree:
                _ = try await runner.run(["--literal-pathspecs", "rm", "-q", "-f", "--cached", "--", path])
                try await removeSharedSection(submodule.name)

            case nil:
                _ = try await runner.run(["--literal-pathspecs", "rm", "-q", "-f", "--", path])

            case .missingPointer, .missingConfiguration:
                // 没有段或没有指针时 git rm 不认这个子模块：分别删掉段与索引里的指针，工作区里的仓库按未跟踪的目录清除
                if submodule.problem == .missingPointer {
                    try await removeSharedSection(submodule.name)
                } else {
                    _ = try await runner.run(["--literal-pathspecs", "rm", "-q", "-f", "--cached", "--", path])
                }

                if !keepsWorkingTree {
                    _ = try await runner.run(["--literal-pathspecs", "clean", "-f", "-f", "-d", "-q", "--", path])
                }
            }

            // 本地配置里的段不随 git rm 删除；没有这一段时 git config 以 128 退出
            _ = try await runner.execute(
                ["config", "--local", "--remove-section", "submodule.\(submodule.name)"],
                acceptedExitCodes: [0, 128]
            )
        }
    }

    /// 修复配置不完整的子模块：缺少配置时按子模块仓库的远端地址补上 `.gitmodules` 的段并初始化，
    /// 缺少指针时按 `.gitmodules` 重新添加，工作区里没有仓库时重新克隆。
    ///
    /// - Parameters:
    ///   - submodule: 配置不完整的子模块。
    ///   - onOutput: 克隆进度。
    /// - Throws: 找不到可用的远端地址时抛出 ``SubmoduleError/missingRemoteURL``。
    public func repair(_ submodule: Submodule, onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil) async throws {
        try await runner.writeTransaction {
            let path = submodule.path

            switch submodule.problem {
            case nil:
                return

            case .missingConfiguration:
                guard
                    try await isRepositoryRoot(path, toplevel: try await toplevel()),
                    let url = try await remoteURL(of: submodule)
                else { throw SubmoduleError.missingRemoteURL }

                // 名称取路径，与 git submodule add 的默认名称相同；内嵌的 Git 目录随后移进父仓库的 Git 目录
                _ = try await runner.run(Self.configCommand(.shared) + ["submodule.\(path).path", path])
                _ = try await runner.run(Self.configCommand(.shared) + ["submodule.\(path).url", url])
                _ = try await runner.run(["--literal-pathspecs", "add", "--", ".gitmodules"])
                _ = try await runner.run(["--literal-pathspecs", "submodule", "init", "--", path])
                _ = try await runner.run(["--literal-pathspecs", "submodule", "absorbgitdirs", "--", path])

            case .missingPointer:
                guard let url = submodule.shared?.url else {
                    throw SubmoduleError.missingRemoteURL
                }

                _ = try await runner.execute(
                    ["submodule", "add", "--progress", "--force", "--name", submodule.name, "--", url, path],
                    onOutput: onOutput
                )
            }
        }
    }
}

// MARK: - Private

extension RepositorySubmodules {
    /// 从一个绝对路径到另一个绝对路径的相对写法。
    static func relativePath(from base: String, to target: String) -> String {
        let baseParts = base.split(separator: "/")
        let targetParts = target.split(separator: "/")
        let common = zip(baseParts, targetParts).prefix { $0 == $1 }.count
        let parts = Array(repeating: "..", count: baseParts.count - common) + targetParts.dropFirst(common).map(String.init)

        return parts.isEmpty ? "." : parts.joined(separator: "/")
    }

    /// 改名的各个步骤，在调用方持有的写事务里执行。
    ///
    /// 子模块的 Git 目录在父仓库的 `modules/<旧名称>` 下时搬到新名称下；已检出时按 Git 的写法以相对路径
    /// 重写子模块的 `.git` 文件与 `core.worktree`，最后改 `.gitmodules` 与本地配置里的段名。
    private func rename(name: String, path: String, to newName: String, toplevel: String) async throws {
        let shared = try await runner.execute(
            ["config", "-z", "--file", ".gitmodules", "--get-regexp", Self.settingsPattern],
            acceptedExitCodes: [0, 1]
        )

        guard !(try Self.parseSettings(shared.standardOutput).contains { $0.name == newName }) else {
            throw SubmoduleError.nameInUse(newName)
        }

        let current = try await gitDirectory(named: name)
        let target = try await gitDirectory(named: newName)

        guard !(try await exists(target)) else {
            throw SubmoduleError.nameInUse(newName)
        }

        if try await exists(current) {
            let files = RepositoryFiles(runner: runner)
            let worktree = toplevel + "/" + path
            let populated = try await isRepositoryRoot(path, toplevel: toplevel)

            if let slash = target.lastIndex(of: "/") {
                try await files.createDirectory(String(target[..<slash]))
            }

            try await files.move(current, to: target)

            // 搬过去之后原来的 core.worktree 已指向别处，子模块里的 Git 无法启动，按文件改写它的配置
            if populated {
                let gitfile = "gitdir: " + Self.relativePath(from: worktree, to: target) + "\n"
                try await files.write(Data(gitfile.utf8), to: worktree + "/.git")
                _ = try await runner.run(
                    ["config", "--file", target + "/config", "core.worktree", Self.relativePath(from: target, to: worktree)]
                )
            }
        }

        _ = try await runner.run(
            ["config", "--file", ".gitmodules", "--rename-section", "submodule.\(name)", "submodule.\(newName)"]
        )

        // 没有初始化的子模块在本地配置里没有这一段，此时 git config 以 128 退出
        _ = try await runner.execute(
            ["config", "--local", "--rename-section", "submodule.\(name)", "submodule.\(newName)"],
            acceptedExitCodes: [0, 128]
        )
    }

    /// 删掉 `.gitmodules` 里的一段并暂存；没有这一段时 git config 以 128 退出。
    private func removeSharedSection(_ name: String) async throws {
        _ = try await runner.execute(
            ["config", "--file", ".gitmodules", "--remove-section", "submodule.\(name)"],
            acceptedExitCodes: [0, 128]
        )
        _ = try await runner.run(["--literal-pathspecs", "add", "--", ".gitmodules"])
    }

    /// 路径上是不是一个独立仓库的工作区根目录；不是时在那里执行的 Git 会找到父仓库，不能用来读取子模块。
    private func isRepositoryRoot(_ path: String, toplevel: String) async throws -> Bool {
        let result = try await runner.execute(["-C", path, "rev-parse", "--show-toplevel"], acceptedExitCodes: [0, 128])
        let root = String(decoding: result.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)

        return result.exitCode == 0 && root == toplevel + "/" + path
    }

    /// 路径上的独立仓库里有没有改动或未跟踪的文件；路径上没有仓库时没有。
    private func hasLocalModifications(at path: String, toplevel: String) async throws -> Bool {
        guard try await isRepositoryRoot(path, toplevel: toplevel) else {
            return false
        }

        return !(try await runner.run(["-C", path, "status", "--porcelain=v2", "-z", "--untracked-files=all"]).isEmpty)
    }

    /// 父仓库工作区根目录的绝对路径。
    private func toplevel() async throws -> String {
        let output = try await runner.run(["rev-parse", "--show-toplevel"])
        let path = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard path.hasPrefix("/"), !path.contains("\n") else {
            throw RepositoryReadError.malformedOutput("rev-parse")
        }

        return path
    }

    /// 仓库所在机器上的路径是否存在。
    private func exists(_ path: String) async throws -> Bool {
        guard let remote = runner.remote else {
            return FileManager.default.fileExists(atPath: path)
        }

        return try await remote.inspect([path]) == [true]
    }
}
