import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryStateTests

/// 撤销状态里引用与储藏列表的解析，以及与界面已读结果的粗略比较。
struct RepositoryStateTests {
    /// 记录之间的换行不属于引用名；附注标签同时记下标签对象与剥离后的提交；储藏引用只说明有储藏。
    @Test("for-each-ref：分支、附注标签与储藏")
    func parseReferences() throws {
        let commit = String(repeating: "a", count: 64)
        let tag = String(repeating: "b", count: 64)
        let output = "refs/heads/功能/分支\0\(commit)\0\0\nrefs/stash\0\(commit)\0\0\nrefs/tags/v1\0\(tag)\0\(commit)\0\n"

        let parsed = try RepositoryState.parseReferences(Data(output.utf8))
        #expect(parsed.references == ["refs/heads/功能/分支": commit, "refs/tags/v1": tag])
        #expect(parsed.peeled == ["refs/heads/功能/分支": commit, "refs/tags/v1": commit])
        #expect(parsed.hasStash)
        #expect(try RepositoryState.parseReferences(Data()).references.isEmpty)

        let broken = [
            "refs/heads/main\0\(commit)\0",
            "refs/heads/main\0HEAD\0\0\n",
            "main\0\(commit)\0\0\n",
            "refs/tags/v1\0\(tag)\0--all\0\n",
        ]

        for text in broken {
            #expect(throws: RepositoryReadError.malformedOutput("for-each-ref")) {
                try RepositoryState.parseReferences(Data(text.utf8))
            }
        }
    }

    /// 储藏的说明可以带冒号与引号；第三个父提交是未跟踪文件，父提交数不对或字段错位时拒绝。
    @Test("stash list：说明与未跟踪文件的父提交")
    func parseStashes() throws {
        let a = String(repeating: "a", count: 40)
        let b = String(repeating: "b", count: 40)
        let output = "\(a)\0\(b) \(a)\0On main: 说明 \"x\": y\0\(b)\0\(a) \(b) \(a)\0WIP on main: z\0"

        let stashes = try RepositoryState.parseStashes(Data(output.utf8))
        #expect(stashes.map(\.message) == ["On main: 说明 \"x\": y", "WIP on main: z"])
        #expect(stashes.map(\.untracked) == [nil, a])

        let broken = [
            String(output.dropLast()),
            "\(a)\0\(b)\0x\0",
            "\(a)\0\(b) \(a)\0",
            "HEAD\0\(b) \(a)\0x\0",
        ]

        for text in broken {
            #expect(throws: RepositoryReadError.malformedOutput("stash list")) {
                try RepositoryState.parseStashes(Data(text.utf8))
            }
        }
    }

    /// 分支名可以含点与斜杠，取第一个点与最后一个点之间；只写键的项没有值；没有分支名的键拒绝。
    @Test("config --get-regexp：分支段")
    func parseBranchSettings() throws {
        let output = "branch.功能/v1.2.remote\norigin\0branch.main.spooky-pinned\0branch.main.description\n第一行\n第二行\0"

        let settings = try RepositoryState.parseBranchSettings(Data(output.utf8))
        #expect(settings.map(\.branch) == ["功能/v1.2", "main", "main"])
        #expect(settings.map(\.value) == ["origin", nil, "第一行\n第二行"])
        #expect(try RepositoryState.parseBranchSettings(Data()).isEmpty)

        for text in ["branch.remote\nx\0", "core.bare\nfalse\0", "branch..remote\nx\0"] {
            #expect(throws: RepositoryReadError.malformedOutput("branch config")) {
                try RepositoryState.parseBranchSettings(Data(text.utf8))
            }
        }
    }

    /// 粗略比较看 HEAD、文件状态、分支与标签、储藏；上游的领先落后不算仓库内容，获取之后仍一致。
    @Test("与界面已读结果的粗略比较")
    func resembles() {
        let commit = String(repeating: "c", count: 40)
        let entry = StatusEntry(kind: .tracked, path: "a b.txt", staged: .modified)
        let state = RepositoryState(
            headBranch: "refs/heads/main",
            head: commit,
            references: ["refs/heads/main": commit],
            peeledReferences: ["refs/heads/main": commit],
            branchSettings: [],
            stashes: [],
            index: commit,
            worktree: commit,
            entries: [entry]
        )

        var status = WorkingCopyStatus(branch: BranchStatus(head: "main", oid: commit), entries: [entry])
        #expect(state.resembles(status: status, references: ["refs/heads/main": commit], stashes: []))
        #expect(state.resembles(status: status, references: nil, stashes: nil))

        status.branch.behind = 3
        #expect(state.resembles(status: status, references: nil, stashes: nil))

        // HEAD 分离、文件状态变化、多出分支或储藏都不一致
        var detached = status
        detached.branch.head = nil
        #expect(!state.resembles(status: detached, references: nil, stashes: nil))

        var changed = status
        changed.entries.append(StatusEntry(kind: .untracked, path: "new"))
        #expect(!state.resembles(status: changed, references: nil, stashes: nil))

        #expect(!state.resembles(status: status, references: [:], stashes: nil))
        #expect(!state.resembles(status: status, references: nil, stashes: [commit]))
    }
}
