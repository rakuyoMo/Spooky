import Foundation

// MARK: - UntrackedPlan

/// 恢复工作区时对未跟踪文件的处理；快照不含未跟踪文件的内容，只有找得回内容的变化才能恢复。
struct UntrackedPlan {
    /// 在目标状态里是未跟踪文件、现在已被跟踪的路径：只从索引拿掉，文件原样留在磁盘上。
    var released: [String] = []

    /// 现在是未跟踪文件、目标状态里没有的路径：内容找得回，先登记进索引，再随恢复从磁盘删除。
    var removed: [String] = []

    /// 目标状态里的未跟踪文件现在不存在：按储藏里的内容重新写出。
    var recreated: [TreeEntry] = []
}

// MARK: - Files

extension RepositoryUndo {
    /// 规划未跟踪文件的处理：会被覆盖或删除的磁盘文件，内容必须能从两份快照或储藏里找回；要补回的未跟踪文件必须找得到内容。
    ///
    /// `stash create` 的树也包含从索引删掉、仍留在磁盘上的 HEAD 文件，这些未跟踪文件的内容同样在快照里。
    func plan(from current: RepositoryState, to target: RepositoryState) async throws -> UntrackedPlan {
        let untrackedNow = Set(current.untracked)
        let untrackedThen = Set(target.untracked)

        // 恢复后成为未跟踪文件的路径，与恢复后不再是未跟踪文件的路径
        let arriving = untrackedThen.subtracting(untrackedNow).sorted()
        let leaving = untrackedNow.subtracting(untrackedThen).sorted()

        // 目标的已跟踪内容里新出现的路径会写到磁盘上，那里可能已有未跟踪或被忽略的文件
        let added = try await addedPaths(from: current.worktree, to: target.worktree)
        let occupied = try await untrackedFiles(among: added)

        let concerned = Set(arriving + leaving + occupied).sorted()
        guard !concerned.isEmpty else { return UntrackedPlan() }

        let now = try await entries(of: current.worktree, at: concerned)
        let then = try await entries(of: target.worktree, at: concerned)
        let sources = try await untrackedSources(in: current.stashes + target.stashes)
        var plan = UntrackedPlan()

        // 目标的已跟踪内容不含的未跟踪文件：现在被跟踪的留在磁盘上，已经不在的从储藏里补回
        for path in arriving where then[path] == nil {
            if now[path] != nil {
                plan.released.append(path)
            } else if let source = sources[path] {
                plan.recreated.append(source)
            } else {
                throw RepositoryUndoError.untrackedFiles
            }
        }

        // 会被覆盖或删除的磁盘文件，内容必须是三处来源之一
        let exposed = Set(leaving + occupied).sorted()
        let hashes: [String]

        do {
            hashes = try await contentHashes(of: exposed)
        } catch is GitError {
            throw RepositoryUndoError.untrackedFiles
        }

        for (path, hash) in zip(exposed, hashes) {
            let known = [now[path], then[path], sources[path]].compactMap { $0?.objectID }
            guard known.contains(hash) else { throw RepositoryUndoError.untrackedFiles }
        }

        plan.removed = leaving.filter { then[$0] == nil }
        return plan
    }

    /// 恢复会改写所有与目标不同的已跟踪文件：标为 assume-unchanged 的文件不能有快照看不到的改动，skip-worktree 不支持。
    func checkHiddenChanges() async throws {
        let listing = try await runner.run(["ls-files", "-v", "-z"])
        var assumed: [String] = []

        for record in listing.split(separator: 0) {
            let text = String(decoding: record, as: UTF8.self)

            guard let tag = text.first, text.dropFirst().first == " " else {
                throw RepositoryReadError.malformedOutput("ls-files")
            }

            if tag == "S" || tag == "s" { throw RepositoryUndoError.hiddenChanges }
            if tag.isLowercase { assumed.append(String(text.dropFirst(2))) }
        }

        guard !assumed.isEmpty else { return }

        let staged = try await runner.run(["--literal-pathspecs", "ls-files", "-s", "-z", "--"] + assumed)
        let objects = Dictionary(
            staged.split(separator: 0).compactMap { record -> (String, String)? in
                let text = String(decoding: record, as: UTF8.self)
                guard let tab = text.firstIndex(of: "\t") else { return nil }
                let fields = text[..<tab].split(separator: " ")
                return fields.count == 3 ? (String(text[text.index(after: tab)...]), String(fields[1])) : nil
            },
            uniquingKeysWith: { first, _ in first }
        )

        // 文件被删掉时读不出内容，同样当作有看不到的改动
        guard
            let hashes = try? await contentHashes(of: assumed),
            zip(assumed, hashes).allSatisfy({ objects[$0] == $1 })
        else { throw RepositoryUndoError.hiddenChanges }
    }

    /// 把索引与已跟踪文件改成目标状态，未跟踪文件按规划处理。
    func restoreFiles(_ target: RepositoryState, plan: UntrackedPlan) async throws {
        if !plan.released.isEmpty {
            _ = try await runner.run(
                ["update-index", "-z", "--force-remove", "--stdin"],
                input: Self.nulList(plan.released)
            )
        }

        if !plan.removed.isEmpty {
            _ = try await runner.run(["update-index", "-z", "--add", "--stdin"], input: Self.nulList(plan.removed))
        }

        // 工作区按目标的已跟踪内容整体复位，不在目标里的已跟踪文件从磁盘删除
        _ = try await runner.run(["read-tree", "-u", "--reset", target.worktree])

        // 补回的文件随写出更新文件信息，之后的单树合并才能把它们移出索引
        if !plan.recreated.isEmpty {
            let records = plan.recreated.map { $0.mode + " " + $0.objectID + "\t" + $0.path }
            _ = try await runner.run(["update-index", "-z", "--index-info"], input: Self.nulList(records))
            _ = try await runner.run(
                ["checkout-index", "-f", "-u", "-z", "--stdin"],
                input: Self.nulList(plan.recreated.map(\.path))
            )
        }

        // 单树合并换成目标索引，内容没变的条目保留原有的文件信息
        _ = try await runner.run(["read-tree", "-m", target.index])
        _ = try await runner.execute(["update-index", "-q", "--refresh"], acceptedExitCodes: [0, 1])
    }
}

// MARK: - Helpers

extension RepositoryUndo {
    /// 目标树比现状树多出的文件路径。
    private func addedPaths(from current: String, to target: String) async throws -> [String] {
        guard current != target else { return [] }

        let output = try await runner.run([
            "diff-tree", "-r", "-z", "--name-only", "--no-renames", "--diff-filter=A", current, target,
        ])
        return Self.nulPaths(output)
    }

    /// 给定路径中磁盘上存在、又不在索引里的文件，包括被忽略的文件。
    private func untrackedFiles(among paths: [String]) async throws -> [String] {
        guard !paths.isEmpty else { return [] }

        let output = try await runner.run(["--literal-pathspecs", "ls-files", "-z", "--others", "--"] + paths)
        return Self.nulPaths(output)
    }

    /// 树里给定路径的文件，以路径为键；不在树里的路径没有对应的值。
    private func entries(of tree: String, at paths: [String]) async throws -> [String: TreeEntry] {
        let output = try await runner.run(
            ["--literal-pathspecs", "ls-tree", "-r", "-z", "--full-tree", tree, "--"] + paths
        )
        let wanted = Set(paths)

        return Dictionary(
            try TreeEntry.parse(output).filter { $0.type == "blob" && wanted.contains($0.path) }.map { ($0.path, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// 储藏里随未跟踪文件一起保存的内容，以路径为键；较新的储藏优先。
    private func untrackedSources(in stashes: [StashRecord]) async throws -> [String: TreeEntry] {
        var sources: [String: TreeEntry] = [:]
        var seen = Set<String>()

        for commit in stashes.compactMap(\.untracked) where seen.insert(commit).inserted {
            let listing = try await runner.run(["ls-tree", "-r", "-z", "--full-tree", commit])

            for entry in try TreeEntry.parse(listing) where entry.type == "blob" && sources[entry.path] == nil {
                sources[entry.path] = entry
            }
        }

        return sources
    }

    /// 文件内容按仓库的过滤规则算出的 blob 哈希，与给定路径一一对应；只计算，不写入对象库。
    private func contentHashes(of paths: [String]) async throws -> [String] {
        guard !paths.isEmpty else { return [] }

        let output = try await runner.run(["hash-object", "--"] + paths)
        let hashes = String(decoding: output, as: UTF8.self).split(separator: "\n").map(String.init)

        guard hashes.count == paths.count, hashes.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.malformedOutput("hash-object")
        }

        return hashes
    }
}

// MARK: - Encoding

extension RepositoryUndo {
    /// 按 NUL 切开的路径列表。
    private static func nulPaths(_ data: Data) -> [String] {
        data.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
    }

    /// 以 NUL 结尾逐条拼接，供 `-z --stdin` 读取。
    static func nulList(_ items: [String]) -> Data {
        Data(items.map { $0 + "\0" }.joined().utf8)
    }
}
