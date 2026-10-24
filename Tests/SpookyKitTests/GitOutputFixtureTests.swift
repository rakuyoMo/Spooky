import Foundation
import Testing

@testable import SpookyKit

/// 固定的 Git 输出夹具：status、diff、log、引用、fetch 与 push 的解析结果必须稳定。
///
/// 夹具由 Git 2.54 在忽略系统与用户配置、固定提交身份与时间的临时仓库中生成，
/// 覆盖重命名、冲突、二进制、中文与引号路径、NFD 文件名、合并提交和 SHA-256 哈希。
struct GitOutputFixtureTests {
    /// 分支头、各类条目与特殊路径都从同一份 porcelain v2 输出中读出。
    @Test("status 夹具：上游计数、重命名、冲突、删除与特殊路径")
    func status() throws {
        let status = try WorkingCopyStatus(porcelainV2: try fixture("status.bin"))
        #expect(status.branch.head == "main")
        #expect(status.branch.upstream == "origin/main")
        #expect(status.branch.ahead == 1 && status.branch.behind == 0)
        #expect(status.branch.oid?.count == 40)

        let entries = Dictionary(uniqueKeysWithValues: status.entries.map { ($0.path, $0) })
        #expect(status.entries.count == 7)
        #expect(entries["deleted.txt"]?.unstaged == .deleted)
        #expect(entries["image.bin"]?.staged == .modified && entries["image.bin"]?.unstaged == nil)
        #expect(entries["lines.txt"]?.unstaged == .modified)
        #expect(entries["重命名 target.txt"]?.staged == .renamed)
        #expect(entries["重命名 target.txt"]?.originalPath == "renamed source.txt")
        #expect(entries["conflict.txt"]?.kind == .conflicted)
        #expect(entries["café.txt"]?.kind == .untracked)
        #expect(entries["未跟踪 \"quoted\" [*].txt"]?.kind == .untracked)
    }

    /// 关闭预组合时 Git 输出原始 NFD 字节；路径保持原样，与 NFC 写法按规范等价比较。
    @Test("status 夹具：NFD 文件名")
    func decomposedPath() throws {
        let status = try WorkingCopyStatus(porcelainV2: try fixture("status-nfd.bin"))
        let entry = try #require(status.entries.first { $0.kind == .untracked && $0.path.hasPrefix("caf") })
        #expect(entry.path.unicodeScalars.contains("\u{301}"))
        #expect(entry.path == "caf\u{E9}.txt")
        #expect(entry.path.precomposedStringWithCanonicalMapping.unicodeScalars.count == 8)
        #expect(status.branch.head == nil)
    }

    /// 两个块与末尾无换行的补丁可以逐行重组：未选的删除行原地变为上下文，未选的新增行连同无换行标记一起丢弃。
    @Test("diff 夹具：多块、末尾无换行与按行补丁")
    func hunks() throws {
        let diff = try RepositoryDiff(patch: try fixture("diff-hunks.bin"))
        let file = try #require(diff.files.first)
        #expect(diff.files.count == 1)
        #expect(file.hunks.count == 2)
        #expect(file.hunks[0].oldStart == 1 && file.hunks[0].newStart == 1)
        #expect(file.hunks[1].oldStart == 7 && file.hunks[1].newStart == 7)
        #expect(file.hunks[1].lines.last?.noNewline ?? false)

        let patch = try diff.patch(path: "lines.txt", file: 0, hunk: 1, selectedLines: [3, 5], reverse: false)
        let expected = """
            diff --git "a/lines.txt" "b/lines.txt"
            --- "a/lines.txt"
            +++ "b/lines.txt"
            @@ -7,5 +7,5 @@
             seven
             eight
             nine
            -ten
             ahead
            +TEN

            """
        #expect(String(decoding: patch, as: UTF8.self) == expected)
    }

    /// 二进制段只给出提示，重命名保留原始扩展头与中文路径。
    @Test("diff 夹具：二进制与重命名")
    func binaryAndRename() throws {
        let diff = try RepositoryDiff(patch: try fixture("diff-binary-rename.bin"))
        #expect(diff.files.count == 2)
        #expect(diff.files[0].isBinary && diff.files[0].hunks.isEmpty)
        #expect(diff.files[1].headers.contains("rename from renamed source.txt"))
        #expect(diff.files[1].headers.contains("rename to 重命名 target.txt"))
        #expect(!diff.files[1].isBinary)
    }

    /// 合并提交、Unicode 作者、正文控制字符与日期都按固定字段读取，哈希长度随对象格式变化。
    @Test("log 夹具：SHA-1 与 SHA-256", arguments: [("log-sha1.bin", 40, 5), ("log-sha256.bin", 64, 4)])
    func history(name: String, hashLength: Int, count: Int) throws {
        let commits = try HistoryCommit.parse(try fixture(name))
        #expect(commits.count == count)
        #expect(commits.allSatisfy { $0.id.count == hashLength && $0.tree.count == hashLength })
        #expect(commits.filter { $0.parents.count == 2 }.count == 1)
        #expect(commits.last?.parents.isEmpty ?? false)
        #expect(commits.allSatisfy { $0.author == "Zoë Ünicode" && $0.committer == "Spooky Test" })

        let root = try #require(commits.last)
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-01T08:01:00+08:00"))
        #expect(root.commitDate == date)

        // 提交图按拓扑序逐行生成，合并提交从圆点分出第二条线。
        var graph = CommitGraph()
        let rows = commits.map { graph.append($0) }
        let merge = try #require(commits.firstIndex { $0.parents.count == 2 })
        #expect(rows[merge].segments.contains { $0.startsAtCommit && $0.end != rows[merge].column })

        if name == "log-sha1.bin" {
            #expect(root.message == "Root commit\n\nBody with\ttab and 中文\n\u{1f} control\n")
        }
    }

    /// 一次 for-each-ref 同时给出上游、远端默认分支和附注标签剥离后的提交。
    @Test("引用夹具：上游、符号引用与附注标签")
    func references() throws {
        let references = try RepositoryReference.parse(try fixture("refs.bin"))
        let byID = Dictionary(uniqueKeysWithValues: references.map { ($0.id, $0) })
        #expect(references.count == 7)

        let main = try #require(byID["refs/heads/main"])
        #expect(main.upstream == "refs/remotes/origin/main")
        #expect(main.upstreamRemote == "origin")
        #expect(main.upstreamBranch == "refs/heads/main")

        let tag = try #require(byID["refs/tags/v1.0"])
        #expect(tag.objectType == "commit")
        #expect(tag.objectID == byID["refs/remotes/origin/main"]?.objectID)

        // 附注标签带回打标签的时间与完整说明，轻量标签和分支没有说明，分支的时间是顶端提交的提交时间
        #expect(tag.date == Date(timeIntervalSince1970: 1_778_051_289))
        #expect(tag.message == "Release “1.0”\n\n第一行说明\nsecond line")
        #expect(byID["refs/tags/light"]?.message == nil)
        #expect(main.message == nil)
        #expect(main.date == Date(timeIntervalSince1970: 1_775_369_228))

        let snapshot = ReferenceSnapshot(references: references, remotes: [RepositoryRemote(name: "origin")])
        #expect(snapshot.defaultBranch(for: RepositoryRemote(name: "origin")) == "refs/remotes/origin/main")
        #expect(snapshot.remote(for: try #require(byID["refs/remotes/origin/side"]))?.name == "origin")
    }

    /// Fetch porcelain 覆盖快进、强制更新、新建、清理与标签。
    @Test("fetch 夹具：引用更新标志")
    func fetch() throws {
        let updates = try RemoteReferenceUpdate.parseFetch(try fixture("fetch.txt"))
        let flags = Dictionary(uniqueKeysWithValues: updates.map { ($0.reference, $0.flag) })
        #expect(updates.count == 5)
        #expect(flags["refs/remotes/origin/gone-local"] == "-")
        #expect(flags["refs/remotes/origin/main"] == " ")
        #expect(flags["refs/remotes/origin/fresh"] == "*")
        #expect(flags["refs/remotes/origin/side"] == "+")
        #expect(flags["refs/tags/v2.0"] == "*")
        #expect(updates.first { $0.flag == "*" }?.oldObject?.allSatisfy { $0 == "0" } ?? false)
    }

    /// Push porcelain 跳过 To / Done 行，保留被拒原因。
    @Test("push 夹具：新分支、快进与被拒")
    func push() throws {
        let updates = try RemoteReferenceUpdate.parsePush(try fixture("push.txt"))
        #expect(updates.map(\.flag) == [" ", "*", "!"])
        #expect(updates[1].reference == "refs/heads/published")
        #expect(updates[2].source == "refs/heads/side")
        #expect(updates[2].summary == "[rejected] (non-fast-forward)")
    }

    /// 读取随测试目标打包的夹具原始字节。
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
