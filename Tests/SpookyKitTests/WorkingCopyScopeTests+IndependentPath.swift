import Foundation
import Testing
import TestSupport

@testable import SpookyKit

extension WorkingCopyScopeTests {
    /// 块、单行和多行的三种写动作都只处理新路径，忽略空白也不能触碰旧路径的新占用者；
    /// 每种动作取两种选择，选择方式与是否忽略空白都至少出现一次。
    @Test("独立旧路径在按块按行写入后保持", arguments: [
        ("stage", (1, false)), ("stage", (2, true)),
        ("unstage", (0, true)), ("unstage", (2, false)),
        ("discard", (0, false)), ("discard", (1, true)),
    ])
    func independentWrites(action: String, selection: (Int, Bool)) async throws {
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        try fixture.change(whitespace: selection.1)

        if action == "unstage" {
            _ = try await fixture.runner.run(["add", "--", "new"])
        }

        // 取样时旧路径上已有一个未跟踪文件，取样之后再换掉它的内容
        try fixture.write(Data([0, 0xFF, 65]), path: "old")
        let entry = try await fixture.entry()
        let options = DiffOptions(showsEntireFile: true, ignoresWhitespace: selection.1)
        let snapshot = try await fixture.service.diff(
            for: entry,
            side: action == "unstage" ? .staged : .unstaged,
            options: options
        )

        let protected = Data([0, 0xFE, 66, 10])
        try fixture.write(protected, path: "old")
        #expect(try await fixture.service.isCurrent(snapshot))

        let lines = try selectedLines(snapshot, mode: selection.0)
        try await fixture.service.apply(
            snapshot,
            file: 0,
            hunk: 0,
            lines: lines,
            discard: action == "discard"
        )
        try await fixture.verifyIndependent(protected)

        // 被写的一侧得到按选择算出的内容，另一侧保持原样
        let index = try await fixture.runner.run(["show", ":new"])
        let working = try fixture.read("new")
        let written = action == "discard" ? working : index
        let untouched = action == "discard" ? index : working
        let unchanged = action == "discard"
            ? WorkingCopyScopeFixture.original
            : fixture.changed(whitespace: selection.1)

        let expected = expectedContent(
            action: action,
            selection: selection.0,
            whitespace: selection.1,
            fixture: fixture
        )

        #expect(written == Data(expected.utf8))
        #expect(untouched == Data(unchanged.utf8))
        #expect(try fixture.read("outside") == Data("unrelated\n".utf8))
    }

    /// 非法选择及可见状态不变的目标编辑都不能让旧路径独立文件参与补丁。
    @Test("独立旧路径在非法选择和旧快照拒绝后保持", arguments: ["invalid", "target", "whitespace"])
    func independentRejections(reason: String) async throws {
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        try fixture.change()

        let protected = Data([0, 0xFF, 0x80, 10])
        try fixture.write(protected, path: "old")
        let entry = try await fixture.entry()
        let snapshot = try await fixture.service.diff(
            for: entry,
            side: .unstaged,
            options: DiffOptions(ignoresWhitespace: reason == "whitespace")
        )
        let before = try await fixture.service.scope(for: entry).status

        // 再改一次目标文件，原始状态记录保持不变
        if reason != "invalid" {
            let text = fixture.changed().replacingOccurrences(
                of: "line 6\n",
                with: reason == "whitespace" ? "  line 6\n" : "edited again\n"
            )
            try fixture.write(Data(text.utf8), path: "new")
            #expect(try await fixture.service.scope(for: entry).status == before)
        }

        let expected = reason == "invalid" ? WorkingCopyError.invalidSelection : .staleSnapshot
        let lines: Set<Int> = reason == "invalid" ? [999] : []

        await #expect(throws: expected) {
            try await fixture.service.apply(snapshot, file: 0, hunk: 0, lines: lines)
        }

        try await fixture.verifyIndependent(protected)
    }

    /// 独立旧路径在工作区出现或加入索引都改变原始状态，旧快照必须拒绝。
    @Test("独立旧路径的身份变化使快照过期", arguments: ["appear", "stage"])
    func independentIdentity(change: String) async throws {
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        try fixture.change()

        let bytes = Data([0, 0xFF, 65])

        if change == "stage" {
            try fixture.write(bytes, path: "old")
        }

        let snapshot = try await fixture.service.diff(for: try await fixture.entry(), side: .unstaged)

        // 取样之后旧路径出现，或被加入索引
        if change == "appear" {
            try fixture.write(bytes, path: "old")
        } else {
            _ = try await fixture.runner.run(["add", "--", "old"])
        }

        await #expect(throws: WorkingCopyError.staleSnapshot) {
            try await fixture.service.apply(snapshot, file: 0, hunk: 0)
        }

        #expect(try fixture.read("new") == Data(fixture.changed().utf8))
        #expect(try fixture.read("old") == bytes)
    }

    /// 真实 Git 预检与正式执行失败仍保留原始退出码，不恢复或改写独立文件；
    /// 三种动作分别覆盖正式写入撞上索引锁、预检失败与正式写入失败。
    @Test("独立旧路径在 Git 两阶段失败后保持", arguments: [
        ("stage", true),
        ("unstage", false),
        ("discard", true),
    ])
    func independentGitFailure(action: String, formal: Bool) async throws {
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        try fixture.change()

        if action == "unstage" {
            _ = try await fixture.runner.run(["add", "--", "new"])
        }

        let protected = Data([0, 0xFE, 0xFF, 10])
        try fixture.write(protected, path: "old")
        let snapshot = try await fixture.service.diff(
            for: try await fixture.entry(),
            side: action == "unstage" ? .staged : .unstaged
        )

        // 暂存类动作的正式写入撞上索引锁；其余情形在预检或正式写入之前换掉目标，让 Git 自己失败
        let locksIndex = formal && action != "discard"
        let replace = action == "discard" ? "printf 'incompatible\\n' > \"$repo/new\"" : """
            hash=$(printf 'incompatible\\n' | /usr/bin/git -C "$repo" hash-object -w --stdin)
            /usr/bin/git -C "$repo" update-index --cacheinfo 100644 "$hash" new
            """

        let phase = formal ? "apply" : "check"
        let before = locksIndex ? "" : "if [ \"$kind\" = \(phase) ]; then\n\(replace)\nfi"
        let after = locksIndex ? "if [ \"$kind\" = check ]; then : > \"$root/index.lock\"; fi" : ""
        let service = WorkingCopyOperations(runner: try fixture.wrappedRunner(before: before, after: after))

        // 失败保留 Git 自己的退出码：索引锁为 128，补丁不适用为 1
        let expectedCode: Int32 = locksIndex ? 128 : 1

        await #expect {
            try await service.apply(snapshot, file: 0, hunk: 0, discard: action == "discard")
        } throws: { error in
            guard let error = error as? GitError else { return false }

            return error.exitCode == expectedCode && !error.message.isEmpty
        }

        #expect(try fixture.commands().filter { $0 == "check" }.count == 1)
        #expect(try fixture.commands().filter { $0 == "apply" }.count == (formal ? 1 : 0))
        try await fixture.verifyIndependent(protected)
    }

    /// 取消停在真实读取闸门上的写入任务，不执行预检或正式 apply。
    @Test("取消按行操作不触及独立旧路径")
    func independentCancellation() async throws {
        let fixture = try WorkingCopyScopeFixture()
        defer { fixture.repository.remove() }

        try await fixture.prepare()
        try fixture.change()

        let protected = Data([0, 0x80, 0xFF])
        try fixture.write(protected, path: "old")
        let snapshot = try await fixture.service.diff(for: try await fixture.entry(), side: .unstaged)

        // 写入前的状态读取停在闸门上，等它真正开始后再取消
        let gate = try ProcessGate(in: fixture.repository.directory.appending(path: ".git"))
        defer { gate.release() }

        let runner = try fixture.wrappedRunner(before: """
            if [ "$kind" = status ]; then
                \(gate.command)
            fi
            """)

        let task = Task {
            try await WorkingCopyOperations(runner: runner).apply(snapshot, file: 0, hunk: 0)
        }

        await gate.arrival()
        task.cancel()

        await #expect {
            try await task.value
        } throws: { error in
            guard let error = error as? GitError else { return false }

            return error.category == .cancelled && error.exitCode == nil
        }

        #expect(try fixture.commands() == ["status"])
        try await fixture.verifyIndependent(protected)
    }

    /// 单行选择新增行，多行选择同一处的删增配对，空集合表示整块。
    private func selectedLines(_ snapshot: DiffSnapshot, mode: Int) throws -> Set<Int> {
        guard mode != 0 else { return [] }

        let hunk = try #require(snapshot.diff?.files.first?.hunks.first)
        let addition = try #require(hunk.lines.first {
            $0.prefix == 43 && $0.content == Data("changed 2".utf8)
        })

        if mode == 1 {
            return [addition.id]
        }

        let deletion = try #require(hunk.lines.first {
            $0.prefix == 45 && $0.content == Data("line 2".utf8)
        })

        return [deletion.id, addition.id]
    }

    /// 用明确的文件行计算期望，不以补丁生成器的输出作为自己的正确性证明。
    private func expectedContent(
        action: String,
        selection: Int,
        whitespace: Bool,
        fixture: WorkingCopyScopeFixture
    ) -> String {
        let original = WorkingCopyScopeFixture.original

        if action == "stage" {
            switch selection {
            case 0: return fixture.changed()
            case 1: return original.replacingOccurrences(of: "line 2\n", with: "line 2\nchanged 2\n")
            default: return original.replacingOccurrences(of: "line 2\n", with: "changed 2\n")
            }
        }

        if selection == 0 {
            return whitespace ? original.replacingOccurrences(of: "line 6\n", with: "  line 6\n") : original
        }

        return fixture.changed(whitespace: whitespace)
            .replacingOccurrences(of: "changed 2\n", with: selection == 1 ? "" : "line 2\n")
    }
}
