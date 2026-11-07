import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteConflictTests

/// 服务器上的冲突向导仅在显式启用时访问测试专用仓库：三方内容、恢复与采用一侧都在 B 上完成。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteConflictTests {
    /// 冲突文件的读取、恢复祖先与采用一侧都经主连接在 B 上完成；断线后的写入不会被当作已执行。
    @Test("服务器冲突向导：三方内容、恢复、采用一侧与断线", .timeLimit(.minutes(3)))
    func conflictWizard() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let path = "冲突 ' [*]?.txt"
            let absolute = fixture.repository + "/" + path

            // 在 B 上构造合并冲突
            try await files.write(Data("base\n".utf8), to: absolute)
            _ = try await runner.run(["add", "-A"])
            _ = try await runner.run(["commit", "-q", "-m", "base"])
            _ = try await runner.run(["checkout", "-q", "-b", "side"])
            try await files.write(Data("theirs\n".utf8), to: absolute)
            _ = try await runner.run(["commit", "-q", "-a", "-m", "theirs"])
            _ = try await runner.run(["checkout", "-q", "main"])
            try await files.write(Data("ours\n".utf8), to: absolute)
            _ = try await runner.run(["commit", "-q", "-a", "-m", "ours"])
            _ = try await runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

            let status = try await runner.status()
            let entry = try #require(status.entries.first { $0.path == path })
            let contents = try await service.conflictContents(of: entry)

            #expect(String(decoding: try #require(contents.worktree), as: UTF8.self).contains("<<<<<<<"))
            #expect(contents.ours == Data("ours\n".utf8) && contents.theirs == Data("theirs\n".utf8))

            // 对方版本所在的提交是被合并的分支
            let merging = try await service.context(head: status.branch.oid).progress
            let side = try await RepositoryRewrite(runner: runner).resolve("side")

            #expect(merging?.state == .merge && merging?.theirsCommit == side)

            // 恢复祖先版本只改 B 上的工作区，文件仍是冲突，内容不同于两侧即算手动改过
            try await service.restoreConflicts([entry], to: .base)
            #expect(try await files.read([absolute])[absolute] == Data("base\n".utf8))
            #expect(try await service.conflictContents(of: entry).isManuallyEdited)

            // 重新生成冲突后标记回来，不再算手动改过
            try await service.restoreConflicts([entry], to: .unmerged)
            #expect(try await !service.conflictContents(of: entry).isManuallyEdited)

            // 断线中的采用一侧不会执行；重连后文件仍是冲突
            try await remote.interruptMaster()

            await #expect(throws: RemoteConnectionError.self) {
                try await service.resolve([entry], theirs: true)
            }

            _ = try await remote.reconnect()
            #expect(try await runner.status().entries.first { $0.path == path }?.kind == .conflicted)
            #expect(try await service.context(head: status.branch.oid).progress?.state == .merge)

            // 重连后采用对方版本，在 B 上写入并标记解决
            try await service.resolve([entry], theirs: true)
            #expect(try await files.read([absolute])[absolute] == Data("theirs\n".utf8))
            #expect(try await runner.status().entries.allSatisfy { $0.kind != .conflicted })

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }

    /// B 上的状态文件经同一次定位与读取：摘取序列、单个摘取与 edit 停顿的分类和步数，以及变基冲突时对方版本的提交，都与本机一致。
    @Test("服务器上进行中操作的分类", .timeLimit(.minutes(3)))
    func operationKinds() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)

            /// 在 B 上写入一个文件并提交全部改动。
            func commit(_ name: String, _ content: String, message: String) async throws {
                try await files.write(Data((content + "\n").utf8), to: fixture.repository + "/" + name)
                _ = try await runner.run(["add", "-A"])
                _ = try await runner.run(["commit", "-q", "-m", message])
            }

            /// 按 B 上当前的 HEAD 读取进行中的操作。
            func progress() async throws -> OperationProgress {
                let head = try await runner.status().branch.oid
                return try #require(try await service.context(head: head).progress)
            }

            try await commit("x", "base", message: "base")
            _ = try await runner.run(["checkout", "-q", "-b", "side"])
            try await commit("a", "a", message: "one")
            try await commit("x", "two", message: "two")
            try await commit("c", "c", message: "three")
            _ = try await runner.run(["checkout", "-q", "main"])
            try await commit("x", "main", message: "main")
            try await commit("y", "after", message: "after")

            // 三个提交在第二个冲突，序列剩两项
            _ = try await runner.execute(["cherry-pick", "side~2", "side~1", "side"], acceptedExitCodes: [1])
            let sequence = try await progress()

            #expect(sequence.state == .cherryPick && sequence.isSequence)
            #expect(sequence.step == 1 && sequence.stepCount == 2 && sequence.stepSubject == "two")

            try await service.finish(.cherryPick, action: "abort")

            // 只摘一个提交时 Git 不建 sequencer
            _ = try await runner.execute(["cherry-pick", "side~1"], acceptedExitCodes: [1])
            let single = try await progress()

            #expect(single.state == .cherryPick && !single.isSequence && single.stepCount == nil)

            try await service.finish(.cherryPick, action: "abort")

            // edit 停下时记下正在修改的提交，不是尚未开始
            let rewrite = RepositoryRewrite(runner: runner)
            let edited = try await rewrite.resolve("HEAD~1")
            try await rewrite.perform(try await rewrite.plan(.edit(edited)))

            let editing = try await progress()

            #expect(editing.stopsForEdit && editing.editedCommit == edited && editing.stepKind == .editing)
            #expect(!editing.isPendingInteractive)

            try await service.finish(.rebase, action: "abort")

            // 变基在 two 上冲突，对方版本是这一步正在应用的原提交
            _ = try await runner.run(["checkout", "-q", "side"])
            _ = try await runner.execute(["rebase", "main"], acceptedExitCodes: [1])

            let rebasing = try await progress()
            let applying = try await rewrite.resolve("side~1")

            #expect(rebasing.state == .rebase && rebasing.theirsCommit == applying)

            try await service.finish(.rebase, action: "abort")

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }

    /// B 上的变基冲突解决后用编辑后的信息继续：Unicode、换行、引号与注释行经标准输入送到 B，原作者保留。
    @Test("服务器上用编辑后的信息继续变基", .timeLimit(.minutes(3)))
    func continueWithMessage() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let file = fixture.repository + "/x"

            // feature 的提交由另一个作者写下，与 main 冲突
            try await files.write(Data("base\n".utf8), to: file)
            _ = try await runner.run(["add", "-A"])
            _ = try await runner.run(["commit", "-q", "-m", "base"])
            _ = try await runner.run(["checkout", "-q", "-b", "feature"])
            try await files.write(Data("feature\n".utf8), to: file)
            _ = try await runner.run([
                "commit", "-q", "-am", "conflicting", "--author=Original Author <author@example.invalid>",
            ])
            _ = try await runner.run(["checkout", "-q", "main"])
            try await files.write(Data("main\n".utf8), to: file)
            _ = try await runner.run(["commit", "-q", "-am", "main"])
            _ = try await runner.run(["checkout", "-q", "feature"])
            _ = try await runner.execute(["rebase", "main"], acceptedExitCodes: [1])

            try await service.resolve(try await runner.status().entries, theirs: true)

            let subject = "标题 “弯引号” 'single' \"double\""
            let body = "第一行\n# 注释\n第二行"
            try await service.continueSequence(.rebase, subject: subject, body: body)

            let log = try await runner.run(["log", "-1", "--format=%an%n%B"])
            let head = try await runner.status().branch.oid

            #expect(
                String(decoding: log, as: UTF8.self).trimmingCharacters(in: .newlines)
                    == "Original Author\n" + subject + "\n\n" + body
            )
            #expect(try await service.context(head: head).operation == nil)

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError {
                Issue.record(Comment(rawValue: git.message))
            }

            await remote.close()
            try await fixture.remove()
            throw error
        }
    }

    /// B 上解决后没有任何改动的单个摘取与序列步骤：保留空提交、中止与跳过的结果都在 B 上完成。
    @Test("服务器上空提交的保留、中止与跳过", .timeLimit(.minutes(3)))
    func emptyCommits() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)

            /// 在 B 上写入一个文件并提交全部改动。
            func commit(_ name: String, _ content: String, message: String) async throws {
                try await files.write(Data((content + "\n").utf8), to: fixture.repository + "/" + name)
                _ = try await runner.run(["add", "-A"])
                _ = try await runner.run(["commit", "-q", "-m", message])
            }

            /// 摘取给定的提交，第一个冲突后采用我方，停在没有任何改动的一步上。
            func stopEmpty(_ revisions: [String]) async throws {
                _ = try await runner.execute(["cherry-pick"] + revisions, acceptedExitCodes: [1])
                try await service.resolve(try await runner.status().entries, theirs: false)
            }

            /// main 原来的提交之后的标题，从新到旧。
            func subjects(after base: String) async throws -> String {
                String(decoding: try await runner.run(["log", "--format=%s", "\(base)..HEAD"]), as: UTF8.self)
            }

            try await commit("x", "base", message: "base")
            _ = try await runner.run(["checkout", "-q", "-b", "picked"])
            try await commit("x", "one", message: "one")
            try await commit("y", "two", message: "two")
            _ = try await runner.run(["checkout", "-q", "main"])
            try await commit("x", "main", message: "main")

            let base = try await runner.status().branch.oid ?? ""

            // 单个摘取：保留空提交，标题用编辑后的信息
            try await stopEmpty(["picked~1"])
            try await service.commit(subject: "空提交", body: "", allowEmpty: true)

            #expect(try await subjects(after: base) == "空提交\n")

            // 单个摘取：中止后回到原来的提交
            _ = try await runner.run(["reset", "-q", "--hard", base])
            try await stopEmpty(["picked~1"])
            try await service.finish(.cherryPick, action: "abort")

            #expect(try await runner.status().branch.oid == base)

            // 序列：保留这一步再继续，或跳过这一步，后面的提交都照常摘取
            try await stopEmpty(["picked~1", "picked"])
            try await service.continueSequence(.cherryPick, subject: "空步骤", body: "", allowEmpty: true)

            #expect(try await subjects(after: base) == "two\n空步骤\n")

            _ = try await runner.run(["reset", "-q", "--hard", base])
            try await stopEmpty(["picked~1", "picked"])
            try await service.finish(.cherryPick, action: "skip")

            #expect(try await subjects(after: base) == "two\n")
            #expect(try await service.context(head: try await runner.status().branch.oid).operation == nil)

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError {
                Issue.record(Comment(rawValue: git.message))
            }

            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}
