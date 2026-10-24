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

    /// 平铺与树形只列出状态里的改动；全部文件补出暂存区里没有改动的文件，状态里已有的路径不重复。
    @Test("全部文件补出未改动的文件")
    func allFiles() {
        let changes = WorkingCopyListing(mode: .tree).entries(status: Self.status, files: Self.files)
        #expect(changes == Self.status)

        let all = WorkingCopyListing(mode: .allFiles).entries(status: Self.status, files: Self.files)
        #expect(Array(all.prefix(Self.status.count)) == Self.status)
        #expect(all.dropFirst(Self.status.count).map(\.path) == ["README.md", "config.local"])
        #expect(all.dropFirst(Self.status.count).allSatisfy { $0.kind == .unchanged })
    }

    /// 被忽略与 assume-unchanged 文件只在打开对应选项时出现；只看冲突时不补任何文件。
    @Test("被忽略与 assume-unchanged 文件按选项出现")
    func ignoredAndAssumeUnchanged() {
        let listing = WorkingCopyListing(mode: .list, showsIgnored: true, showsAssumeUnchanged: true)
        let extra = listing.entries(status: Self.status, files: Self.files).dropFirst(Self.status.count)

        #expect(extra.map(\.path) == ["build/", "config.local"])
        #expect(extra.map(\.kind) == [.ignored, .unchanged])

        let conflicts = WorkingCopyListing(
            mode: .allFiles,
            showsIgnored: true,
            showsAssumeUnchanged: true,
            onlyConflicts: true
        )
        #expect(conflicts.entries(status: Self.status, files: Self.files).map(\.path) == ["merge.txt"])
    }

    /// 搜索按路径或文件名过滤：不区分大小写，组合与分解两种 Unicode 写法相同，重命名的原路径也能命中。
    @Test("搜索不区分大小写与 Unicode 写法")
    func filter() {
        let entries = { (query: String) in
            WorkingCopyListing(mode: .allFiles, filter: query)
                .entries(status: Self.status, files: Self.files)
                .map(\.path)
        }

        #expect(entries("APP.SWIFT") == ["src/App.swift"])
        #expect(entries("CAFÉ") == ["notes/cafe\u{301}.txt"])
        #expect(entries("old") == ["docs/新 名字.md"])
        #expect(entries("readme") == ["README.md"])
        #expect(entries("  ").count == Self.status.count + 2)
        #expect(entries("zzz").isEmpty)
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

    /// 文件操作的可用范围：只有暂存区里的文件能停止跟踪，工作区里已经没有的文件不能删除或打开。
    @Test("文件操作的适用条目")
    func entryPredicates() {
        let stagedDeletion = StatusEntry(kind: .tracked, path: "gone.txt", staged: .deleted)
        let worktreeDeletion = StatusEntry(kind: .tracked, path: "removed.txt", unstaged: .deleted)
        let ignoredDirectory = StatusEntry(kind: .ignored, path: "build/")
        let unchanged = StatusEntry(kind: .unchanged, path: "README.md")

        #expect(!stagedDeletion.isInIndex && !stagedDeletion.isDeletable)
        #expect(worktreeDeletion.isInIndex && !worktreeDeletion.isOpenable)
        #expect(ignoredDirectory.isDeletable && !ignoredDirectory.isOpenable && !ignoredDirectory.isStageable)
        #expect(unchanged.isInIndex && unchanged.isOpenable && !unchanged.hasWorkingCopyDiff)
        #expect(!Self.status[3].isInIndex && !Self.status[3].isDeletable)
    }

    /// 移动的新路径必须留在仓库内：不能是绝对路径、含 “.” 或 “..” 段、换行，或与原路径相同。
    @Test("移动目标路径校验")
    func moveDestination() {
        #expect(WorkingCopyFileDialog.destination("docs/新 名字.md", from: "a.md") == "docs/新 名字.md")

        for invalid in ["", "a.md", "/etc/passwd", "../outside.md", "docs/./a.md", "docs//a.md", "a\nb.md"] {
            #expect(WorkingCopyFileDialog.destination(invalid, from: "a.md") == nil)
        }
    }

    /// 恢复版本的候选：当前分支排在最前，打开表单时预选它；同名标签仍各占一项，符号引用不列出，分离 HEAD 时保持快照顺序。
    @Test("恢复版本的候选顺序")
    func revisionCandidates() {
        let references = [
            Self.reference("refs/heads/feature"),
            Self.reference("refs/heads/main"),
            Self.reference("refs/remotes/origin/HEAD", symbolicTarget: "refs/remotes/origin/main"),
            Self.reference("refs/remotes/origin/main"),
            Self.reference("refs/tags/main"),
        ]

        #expect(
            WorkingCopyFileDialog.revisions(in: references, currentBranch: "main")
                == ["main", "feature", "origin/main", "main"]
        )
        #expect(
            WorkingCopyFileDialog.revisions(in: references, currentBranch: nil)
                == ["feature", "main", "origin/main", "main"]
        )
    }

    /// 补丁前像不符与移动目标已存在都属于仓库状态问题；前像不符时列出这些文件。
    @Test("文件操作错误的呈现")
    func failures() {
        let mismatch = AppFailure(
            error: WorkingCopyFileError.patchPreimageMismatch(["a.txt", "b [*].txt"]),
            opening: false,
            location: nil,
            writing: true
        )
        #expect(mismatch.kind == .repository)
        #expect(mismatch.title == AppLocalization.text("files.error.preimage"))
        #expect(mismatch.details.contains("a.txt\nb [*].txt"))

        let exists = AppFailure(error: WorkingCopyFileError.destinationExists, opening: false, location: nil)
        #expect(exists.kind == .repository)

        let tool = AppFailure(
            error: DiffToolLaunchError(diagnostic: "xcode-select: error"),
            opening: false,
            location: nil
        )
        #expect(tool.details.contains("xcode-select: error"))
        #expect(tool.message == AppLocalization.text("files.error.diffToolHelp"))
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
