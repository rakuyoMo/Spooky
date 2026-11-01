import Foundation

// MARK: - SubmoduleFileState

/// `.gitmodules` 在索引与工作区里的样子；增删子模块之前记下，撤销时整份换回，各段在文件里的顺序随之复原。
public struct SubmoduleFileState: Sendable, Equatable {
    /// 索引里 stage 0 的一条记录去掉路径后的 “模式 对象”；不在索引里时为 nil。
    let staged: String?

    /// 工作区里的内容；没有这个文件时为 nil。
    let content: Data?

    /// 工作区里的全部配置项，按文件中的顺序。
    let entries: [ConfigEntry]

    /// 去掉一个子模块的段之后的配置项；撤销前据此核对别的段没有变。
    func entries(excluding name: String) -> [ConfigEntry] {
        entries.filter { !RepositorySubmodules.isSetting($0, of: name) }
    }
}

// MARK: - SubmoduleAddition

/// 添加子模块之前记下的内容，撤销添加时据此恢复。
public struct SubmoduleAddition: Sendable, Equatable {
    /// 子模块在工作区里的相对路径。
    let path: String

    /// 添加之前的 `.gitmodules`。
    let file: SubmoduleFileState
}

// MARK: - SubmoduleRemoval

/// 删除子模块之前记下的内容，撤销删除时据此恢复。
public struct SubmoduleRemoval: Sendable, Equatable {
    /// 删除会一起删掉的工作区。
    enum Worktree: Sendable, Equatable {
        /// 检出的子模块仓库：Git 目录不在工作区里，删掉工作区后仍在，HEAD 也记在其中，撤销时据此重新检出。
        case repository(gitDirectory: String)

        /// 没有检出的子模块留下的空目录。
        case directory
    }

    /// 子模块名称。
    let name: String

    /// 子模块在工作区里的相对路径。
    let path: String

    /// 索引里的子模块指针；缺少指针的子模块为 nil。
    let pointer: String?

    /// 删除之前的 `.gitmodules`。
    let file: SubmoduleFileState

    /// 仓库本地配置里这个子模块的段，按配置文件中的顺序。
    let localSettings: [ConfigEntry]

    /// 删除会一起删掉的工作区；保留工作区、或路径上本来就没有东西时为 nil。
    let worktree: Worktree?
}

// MARK: - SubmoduleSettingChange

/// 修改仓库本地配置里子模块的一项设置之前记下的内容，撤销时写回。
public struct SubmoduleSettingChange: Sendable, Equatable {
    /// 写入用的键，如 `submodule.<名称>.url`。
    let key: String

    /// 修改之前的值；原来没有设置时为 nil。
    let previous: String?

    /// 修改之后的值；删除这一项时为 nil。
    let current: String?
}

// MARK: - SubmoduleCheckout

/// 在子模块里检出别的版本之前记下的内容，撤销时据此检出回去。
public struct SubmoduleCheckout: Sendable, Equatable {
    /// 子模块的 HEAD。
    enum Head: Sendable, Equatable {
        /// 停在分支上，值是分支的短名。
        case branch(String)

        /// 分离 HEAD，值是检出的提交。
        case detached(String)
    }

    /// 子模块在工作区里的相对路径。
    let path: String

    /// 检出之前的 HEAD。
    let previous: Head

    /// 检出之后应有的 HEAD；撤销前据此核对子模块没有在别处换过版本。
    let current: Head
}

// MARK: - Structure Undo

extension RepositorySubmodules {
    /// 添加子模块之前记下 `.gitmodules`。
    ///
    /// - Parameter path: 要添加的子模块在工作区里的相对路径。
    public func additionRecord(at path: String) async throws -> SubmoduleAddition {
        SubmoduleAddition(path: path, file: try await fileState(toplevel: try await toplevel()))
    }

    /// 撤销添加子模块：删掉它，子模块的 Git 目录留在仓库里，再把 `.gitmodules` 整份换回添加之前。
    ///
    /// 前提是这个路径上还是一个配置完整的子模块，`.gitmodules` 里别的段与添加之前相同。
    ///
    /// - Throws: 子模块里有改动或未跟踪的文件时抛出 ``SubmoduleError/localModifications``，不做任何改动。
    public func undoAdd(_ addition: SubmoduleAddition) async throws {
        try await runner.writeTransaction {
            let toplevel = try await toplevel()
            let file = try await fileState(toplevel: toplevel)

            guard
                let submodule = try await list().first(where: { $0.path == addition.path && $0.isValid }),
                file.entries(excluding: submodule.name) == addition.file.entries(excluding: submodule.name)
            else {
                throw RepositoryUndoError.repositoryChanged
            }

            try await delete(submodule, keepsWorkingTree: false, force: false)
            try await restore(addition.file, toplevel: toplevel)
        }
    }

    /// 删除子模块之前记下撤销要用的内容：指针、`.gitmodules`、本地配置里的段，以及会一起删掉的工作区。
    ///
    /// - Parameters:
    ///   - submodule: 要删除的子模块。
    ///   - keepsWorkingTree: 删除时保留工作区里的文件。
    /// - Throws: 要删掉的工作区里有找不回的内容时抛出：子模块里有改动或未跟踪的文件时抛出
    ///   ``SubmoduleError/localModifications``，Git 目录就在工作区里时抛出 ``RepositoryUndoError/untrackedFiles``；
    ///   指针处于冲突中时抛出 ``RepositoryUndoError/unresolvedConflicts``。
    public func removalRecord(of submodule: Submodule, keepsWorkingTree: Bool) async throws -> SubmoduleRemoval {
        let toplevel = try await toplevel()

        async let file = fileState(toplevel: toplevel)
        async let settings = localSettings(of: submodule.name)
        async let gitlinks = pointers([submodule.path])

        let worktree = keepsWorkingTree ? nil : try await removedWorktree(at: submodule.path, toplevel: toplevel)
        let gitlink = try await gitlinks[submodule.path]

        // 冲突中的指针没有唯一的提交可以写回
        guard gitlink != .some(nil) else {
            throw RepositoryUndoError.unresolvedConflicts
        }

        return SubmoduleRemoval(
            name: submodule.name,
            path: submodule.path,
            pointer: gitlink ?? nil,
            file: try await file,
            localSettings: try await settings,
            worktree: worktree
        )
    }

    /// 撤销删除子模块：重新检出删掉的工作区，写回索引里的指针，把 `.gitmodules` 整份换回删除之前，再写回本地配置里的段。
    ///
    /// 前提是路径上没有已跟踪的内容，`.gitmodules` 除了这一段与删除之前相同，本地配置里没有这个名称的段；
    /// 删掉了工作区时路径上也没有未跟踪的内容，要重新检出的子模块的 Git 目录还在。
    public func undoDelete(_ removal: SubmoduleRemoval) async throws {
        try await runner.writeTransaction {
            let toplevel = try await toplevel()

            guard try await canRestore(removal, toplevel: toplevel) else {
                throw RepositoryUndoError.repositoryChanged
            }

            try await restoreWorktree(of: removal, toplevel: toplevel)

            if let pointer = removal.pointer {
                let record = Self.gitlinkMode + " " + pointer + "\t" + removal.path + "\0"
                _ = try await runner.run(["update-index", "-z", "--index-info"], input: Data(record.utf8))
            }

            try await restore(removal.file, toplevel: toplevel)

            // 只写键不写值的项写回为 true，Git 对布尔项按同样的意思读取
            for entry in removal.localSettings {
                _ = try await runner.run(["config", "--local", "--add", entry.key, entry.value ?? "true"])
            }
        }
    }

    /// 撤销把子模块移到 `newPath`：从新路径移回原路径，移动时同时改了名称的再改回原名。
    ///
    /// 前提是新路径上还是这个子模块，原路径与原名称都空着。
    ///
    /// - Parameters:
    ///   - submodule: 移动之前的子模块。
    ///   - newPath: 移动到的路径。
    ///   - renamesSubmodule: 移动时是否把名称改成了新路径。
    public func undoMove(_ submodule: Submodule, to newPath: String, renamesSubmodule: Bool) async throws {
        try await runner.writeTransaction {
            let toplevel = try await toplevel()
            let movedName = renamesSubmodule ? newPath : submodule.name
            let current = try await list()
            let occupied = try await exists(toplevel + "/" + submodule.path)
            let nameTaken = movedName == submodule.name ? false : try await isNameTaken(submodule.name, in: current)

            guard
                let moved = current.first(where: { $0.path == newPath && $0.isValid }),
                moved.name == movedName,
                !current.contains(where: { $0.path == submodule.path }),
                !occupied,
                !nameTaken
            else {
                throw RepositoryUndoError.repositoryChanged
            }

            // 改名对 `.gitmodules` 的改动没有暂存，git mv 遇到它会拒绝，所以先改回名称再移回原路径
            if movedName != submodule.name {
                try await rename(name: movedName, path: newPath, to: submodule.name, toplevel: toplevel)
            }

            // 不改名的移动只用到子模块的路径
            try await move(moved, to: submodule.path, renamesSubmodule: false)
        }
    }

    /// 撤销把子模块改名为 `newName`：改回原名；前提是新名称的子模块还在原来的路径上，原名称空着。
    ///
    /// - Parameters:
    ///   - submodule: 改名之前的子模块。
    ///   - newName: 改成的名称。
    public func undoRename(_ submodule: Submodule, to newName: String) async throws {
        try await runner.writeTransaction {
            let current = try await list()

            guard
                current.contains(where: { $0.name == newName && $0.path == submodule.path && $0.isValid }),
                try await !isNameTaken(submodule.name, in: current)
            else {
                throw RepositoryUndoError.repositoryChanged
            }

            try await rename(name: newName, path: submodule.path, to: submodule.name, toplevel: try await toplevel())
        }
    }
}

// MARK: - Setting Undo

extension RepositorySubmodules {
    /// 修改本地配置里的子模块地址之前记下原值；新值与原值相同时返回 nil。
    ///
    /// - Parameters:
    ///   - submodule: 子模块。
    ///   - url: 新地址。
    public func localURLChange(of submodule: Submodule, to url: String) async throws -> SubmoduleSettingChange? {
        try await localSettingChange(of: submodule.name, variable: "url", to: url)
    }

    /// 修改或删除本地配置里子模块的一个选项之前记下原值；新值与原值相同时返回 nil。
    ///
    /// - Parameters:
    ///   - option: 选项。
    ///   - submodule: 子模块。
    ///   - value: 新值；nil 表示删除。
    public func localOptionChange(
        _ option: SubmoduleOption,
        of submodule: Submodule,
        to value: String?
    ) async throws -> SubmoduleSettingChange? {
        try await localSettingChange(of: submodule.name, variable: option.rawValue, to: value)
    }

    /// 撤销修改本地配置里子模块的一项设置：写回原值，原来没有设置的删掉；前提是这一项仍是修改之后的值。
    public func undoSettingChange(_ change: SubmoduleSettingChange) async throws {
        try await runner.writeTransaction {
            guard try await localValue(of: change.key) == change.current else {
                throw RepositoryUndoError.repositoryChanged
            }

            guard let previous = change.previous else {
                _ = try await runner.run(["config", "--local", "--unset", change.key])
                return
            }

            _ = try await runner.run(["config", "--local", change.key, previous])
        }
    }
}

// MARK: - Revision Undo

extension RepositorySubmodules {
    /// 在子模块里检出别的版本之前记下子模块的 HEAD，以及检出之后应有的 HEAD。
    ///
    /// - Parameters:
    ///   - revision: 要检出的分支或标签。
    ///   - submodule: 已检出的子模块。
    public func checkoutRecord(
        of revision: SubmoduleRevision,
        in submodule: Submodule
    ) async throws -> SubmoduleCheckout {
        let previous = try await head(of: submodule.path)

        guard revision.isTag else {
            return SubmoduleCheckout(path: submodule.path, previous: previous, current: .branch(revision.name))
        }

        // 检出标签会以分离 HEAD 停在它所指的提交上
        let tagged = try await commit(of: revision.reference, in: submodule.path)

        return SubmoduleCheckout(path: submodule.path, previous: previous, current: .detached(tagged))
    }

    /// 撤销在子模块里检出别的版本：检出回原来的分支，原来是分离 HEAD 的以分离 HEAD 检出原来的提交。
    ///
    /// 前提是子模块的 HEAD 仍是检出之后的样子。子模块里的改动与检出时一样交给 Git：不冲突的带到原来的版本上，
    /// 冲突时 Git 拒绝检出、子模块不变。
    public func undoCheckout(_ checkout: SubmoduleCheckout) async throws {
        try await runner.writeTransaction {
            guard try await head(of: checkout.path) == checkout.current else {
                throw RepositoryUndoError.repositoryChanged
            }

            let target: [String] =
                switch checkout.previous {
                case .branch(let name): [name]
                case .detached(let commit): ["--detach", commit]
                }

            _ = try await runner.run(["-C", checkout.path, "checkout"] + target + ["--"])
        }
    }
}

// MARK: - Helpers

extension RepositorySubmodules {
    /// 配置项是否属于这个名称的子模块段：键是 `submodule.<名称>.<变量>`，名称可以含句点，变量名里没有。
    static func isSetting(_ entry: ConfigEntry, of name: String) -> Bool {
        let prefix = "submodule." + name + "."
        return entry.key.hasPrefix(prefix) && !entry.key.dropFirst(prefix.count).contains(".")
    }

    /// `ls-files -s -z` 里 stage 0 的一条记录去掉路径后的 “模式 对象”；没有记录时为 nil。
    ///
    /// 每条记录是 “模式 对象 阶段、制表符、路径、NUL”。
    ///
    /// - Throws: 文件处于冲突中时抛出 ``RepositoryUndoError/unresolvedConflicts``。
    static func stagedRecord(_ data: Data) throws -> String? {
        guard let record = data.split(separator: 0).first else {
            return nil
        }

        guard let tab = record.firstIndex(of: 9) else {
            throw RepositoryReadError.malformedOutput("ls-files")
        }

        let fields = String(decoding: record[..<tab], as: UTF8.self).split(separator: " ")

        guard fields.count == 3, GitObjectID.isValid(String(fields[1])) else {
            throw RepositoryReadError.malformedOutput("ls-files")
        }

        guard fields[2] == "0" else {
            throw RepositoryUndoError.unresolvedConflicts
        }

        return String(fields[0]) + " " + String(fields[1])
    }

    /// 撤销删除的前提，见 ``undoDelete(_:)``。
    private func canRestore(_ removal: SubmoduleRemoval, toplevel: String) async throws -> Bool {
        async let file = fileState(toplevel: toplevel)
        async let settings = localSettings(of: removal.name)
        async let tracked = runner.run(["--literal-pathspecs", "ls-files", "-z", "--", removal.path])

        guard
            try await file.entries == removal.file.entries(excluding: removal.name),
            try await settings.isEmpty,
            try await tracked.isEmpty
        else { return false }

        switch removal.worktree {
        case nil:
            return true

        case .directory:
            return try await isVacant(removal.path)

        case .repository(let gitDirectory):
            guard try await isVacant(removal.path) else { return false }
            return try await exists(gitDirectory)
        }
    }

    /// 重新检出删掉的工作区：按 Git 的写法以相对路径写回 `.git` 文件，再按子模块仓库自己的 HEAD 检出全部文件。
    private func restoreWorktree(of removal: SubmoduleRemoval, toplevel: String) async throws {
        let files = RepositoryFiles(runner: runner)
        let worktree = toplevel + "/" + removal.path

        switch removal.worktree {
        case nil:
            return

        case .directory:
            try await files.createDirectory(worktree)

        case .repository(let gitDirectory):
            try await files.createDirectory(worktree)

            let gitfile = "gitdir: " + Self.relativePath(from: worktree, to: gitDirectory) + "\n"
            try await files.write(Data(gitfile.utf8), to: worktree + "/.git")

            // HEAD 与 core.worktree 都在 Git 目录里，删掉工作区时没有变
            _ = try await runner.run(["-C", removal.path, "checkout", "-f", "-q"])
        }
    }

    /// 把 `.gitmodules` 的工作区内容与索引记录换回记下的样子；原来没有的从工作区与索引里删掉。
    private func restore(_ file: SubmoduleFileState, toplevel: String) async throws {
        let files = RepositoryFiles(runner: runner)
        let path = toplevel + "/.gitmodules"

        if let content = file.content {
            try await files.write(content, to: path)
        } else if try await exists(path) {
            try await files.remove([path])
        }

        if let staged = file.staged {
            _ = try await runner.run(
                ["update-index", "-z", "--index-info"],
                input: Data((staged + "\t.gitmodules\0").utf8)
            )
        } else {
            _ = try await runner.run(
                ["update-index", "-z", "--force-remove", "--stdin"],
                input: Data(".gitmodules\0".utf8)
            )
        }

        // 写回的索引记录没有文件信息，刷新后内容相同的文件不再显示为改动
        _ = try await runner.execute(["update-index", "-q", "--refresh"], acceptedExitCodes: [0, 1])
    }

    /// 删除会一起删掉的工作区。
    ///
    /// - Throws: 工作区里有找不回的内容时抛出，见 ``removalRecord(of:keepsWorkingTree:)``。
    private func removedWorktree(at path: String, toplevel: String) async throws -> SubmoduleRemoval.Worktree? {
        guard try await isRepositoryRoot(path, toplevel: toplevel) else {
            return try await exists(toplevel + "/" + path) ? .directory : nil
        }

        // 子模块里的改动与未跟踪文件随工作区删掉，找不回来
        guard try await !hasLocalModifications(at: path, toplevel: toplevel) else {
            throw SubmoduleError.localModifications
        }

        let output = try await runner.run(["-C", path, "rev-parse", "--absolute-git-dir"])
        let gitDirectory = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard gitDirectory.hasPrefix("/"), !gitDirectory.contains("\n") else {
            throw RepositoryReadError.malformedOutput("rev-parse")
        }

        // Git 目录就在工作区里时随工作区一起删掉，仓库的历史找不回来
        guard !gitDirectory.hasPrefix(toplevel + "/" + path + "/") else {
            throw RepositoryUndoError.untrackedFiles
        }

        return .repository(gitDirectory: gitDirectory)
    }

    /// 读出 `.gitmodules` 现在在索引与工作区里的样子。
    private func fileState(toplevel: String) async throws -> SubmoduleFileState {
        let path = toplevel + "/.gitmodules"

        async let staged = runner.run(["--literal-pathspecs", "ls-files", "-s", "-z", "--", ".gitmodules"])
        async let settings = runner.execute(
            ["config", "-z", "--file", ".gitmodules", "--get-regexp", "."],
            acceptedExitCodes: [0, 1]
        )
        async let contents = RepositoryFiles(runner: runner).read([path])

        return SubmoduleFileState(
            staged: try Self.stagedRecord(try await staged),
            content: try await contents[path],
            entries: ConfigEntry.parse(try await settings.standardOutput)
        )
    }

    /// 名称是否已被别的子模块或留在仓库里的 Git 目录占用。
    private func isNameTaken(_ name: String, in submodules: [Submodule]) async throws -> Bool {
        guard !submodules.contains(where: { $0.name == name }) else {
            return true
        }

        return try await exists(try await gitDirectory(named: name))
    }

    /// 路径上没有未跟踪的文件或仓库；空目录不算。
    private func isVacant(_ path: String) async throws -> Bool {
        try await runner.run(["--literal-pathspecs", "ls-files", "-z", "--others", "--", path]).isEmpty
    }

    /// 记下本地配置里一项设置的原值；新值与原值相同时返回 nil。
    private func localSettingChange(
        of name: String,
        variable: String,
        to value: String?
    ) async throws -> SubmoduleSettingChange? {
        let key = "submodule." + name + "." + variable
        let previous = try await localValue(of: key)

        guard previous != value else {
            return nil
        }

        return SubmoduleSettingChange(key: key, previous: previous, current: value)
    }

    /// 本地配置里一个键现在的值；同一个键出现多次时 Git 采用最后一个，只写键不写值的按 `true` 读取。
    private func localValue(of key: String) async throws -> String? {
        // Git 输出的变量名是小写，子模块名称保留原样
        let variable = key.lastIndex(of: ".").map { key.index(after: $0) } ?? key.endIndex
        let target = String(key[..<variable]) + key[variable...].lowercased()

        return try await localEntries().last { $0.key == target }.map { $0.value ?? "true" }
    }

    /// 本地配置里这个名称的子模块段，按配置文件中的顺序。
    private func localSettings(of name: String) async throws -> [ConfigEntry] {
        try await localEntries().filter { Self.isSetting($0, of: name) }
    }

    /// 本地配置里子模块各段的全部项，按配置文件中的顺序。
    private func localEntries() async throws -> [ConfigEntry] {
        let result = try await runner.execute(
            ["config", "-z", "--local", "--get-regexp", Self.settingsPattern],
            acceptedExitCodes: [0, 1]
        )

        return ConfigEntry.parse(result.standardOutput)
    }

    /// 子模块现在的 HEAD：停在分支上时是分支的短名，否则是检出的提交。
    private func head(of path: String) async throws -> SubmoduleCheckout.Head {
        let output = try await runner.run(["-C", path, "branch", "--show-current"])
        let branch = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard branch.isEmpty else {
            return .branch(branch)
        }

        return .detached(try await commit(of: "HEAD", in: path))
    }

    /// 子模块里一个版本所指的提交；附注标签剥到它所指的提交。
    private func commit(of revision: String, in path: String) async throws -> String {
        let output = try await runner.run(
            ["-C", path, "rev-parse", "--verify", "--end-of-options", revision + "^{commit}"]
        )
        let commit = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard GitObjectID.isValid(commit) else {
            throw RepositoryReadError.malformedOutput("rev-parse")
        }

        return commit
    }
}
