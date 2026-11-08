import Foundation
import Testing

@testable import SpookyKit

extension WorkingCopyScopeTests {
    /// 每轮补丁使用同一状态范围，新增排除子树时全部重读，第二轮仍变则拒绝；
    /// 四种变化各取一种空白选项，两种空白选项都至少出现一次。
    @Test("动态排除范围的有界重读", arguments: [
        ("stable", false),
        ("once", true),
        ("twice", false),
        ("existing", true),
    ])
    func resampling(change: String, whitespace: Bool) async throws {
        let fixture = try WorkingCopyScopeFixture(oldPath: "node", newPath: "node/sub/a.txt")
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        try fixture.change(whitespace: whitespace)
        try fixture.write(Data("branch\n".utf8), path: "node/side/existing")
        _ = try await fixture.runner.run(["add", "--", "node/side"])

        let entry = try await fixture.entry()
        let options = DiffOptions(showsEntireFile: true, ignoresWhitespace: whitespace)
        let baseline = try await fixture.service.diff(for: entry, side: .unstaged, options: options)

        // 状态输出交出之后、补丁读取之前加入旁支
        let hook = samplingHook(change: change)
        let service = WorkingCopyOperations(runner: try fixture.wrappedRunner(after: hook))

        if change == "twice" {
            await #expect(throws: WorkingCopyError.staleSnapshot) {
                try await service.diff(for: entry, side: .unstaged, options: options)
            }
        } else {
            let snapshot = try await service.diff(for: entry, side: .unstaged, options: options)
            #expect(snapshot.fingerprint == baseline.fingerprint)
            #expect(snapshot.diff?.files.count == 1)
        }

        // 每轮读两次状态；忽略空白时每轮的补丁读取翻倍
        let rounds = change == "once" || change == "twice" ? 2 : 1
        let commands = try fixture.commands()
        #expect(commands.count == rounds * (whitespace ? 6 : 4))
        #expect(commands.filter { $0 == "status" }.count == rounds * 2)
        #expect(commands.filter { $0 == "diff" }.count == rounds * (whitespace ? 4 : 2))
    }

    /// public patch 保持普通路径一次读取，重命名三次读取；祖先范围改变时最多完整重读一次。
    @Test("独立补丁读取的查询边界", arguments: ["ordinary", "rename", "retry"])
    func publicPatchCounts(kind: String) async throws {
        let ancestor = kind == "retry"
        let fixture = try WorkingCopyScopeFixture(
            oldPath: ancestor ? "node" : "old",
            newPath: ancestor ? "node/sub/a.txt" : "new"
        )
        defer { fixture.repository.remove() }

        try await fixture.prepare()

        // 普通路径先把重命名提交掉，只剩一处内容改动
        if kind == "ordinary" {
            _ = try await fixture.runner.run(["commit", "-qm", "rename"])
        }

        try fixture.change()
        let entry = try await fixture.entry()
        let runner = try fixture.wrappedRunner(after: ancestor ? samplingHook(change: "once") : "")
        let patch = try await WorkingCopyOperations(runner: runner).patch(
            for: entry,
            side: .unstaged,
            options: DiffOptions()
        )
        #expect(try RepositoryDiff(patch: patch).files.count == 1)

        let expected =
            switch kind {
            case "ordinary": 1
            case "retry": 6
            default: 3
            }

        #expect(try fixture.commands().count == expected)
    }

    /// 真实快照发出的状态与两侧补丁查询都属于读取，路径规格选项不能使取消被误判为中断写入。
    @Test("快照查询保留只读调度身份")
    func snapshotReadClassification() async throws {
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        try fixture.change()

        // 包装程序按序号留下每条命令的完整参数
        let entry = try await fixture.entry()
        let runner = try fixture.wrappedRunner(before: """
            sequence=$(wc -l < "$root/scope-log" | tr -d ' ')
            printf '%s\\0' "$@" > "$root/arguments-$sequence"
            """)
        let snapshot = try await WorkingCopyOperations(runner: runner).diff(for: entry, side: .unstaged)
        #expect(snapshot.diff?.files.count == 1)

        let commands = try fixture.commands()
        #expect(commands == ["status", "diff", "diff", "status"])

        // 从路径规格选项开始的查询被调度器识别为原命令，并归为只读
        for (index, command) in commands.enumerated() {
            let data = try fixture.read(".git/arguments-\(index + 1)")
            let arguments = data.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
            let start = try #require(arguments.firstIndex(of: "--no-literal-pathspecs"))
            let query = Array(arguments[start...])

            #expect(RepositoryOperationQueue.command(in: query) == command)
            #expect(RepositoryOperationQueue.isReadOnly(query))
        }
    }

    /// apply 预检后的目标变化在第二次取样中被拒绝，无关旁支则不阻止安全写入。
    @Test("预检之后的第二次快照校验", arguments: [true, false])
    func secondValidation(targetChanges: Bool) async throws {
        let fixture = try WorkingCopyScopeFixture(oldPath: "node", newPath: "node/sub/a.txt")
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        try fixture.change()
        let snapshot = try await fixture.service.diff(for: try await fixture.entry(), side: .unstaged)

        // 预检之后改写目标文件，或在同一目录下加入并暂存一个旁支
        let hook = targetChanges
            ? """
                if [ "$kind" = check ]; then printf 'externally changed\\n' > "$repo/node/sub/a.txt"; fi
                """
            : """
                if [ "$kind" = check ]; then
                    printf 'new sibling\\n' > "$repo/node/sub/sibling"
                    /usr/bin/git -C "$repo" add -- node/sub/sibling
                fi
                """
        let service = WorkingCopyOperations(runner: try fixture.wrappedRunner(after: hook))

        // 目标变化时不执行正式 apply，索引保持原文
        if targetChanges {
            await #expect(throws: WorkingCopyError.staleSnapshot) {
                try await service.apply(snapshot, file: 0, hunk: 0)
            }

            #expect(try !fixture.commands().contains("apply"))

            let index = try await fixture.runner.run(["show", ":node/sub/a.txt"])
            #expect(index == Data(WorkingCopyScopeFixture.original.utf8))
            return
        }

        // 旁支变化时正式 apply 执行一次，旁支的索引与工作区保持
        try await service.apply(snapshot, file: 0, hunk: 0)
        #expect(try fixture.commands().filter { $0 == "apply" }.count == 1)
        #expect(try await fixture.runner.run(["show", ":node/sub/sibling"]) == Data("new sibling\n".utf8))
        #expect(try fixture.read("node/sub/sibling") == Data("new sibling\n".utf8))
    }

    /// 损坏旁支必须经过完整解析才拒绝；完成的旁支修改、新增与删除重新取范围但不改变目标指纹，
    /// 目标的索引内容变化则使旧快照过期。
    @Test("旁支与目标变化对快照的影响")
    func siblingAndTargetChanges() async throws {
        let fixture = try WorkingCopyScopeFixture(oldPath: "node", newPath: "node/sub/a.txt")
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        try fixture.change()
        try fixture.write(Data("branch\n".utf8), path: "node/branch/file")
        _ = try await fixture.runner.run(["add", "--", "node/branch"])
        let entry = try await fixture.entry()

        // 完整状态里混入一条损坏的旁支记录，不能先过滤掉而悄悄接受目标
        let broken = try fixture.wrappedRunner(after: """
            if [ "$kind" = status ]; then printf '1 broken sibling\\0' >> "$output"; fi
            """)

        await #expect(throws: StatusParseError.self) {
            try await WorkingCopyOperations(runner: broken).diff(for: entry, side: .unstaged)
        }

        #expect(try fixture.commands() == ["status"])

        // 旁支在工作区修改、暂存，再整个删除，快照都仍有效
        let snapshot = try await fixture.service.diff(for: entry, side: .unstaged)
        try fixture.write(Data("changed branch\n".utf8), path: "node/branch/file")
        #expect(try await fixture.service.isCurrent(snapshot))

        _ = try await fixture.runner.run(["add", "--", "node/branch"])
        #expect(try await fixture.service.isCurrent(snapshot))

        try FileManager.default.removeItem(at: fixture.repository.directory.appending(path: "node/branch"))
        _ = try await fixture.runner.run(["add", "--all", "--", "node/branch"])
        #expect(try await fixture.service.isCurrent(snapshot))

        // 目标的改动进入索引后，旧快照过期，写入被拒绝
        _ = try await fixture.runner.run(["add", "--", fixture.newPath])
        #expect(try await !fixture.service.isCurrent(snapshot))

        await #expect(throws: WorkingCopyError.staleSnapshot) {
            try await fixture.service.apply(snapshot, file: 0, hunk: 0)
        }
    }

    /// 原始状态已交给管道但补丁尚未读取时，确定性加入新的旁支。
    private func samplingHook(change: String) -> String {
        guard change != "stable" else { return "" }

        let path = change == "existing" ? "node/side/new" : "node/sub/branch-$count"
        let condition = change == "twice"
            ? "[ \"$count\" -eq 1 ] || [ \"$count\" -eq 3 ]"
            : "[ \"$count\" -eq 1 ]"

        return """
            if [ "$kind" = status ] && { \(condition); }; then
                printf 'sibling content\\n' > "$repo/\(path)"
                /usr/bin/git -C "$repo" add -- "\(path)"
            fi
            """
    }
}
