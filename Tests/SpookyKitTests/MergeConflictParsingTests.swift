import Foundation
import Testing

@testable import SpookyKit

/// 冲突向导依赖的 Git 输出解析：status 的三方 stage、cat-file 批量输出、resolve-undo 记录与进行中操作的状态文件。
struct MergeConflictParsingTests {
    /// 缺少的一侧必须识别为不存在，否则向导会去取一个全零的对象，采用那一侧时也会误用 checkout；采用两侧时按三方的模式决定结果的模式。
    @Test("冲突记录的三方 stage、文件模式、工作区存在性与 SHA-256 哈希")
    func conflictStages() throws {
        let sha256 = String(repeating: "ab", count: 32)
        let zero = String(repeating: "0", count: 40)

        let status = try WorkingCopyStatus(porcelainV2: output(
            "u UU N... 100644 100644 100644 100644 aaaa bbbb cccc 冲突 'x' [*]? 文件.txt",
            "u DU N... 100644 000000 100644 000000 aaaa \(zero) cccc deleted-by-us.txt",
            "u AA N... 000000 100644 100755 100644 \(zero) \(sha256) dddd both-added.sh"
        ))

        let entries = status.entries

        #expect(entries.count == 3)
        #expect(entries[0].path == "冲突 'x' [*]? 文件.txt")
        #expect(entries[0].conflict == ConflictStages(
            base: "aaaa",
            ours: "bbbb",
            theirs: "cccc",
            existsInWorktree: true,
            baseMode: "100644",
            oursMode: "100644",
            theirsMode: "100644"
        ))
        #expect(entries[0].conflictKind == .bothModified)

        // 我方删除了文件：没有我方版本与模式，工作区里也已经没有它
        #expect(entries[1].conflict == ConflictStages(
            base: "aaaa",
            ours: nil,
            theirs: "cccc",
            existsInWorktree: false,
            baseMode: "100644",
            oursMode: nil,
            theirsMode: "100644"
        ))
        #expect(entries[1].conflictKind == .deletedByUs)

        // 两侧都新增：没有共同祖先，哈希长度随对象格式变化，两侧的模式各自保留
        #expect(entries[2].conflict?.base == nil && entries[2].conflict?.baseMode == nil)
        #expect(entries[2].conflict?.ours == sha256)
        #expect(entries[2].conflict?.theirsMode == "100755")
        #expect(entries[2].conflictKind == .bothAdded)
    }

    /// 七种未合并 XY 各自对应一种冲突类型，界面据此显示冲突说明。
    @Test("冲突类型与 XY 的对应", arguments: [
        ("UU", ConflictKind.bothModified),
        ("AA", .bothAdded),
        ("DD", .bothDeleted),
        ("AU", .addedByUs),
        ("UA", .addedByThem),
        ("DU", .deletedByUs),
        ("UD", .deletedByThem),
    ])
    func conflictKinds(xy: String, kind: ConflictKind) throws {
        let status = try WorkingCopyStatus(porcelainV2: output(
            "u \(xy) N... 100644 100644 100644 100644 aaaa bbbb cccc file.txt"
        ))

        #expect(status.entries.first?.conflictKind == kind)
    }

    /// 模式与哈希格式不对的冲突记录不能当作有效快照。
    @Test("冲突记录的模式或哈希损坏", arguments: [
        "u UU N... 10064x 100644 100644 100644 aaaa bbbb cccc file.txt",
        "u UU N... 100644 100644 100644 1006440 aaaa bbbb cccc file.txt",
        "u UU N... 100644 100644 100644 100644 aaaa zzzz cccc file.txt",
        "u UU N... 100644 100644 100644 100644 aaaa BBBB cccc file.txt",
    ])
    func malformedStages(record: String) {
        #expect(throws: StatusParseError(record: record)) {
            try WorkingCopyStatus(porcelainV2: output(record))
        }
    }

    /// 内容按声明的字节数截取：内容里的换行、NUL 与看起来像对象头的文字都不能打乱切分。
    @Test("cat-file 批量输出：二进制内容与缺失的对象")
    func batchOutput() throws {
        let binary = Data([0, 1, 10, 255])
        let text = Data("line\naaaa blob 3\n".utf8)

        var output = Data("aaaa blob \(binary.count)\n".utf8) + binary + Data("\n".utf8)
        output += Data("bbbb missing\n".utf8)
        output += Data("cccc blob \(text.count)\n".utf8) + text + Data("\n".utf8)

        let objects = try WorkingCopyOperations.parseBatch(output)

        #expect(objects == ["aaaa": binary, "cccc": text])
        #expect(try WorkingCopyOperations.parseBatch(Data()).isEmpty)
    }

    /// 截断或者头部损坏的输出必须报错，不能把半个对象交给向导显示或写回。
    @Test("cat-file 批量输出损坏", arguments: [
        "aaaa blob 5\nabc\n",
        "aaaa blob 3\nabcX",
        "aaaa blob\nabc\n",
        "aaaa blob -1\n\n",
        "XYZ! blob 3\nabc\n",
        "aaaa blob 3",
    ])
    func malformedBatch(output: String) {
        #expect(throws: RepositoryReadError.self) {
            try WorkingCopyOperations.parseBatch(Data(output.utf8))
        }
    }

    /// resolve-undo 的每条记录对应一个 stage，同一路径只算一次；路径里的空格和制表符之后的内容原样保留。
    @Test("resolve-undo 记录：已解决的路径")
    func resolveUndo() throws {
        let output = Data((
            "100644 aaaa 1\t已解决 [*].txt\0"
                + "100644 bbbb 2\t已解决 [*].txt\0"
                + "100644 cccc 3\t已解决 [*].txt\0"
                + "100644 dddd 3\tother\tname\0"
        ).utf8)

        #expect(try OperationProgress.parseResolveUndo(output) == ["已解决 [*].txt", "other\tname"])
        #expect(try OperationProgress.parseResolveUndo(Data()).isEmpty)
    }

    /// 缺少分隔符、stage 不对或者截断的记录必须报错，已解决计数不能凭损坏的输出得出。
    @Test("resolve-undo 记录损坏", arguments: [
        "100644 aaaa 1 file\0",
        "100644 aaaa 4\tfile\0",
        "100644 aaaa\tfile\0",
        "100644 aaaa 1\t\0",
        "100644 aaaa 1\tfile",
    ])
    func malformedResolveUndo(output: String) {
        #expect(throws: RepositoryReadError.self) {
            try OperationProgress.parseResolveUndo(Data(output.utf8))
        }
    }

    /// merge 后端的变基从 done 的最后一条取当前一步；新旧两种 Git 的标题写法都要识别。
    @Test("变基进度：merge 后端", arguments: ["# feature two", "feature two"])
    func mergeBackendRebase(subject: String) throws {
        let progress = try #require(OperationProgress(files: [
            "rebase-merge/head-name": "refs/heads/feature\n",
            "rebase-merge/onto": "aaaa\n",
            "rebase-merge/orig-head": "bbbb\n",
            "rebase-merge/msgnum": "2\n",
            "rebase-merge/end": "3\n",
            "rebase-merge/done": "pick cccc # feature one\npick dddd \(subject)\n",
        ], head: "eeee"))

        #expect(progress.state == .rebase)
        #expect(progress.ours == "aaaa")
        #expect(progress.theirs == "bbbb")
        #expect(progress.branch == "refs/heads/feature")
        #expect(progress.step == 2 && progress.stepCount == 3)
        #expect(progress.stepKind == .applying)
        #expect(progress.stepSubject == "feature two")
    }

    /// apply 后端只有步号与提交信息文件；分离 HEAD 上的变基没有分支名，不带提交的指令不产生标题。
    @Test("变基进度：apply 后端、分离 HEAD 与 edit 指令")
    func otherRebases() throws {
        let apply = try #require(OperationProgress(files: [
            "rebase-apply/head-name": "detached HEAD\n",
            "rebase-apply/onto": "aaaa\n",
            "rebase-apply/orig-head": "bbbb\n",
            "rebase-apply/next": "1\n",
            "rebase-apply/last": "2\n",
            "rebase-apply/final-commit": "第一行 标题\n\n正文\n",
        ], head: nil))

        #expect(apply.branch == nil)
        #expect(apply.step == 1 && apply.stepCount == 2)
        #expect(apply.stepSubject == "第一行 标题")

        let edit = try #require(OperationProgress(files: [
            "rebase-merge/head-name": "refs/heads/feature",
            "rebase-merge/done": "edit aaaa change\nexec make test\n",
        ], head: nil))

        // 最后一条是不带提交的 exec，当前一步没有标题
        #expect(edit.stepSubject == nil)
        #expect(edit.stepKind == .applying)

        let editing = try #require(OperationProgress(files: [
            "rebase-merge/head-name": "refs/heads/feature",
            "rebase-merge/done": "edit aaaa change\n",
        ], head: nil))

        #expect(editing.stepKind == .editing)
    }

    /// 序列看 todo 的第一条指令，只数得出剩余的提交，没有当前一步；单个提交的摘取、反转与合并只看伪引用文件。
    @Test("摘取、反转与合并的识别")
    func sequencesAndMerges() throws {
        let picking = try #require(OperationProgress(files: [
            "sequencer/todo": "pick aaaa first commit\npick bbbb second\n",
            "CHERRY_PICK_HEAD": "aaaaaaaa\n",
        ], head: "cccc"))

        #expect(picking.state == .cherryPick)
        #expect(picking.ours == "cccc" && picking.theirs == "aaaaaaaa")
        #expect(picking.step == nil && picking.stepCount == 2)
        #expect(picking.stepSubject == "first commit")

        let reverting = try #require(OperationProgress(files: ["REVERT_HEAD": "dddd\n"], head: "cccc"))
        #expect(reverting.state == .revert && reverting.theirs == "dddd" && reverting.stepKind == .reverting)
        #expect(reverting.stepCount == nil && reverting.stepSubject == nil)

        let merging = try #require(OperationProgress(files: ["MERGE_HEAD": "eeee\nffff\n", "MERGE_MSG": "Merge"], head: "cccc"))
        #expect(merging.state == .merge && merging.theirs == "eeee" && merging.ours == "cccc")

        let squashing = try #require(OperationProgress(files: ["SQUASH_MSG": "Squashed"], head: "cccc"))
        #expect(squashing.state == .squash && squashing.theirs == nil)

        #expect(OperationProgress(files: ["MERGE_MSG": "leftover"], head: "cccc") == nil)
    }

    /// 把若干条记录按 `-z` 的格式拼成 git 的输出：每条以 NUL 结尾。
    private func output(_ records: String...) -> Data {
        Data(records.map { $0 + "\0" }.joined().utf8)
    }
}
