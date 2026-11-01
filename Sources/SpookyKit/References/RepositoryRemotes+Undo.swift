import Foundation

// MARK: - RemoteRemovalRecord

/// 删除远端之前记下的内容，撤销删除时据此恢复。
public struct RemoteRemovalRecord: Sendable, Equatable {
    /// 要删除的远端名。
    let names: [String]

    /// 这些远端在仓库配置里的全部项，按配置文件中的顺序。
    let settings: [ConfigEntry]

    /// 这些远端的远端跟踪分支指向的对象，以完整引用名为键；符号引用记在 ``symbolicReferences``。
    let references: [String: String]

    /// 远端跟踪分支里的符号引用，如 `refs/remotes/origin/HEAD`，值是它指向的引用名。
    let symbolicReferences: [String: String]

    /// 跟踪这些远端或推送到这些远端的分支，各分支的配置段整段记下。
    let branchSettings: [BranchSetting]

    /// `remote.pushDefault` 是其中一个远端时它的值。
    let pushDefault: String?

    /// 删除远端时 Git 会从分支段里去掉的项：指向这些远端的 `remote` 与同一分支的 `merge`，以及指向它们的 `pushRemote`。
    ///
    /// - Parameters:
    ///   - section: 这一项所在的分支段。
    ///   - names: 删除的远端名。
    static func isTracking(_ setting: BranchSetting, in section: [BranchSetting], names: Set<String>) -> Bool {
        let prefix = "branch." + setting.branch + "."

        switch setting.key {
        case prefix + "remote", prefix + "pushremote":
            return setting.value.map(names.contains) ?? false

        case prefix + "merge":
            return section.contains { $0.key == prefix + "remote" && $0.value.map(names.contains) ?? false }

        default:
            return false
        }
    }

    /// 相关的分支段是否只少了删除远端时去掉的项：其余的项都还在、顺序不变，也没有多出来的项。
    ///
    /// 不同版本的 Git 去掉的范围不完全相同，所以跟踪设置留着与去掉都算。
    ///
    /// - Parameter current: 现在全部的分支段。
    func canRestoreBranchSettings(from current: [BranchSetting]) -> Bool {
        let names = Set(names)

        return Dictionary(grouping: branchSettings, by: \.branch).allSatisfy { branch, section in
            let now = current.filter { $0.branch == branch }
            return section.filter { !Self.isTracking($0, in: section, names: names) || now.contains($0) } == now
        }
    }
}

// MARK: - Undo

extension RepositoryRemotes {
    /// 这个远端在仓库配置里的全部项，按配置文件中的顺序；修改远端设置之前记下，撤销时整段换回。
    public func settings(of name: String) async throws -> [ConfigEntry] {
        try await localEntries().filter { RemoteConfiguration.remoteName(inKey: $0.key) == name }
    }

    /// 撤销添加远端：前提是这个远端还在。
    public func undoAdd(_ name: String) async throws {
        try await runner.writeTransaction {
            guard try await !settings(of: name).isEmpty else {
                throw RepositoryUndoError.repositoryChanged
            }

            try await remove(name)
        }
    }

    /// 撤销把 `name` 改成 `newName`：前提是 `newName` 还在、`name` 上没有远端；远端跟踪分支与跟踪设置随之改回。
    public func undoRename(_ name: String, to newName: String) async throws {
        try await runner.writeTransaction {
            let names = Set(try await localEntries().compactMap { RemoteConfiguration.remoteName(inKey: $0.key) })

            guard names.contains(newName), !names.contains(name) else {
                throw RepositoryUndoError.repositoryChanged
            }

            try await rename(newName, to: name)
        }
    }

    /// 把远端的配置段换回记下的项，撤销修改地址、refspec 与 “获取全部”；前提是这个远端还在。
    ///
    /// - Parameter settings: 修改之前由 ``settings(of:)`` 读出的项。
    public func restoreSettings(_ settings: [ConfigEntry], of name: String) async throws {
        try await runner.writeTransaction {
            guard try await !self.settings(of: name).isEmpty else {
                throw RepositoryUndoError.repositoryChanged
            }

            _ = try await runner.run(["config", "--local", "--remove-section", "remote." + name])
            try await add(settings)
        }
    }

    /// 删除远端之前记下撤销要用的内容：配置段、远端跟踪分支、跟踪或推送到它们的分支段，以及 `remote.pushDefault`。
    ///
    /// 远端名按字面比较，不拼进正则。
    public func removalRecord(of names: [String]) async throws -> RemoteRemovalRecord {
        guard !names.isEmpty else {
            throw RepositoryReadError.invalidQuery
        }

        async let entries = localEntries()
        async let branches = RepositoryUndo(runner: runner).branchSettings()
        async let listing = trackingReferences(of: names)

        let wanted = Set(names)
        let settings = try await entries
        let references = try await listing
        let branchSettings = try await branches

        // 有一项指向这些远端的分支整段记下
        let sections = Dictionary(grouping: branchSettings, by: \.branch)
            .filter { _, section in
                section.contains { RemoteRemovalRecord.isTracking($0, in: section, names: wanted) }
            }

        // 同一个键出现多次时 Git 采用最后一个
        let pushDefault = settings.last { $0.key == "remote.pushdefault" }?.value

        return RemoteRemovalRecord(
            names: names,
            settings: settings.filter { RemoteConfiguration.remoteName(inKey: $0.key).map(wanted.contains) ?? false },
            references: references.objects,
            symbolicReferences: references.symbolic,
            branchSettings: branchSettings.filter { sections[$0.branch] != nil },
            pushDefault: pushDefault.flatMap { wanted.contains($0) ? $0 : nil }
        )
    }

    /// 撤销删除远端：建回远端跟踪分支，按原顺序写回配置段，再把相关的分支段与 `remote.pushDefault` 恢复原样。
    ///
    /// 前提是这些名字上都没有远端，且相关的分支段只少了删除远端时去掉的项；只补现在缺少的引用。
    public func undoRemove(_ record: RemoteRemovalRecord) async throws {
        try await runner.writeTransaction {
            let undo = RepositoryUndo(runner: runner)
            let wanted = Set(record.names)
            let entries = try await localEntries()
            let current = try await undo.branchSettings()

            guard
                !entries.contains(where: { RemoteConfiguration.remoteName(inKey: $0.key).map(wanted.contains) ?? false }),
                record.canRestoreBranchSettings(from: current)
            else {
                throw RepositoryUndoError.repositoryChanged
            }

            // 引用的对象可能已被清理，最容易失败，先在一个事务里建回；整批失败时配置不动
            try await restoreReferences(record)
            try await add(record.settings)

            let branches = Set(record.branchSettings.map(\.branch))
            try await undo.restoreBranchSettings(
                from: current.filter { branches.contains($0.branch) },
                to: record.branchSettings
            )

            if let pushDefault = record.pushDefault, !entries.contains(where: { $0.key == "remote.pushdefault" }) {
                _ = try await runner.run(["config", "--local", "remote.pushDefault", pushDefault])
            }
        }
    }
}

// MARK: - Private

extension RepositoryRemotes {
    /// 现在缺少的远端跟踪分支在一个 `update-ref --stdin` 事务里建回，符号引用随后指回原处。
    private func restoreReferences(_ record: RemoteRemovalRecord) async throws {
        let existing = try await trackingReferences(of: record.names)
        var commands = Data()

        for (name, object) in record.references.sorted(by: { $0.key < $1.key }) where existing.objects[name] == nil {
            commands.append(Data(("create " + name + "\0" + object + "\0").utf8))
        }

        if !commands.isEmpty {
            _ = try await runner.run(["update-ref", "-m", "undo", "-z", "--stdin"], input: commands)
        }

        for (name, target) in record.symbolicReferences.sorted(by: { $0.key < $1.key })
            where existing.symbolic[name] == nil && existing.objects[name] == nil
        {
            _ = try await runner.run(["symbolic-ref", "-m", "undo", name, target])
        }
    }

    /// 这些远端的远端跟踪分支：普通引用指向的对象，与符号引用指向的引用名。
    ///
    /// 引用名里不会有换行与 NUL，所以每行一个引用，字段以 NUL 分隔。
    private func trackingReferences(
        of names: [String]
    ) async throws -> (objects: [String: String], symbolic: [String: String]) {
        let output = try await runner.run(
            ["for-each-ref", "--format=%(refname)%00%(objectname)%00%(symref)"] + names.map { "refs/remotes/" + $0 + "/" }
        )

        var objects: [String: String] = [:]
        var symbolic: [String: String] = [:]

        for line in output.split(separator: 10) {
            let fields = line.split(separator: 0, omittingEmptySubsequences: false)
                .map { String(decoding: $0, as: UTF8.self) }

            guard
                fields.count == 3,
                fields[0].hasPrefix("refs/remotes/"),
                GitObjectID.isValid(fields[1])
            else {
                throw RepositoryReadError.malformedOutput("for-each-ref")
            }

            if fields[2].isEmpty {
                objects[fields[0]] = fields[1]
            } else {
                symbolic[fields[0]] = fields[2]
            }
        }

        return (objects, symbolic)
    }

    /// 仓库自己的配置文件里 `remote.` 开头的全部项，按配置文件中的顺序。
    private func localEntries() async throws -> [ConfigEntry] {
        let result = try await runner.execute(
            ["config", "-z", "--local", "--get-regexp", "^remote\\."],
            acceptedExitCodes: [0, 1]
        )

        return ConfigEntry.parse(result.standardOutput)
    }

    /// 按顺序把配置项加进仓库自己的配置文件；只写键不写值的项写回为 `true`，Git 对布尔项按同样的意思读取。
    private func add(_ entries: [ConfigEntry]) async throws {
        for entry in entries {
            _ = try await runner.run(["config", "--local", "--add", entry.key, entry.value ?? "true"])
        }
    }
}
