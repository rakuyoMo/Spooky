import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - WorkingCopyListingTests

/// 工作区列表的显示规则：显示选项与搜索只决定列出哪些条目，Git 状态模型保持原样。
@MainActor
struct WorkingCopyListingTests {
    /// 测试用的 Git 状态：一处修改、一次重命名、一个未跟踪文件与一个冲突文件。
    private static let status = [
        StatusEntry(kind: .tracked, path: "src/App.swift", unstaged: .modified),
        StatusEntry(kind: .tracked, path: "docs/新 名字.md", originalPath: "docs/old.md", staged: .renamed),
        StatusEntry(kind: .untracked, path: "notes/cafe\u{301}.txt"),
        StatusEntry(kind: .conflicted, path: "merge.txt", staged: .unmerged, unstaged: .unmerged),
    ]

    /// 补充清单：暂存区里还有没有改动的文件与一个 assume-unchanged 文件，另有被忽略的目录。
    private static let files = WorkingTreeFileListing(
        index: [
            IndexFile(path: "src/App.swift", assumeUnchanged: false),
            IndexFile(path: "README.md", assumeUnchanged: false),
            IndexFile(path: "config.local", assumeUnchanged: true),
        ],
        ignored: ["build/"]
    )

    /// 平铺与树形只列出状态里的改动；全部文件补出暂存区里没有改动的文件，状态里已有的路径不重复；
    /// 被忽略与 assume-unchanged 文件只在打开对应选项时出现。
    @Test("列出的条目随显示选项变化")
    func entries() {
        let changes = WorkingCopyListing(mode: .tree).entries(status: Self.status, files: Self.files)
        #expect(changes == Self.status)

        // 全部文件在状态之后补出未改动的文件。
        let all = WorkingCopyListing(mode: .allFiles).entries(status: Self.status, files: Self.files)
        let unchanged = all.dropFirst(Self.status.count)

        #expect(Array(all.prefix(Self.status.count)) == Self.status)
        #expect(unchanged.map(\.path) == ["README.md", "config.local"])
        #expect(unchanged.allSatisfy { $0.kind == .unchanged })

        // 打开两个选项后，平铺也补出被忽略的目录与 assume-unchanged 文件。
        let listing = WorkingCopyListing(mode: .list, showsIgnored: true, showsAssumeUnchanged: true)
        let extra = listing.entries(status: Self.status, files: Self.files).dropFirst(Self.status.count)

        #expect(extra.map(\.path) == ["build/", "config.local"])
        #expect(extra.map(\.kind) == [.ignored, .unchanged])
    }

    /// 只看冲突时不补任何文件，但保留这次操作已经解决的文件：解决后仍有改动的照常列出，与 HEAD 相同、已不在状态里的补成未改动的条目，
    /// 不只看冲突时同样保留；
    /// 搜索按路径或文件名过滤：不区分大小写，组合与分解两种 Unicode 写法相同，重命名的原路径也能命中。
    @Test("只看冲突与搜索的过滤")
    func conflictsAndFilter() {
        let conflicts = WorkingCopyListing(
            mode: .allFiles,
            showsIgnored: true,
            showsAssumeUnchanged: true,
            conflictPaths: ["merge.txt"]
        )
        #expect(conflicts.entries(status: Self.status, files: Self.files).map(\.path) == ["merge.txt"])

        // 冲突路径里已经解决的文件仍然列出。
        var resolved = WorkingCopyListing(
            mode: .list,
            conflictPaths: ["merge.txt", "src/App.swift", "same.txt"]
        )

        let entries = resolved.entries(status: Self.status, files: Self.files)
        #expect(entries.map(\.path) == ["src/App.swift", "merge.txt", "same.txt"])
        #expect(entries.map(\.kind) == [.tracked, .conflicted, .unchanged])

        // 搜索仍在冲突文件里过滤。
        resolved.filter = "same"
        #expect(resolved.entries(status: Self.status, files: Self.files).map(\.path) == ["same.txt"])

        // 不只看冲突时，已解决、与 HEAD 相同的文件同样留在列表里；全部文件里不与暂存区清单重复
        let kept = WorkingCopyListing(mode: .list, resolvedPaths: ["merge.txt", "same.txt"])
            .entries(status: Self.status, files: Self.files)
            .dropFirst(Self.status.count)

        #expect(kept.map(\.path) == ["same.txt"] && kept.allSatisfy { $0.kind == .unchanged })

        let allFiles = WorkingCopyListing(mode: .allFiles, resolvedPaths: ["README.md"])
            .entries(status: Self.status, files: Self.files)
            .map(\.path)

        #expect(allFiles.filter { $0 == "README.md" }.count == 1)

        // 操作结束后不再有已解决的记录，这类文件随之消失
        #expect(WorkingCopyListing(mode: .list).entries(status: Self.status, files: Self.files) == Self.status)

        // 全部文件里搜索。
        let search = { (query: String) in
            WorkingCopyListing(mode: .allFiles, filter: query)
                .entries(status: Self.status, files: Self.files)
                .map(\.path)
        }

        #expect(search("APP.SWIFT") == ["src/App.swift"])
        #expect(search("CAFÉ") == ["notes/cafe\u{301}.txt"])
        #expect(search("old") == ["docs/新 名字.md"])
        #expect(search("readme") == ["README.md"])
        #expect(search("  ").count == Self.status.count + 2)
        #expect(search("zzz").isEmpty)
    }

    /// 显示模式只有一个全局记录：没有记录时为平铺，记下的模式对之后打开的每个仓库都生效，无法识别的记录回到平铺。
    @Test("显示模式所有仓库共用")
    func sharedListMode() throws {
        // 偏好写进临时目录里的 plist，测试结束随目录删除
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-modes-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))

        #expect(WorkingCopyListMode.stored(defaults: defaults) == .list)

        WorkingCopyListMode.store(.allFiles, defaults: defaults)
        #expect(WorkingCopyListMode.stored(defaults: defaults) == .allFiles)

        // 不认识的值写进另一个偏好域：覆盖已有的值后立即读取，可能仍读到旧值
        let unknown = try #require(UserDefaults(suiteName: directory.appending(path: "unknown").path))
        unknown.set(9, forKey: "workingCopyViewMode")
        #expect(WorkingCopyListMode.stored(defaults: unknown) == .list)
    }

    /// 状态头的分支：未出生分支照写分支名、不附加说明；分离 HEAD 只取前 8 位哈希，SHA-256 仓库同样如此；
    /// 既没有分支也没有提交时写没有 HEAD 分支。
    @Test("状态头的分支写法")
    func branchTitles() {
        let sha1 = "0123456789abcdef0123456789abcdef01234567"
        let sha256 = String(repeating: "fedcba98", count: 8)

        #expect(WorkingCopyListView.branchTitle(BranchStatus(head: "main")) == "main")
        #expect(WorkingCopyListView.branchTitle(BranchStatus(head: "main", oid: sha1)) == "main")

        // 分离 HEAD 的显示缩写与哈希长度无关
        #expect(
            WorkingCopyListView.branchTitle(BranchStatus(oid: sha1))
                == AppLocalization.text("branch.detached", "01234567")
        )
        #expect(
            WorkingCopyListView.branchTitle(BranchStatus(oid: sha256))
                == AppLocalization.text("branch.detached", "fedcba98")
        )

        #expect(WorkingCopyListView.branchTitle(BranchStatus()) == AppLocalization.text("branch.noHeadBranch"))
    }

    /// 文件操作的可用范围：只有暂存区里的文件能停止跟踪，工作区里已经没有的文件不能删除或打开；
    /// 补丁前像不符与移动目标已存在都属于仓库状态问题，前像不符时列出这些文件，外部工具启动失败时写出诊断。
    @Test("文件操作的适用条目与错误呈现")
    func fileOperations() {
        let stagedDeletion = StatusEntry(kind: .tracked, path: "gone.txt", staged: .deleted)
        let worktreeDeletion = StatusEntry(kind: .tracked, path: "removed.txt", unstaged: .deleted)
        let ignoredDirectory = StatusEntry(kind: .ignored, path: "build/")
        let unchanged = StatusEntry(kind: .unchanged, path: "README.md")

        #expect(!stagedDeletion.isInIndex && !stagedDeletion.isDeletable)
        #expect(worktreeDeletion.isInIndex && !worktreeDeletion.isOpenable)
        #expect(unchanged.isInIndex && unchanged.isOpenable && !unchanged.hasWorkingCopyDiff)
        #expect(!Self.status[3].isInIndex && !Self.status[3].isDeletable)

        #expect(
            ignoredDirectory.isDeletable
                && !ignoredDirectory.isOpenable
                && !ignoredDirectory.isStageable
        )

        // 错误的类别与详情。
        let mismatch = AppFailure(
            error: WorkingCopyFileError.patchPreimageMismatch(["a.txt", "b [*].txt"]),
            opening: false,
            location: nil,
            writing: true
        )
        #expect(mismatch.kind == .repository)
        #expect(mismatch.details.contains("a.txt\nb [*].txt"))

        let exists = AppFailure(error: WorkingCopyFileError.destinationExists, opening: false, location: nil)
        #expect(exists.kind == .repository)

        let tool = AppFailure(
            error: ExternalToolLaunchError(diagnostic: "/Applications/Tool.app/Contents/MacOS/tool"),
            opening: false,
            location: nil
        )
        #expect(tool.details.contains("/Applications/Tool.app/Contents/MacOS/tool"))
    }

    /// 移动的新路径必须留在仓库内：不能是绝对路径、含 “.” 或 “..” 段、换行，或与原路径相同；
    /// 恢复版本的候选按引用的公共顺序排列，当前分支不提前，打开表单时预选第一项；同名标签仍各占一项，符号引用不列出；
    /// 其它版本组合框的候选仍是当前分支在前。
    @Test("移动目标校验与恢复版本的候选")
    func dialogInputs() {
        #expect(WorkingCopyFileDialog.destination("docs/新 名字.md", from: "a.md") == "docs/新 名字.md")

        for invalid in ["", "a.md", "/etc/passwd", "../outside.md", "docs/./a.md", "docs//a.md", "a\nb.md"] {
            #expect(WorkingCopyFileDialog.destination(invalid, from: "a.md") == nil)
        }

        // 恢复版本的候选：本地分支 main 排在 feature 之前，其后是远端分支与标签
        let references = [
            Self.reference("refs/heads/feature"),
            Self.reference("refs/heads/main"),
            Self.reference("refs/remotes/origin/HEAD", symbolicTarget: "refs/remotes/origin/main"),
            Self.reference("refs/remotes/origin/main"),
            Self.reference("refs/tags/main"),
        ]

        let snapshot = ReferenceSnapshot(references: references, remotes: [])

        #expect(WorkingCopyFileDialog.revisions(in: snapshot) == ["main", "feature", "origin/main", "main"])

        // 重置、检出版本与变基到别处的候选仍是当前分支在前，分离 HEAD 时保持快照顺序
        #expect(
            RepositorySession.revisionCandidates(in: references, currentBranch: "main")
                == ["main", "feature", "origin/main", "main"]
        )
        #expect(
            RepositorySession.revisionCandidates(in: references, currentBranch: nil)
                == ["feature", "main", "origin/main", "main"]
        )
    }
}

// MARK: - Helpers

extension WorkingCopyListingTests {
    /// 指向同一个提交的引用。
    private static func reference(_ id: String, symbolicTarget: String? = nil) -> RepositoryReference {
        RepositoryReference(
            id: id,
            objectID: String(repeating: "a", count: 40),
            objectType: "commit",
            upstream: nil,
            upstreamRemote: nil,
            upstreamBranch: nil,
            symbolicTarget: symbolicTarget
        )
    }
}
