import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Updates

extension WorkingCopyFileListTests {
    /// 增量更新的步骤：先一次删掉消失的行，再按新顺序移动与插入，相邻的插入合成一步；
    /// 按步骤依次改旧顺序，得到的正好是新顺序。
    @Test("增量更新的步骤")
    func rowSteps() {
        typealias Coordinator = WorkingCopyFileList.Coordinator

        #expect(
            Coordinator.steps(from: ["a", "b", "c", "d"], to: ["b", "e", "d", "c"])
                == [.remove([0]), .insert([1]), .move(from: 3, to: 2)]
        )
        #expect(Coordinator.steps(from: ["a"], to: ["x", "a", "y"]) == [.insert([0, 2])])
        #expect(Coordinator.steps(from: ["a", "b"], to: ["a", "b"]).isEmpty)

        // 删除、移动与插入交错时按步骤逐个执行
        let old = ["a", "b", "c", "d", "e"]
        let new = ["e", "x", "c", "a", "y"]
        var current = old

        for step in Coordinator.steps(from: old, to: new) {
            switch step {
            case .remove(let indexes):
                current = current.indices.filter { !indexes.contains($0) }.map { current[$0] }

            case .move(let from, let to):
                current.insert(current.remove(at: from), at: to)

            case .insert(let indexes):
                for index in indexes {
                    current.insert(new[index], at: index)
                }
            }
        }

        #expect(current == new)
    }

    /// 重载后保留仍在的选中项，多选只剩一部分时只留这些；选中项全部消失时先改选下面的邻行、没有再改选上面的，详情随之同步；
    /// 暂存把未跟踪文件变成已跟踪文件时仍是同一行；平铺、树形与搜索过滤下规则相同，沿用的行是同一个节点。
    @Test("重载后的增量更新与选择")
    func incrementalUpdates() async throws {
        let source = StatusSource()
        let session = RepositorySession(loadStatus: { _ in await source.status }, activities: RepositoryActivities())
        defer { session.close() }

        session.display(RepositoryLocation.local(path: "/temporary/updates-" + UUID().uuidString))

        let list = FileListHarness(session: session, source: source)

        // 平铺：多选的 b、c 里 b 消失，只留 c；d 由未跟踪变成已暂存，仍是同一行
        await list.show([.modified("a.txt"), .modified("b.txt"), .modified("c.txt"), .untracked("d.txt")])
        list.select(rows: [1, 2])

        let c = try #require(list.node(at: 2))
        let d = try #require(list.node(at: 3))

        await list.show([.modified("a.txt"), .modified("c.txt"), .added("d.txt"), .untracked("e.txt")])

        #expect(list.paths == ["a.txt", "c.txt", "d.txt", "e.txt"])
        #expect(list.selectedPaths == ["c.txt"] && list.node(at: 1) === c && list.node(at: 2) === d)

        // c 消失后改选下面的 d；d、e 都消失后改选上面的 a
        await list.show([.modified("a.txt"), .added("d.txt"), .untracked("e.txt")])
        #expect(list.selectedPaths == ["d.txt"])
        await until { session.selectedID?.path == "d.txt" }

        await list.show([.modified("a.txt")])
        #expect(list.selectedPaths == ["a.txt"])
        await until { session.selectedID?.path == "a.txt" }

        await list.show([])
        #expect(list.paths.isEmpty && list.selectedPaths.isEmpty)

        // 树形：选中的 src/x.swift 消失后改选同一目录里的 src/y.swift，目录行沿用
        list.listing = WorkingCopyListing(mode: .tree)
        await list.show([.modified("src/x.swift"), .modified("src/y.swift"), .modified("top.txt")])
        list.select(rows: [1])

        let directory = try #require(list.node(at: 0))

        await list.show([.modified("src/y.swift"), .modified("top.txt")])
        #expect(list.paths == ["src", "src/y.swift", "top.txt"] && list.node(at: 0) === directory)
        #expect(list.selectedPaths == ["src/y.swift"])

        // 搜索过滤：只在看得见的行里找邻行
        session.searchText = "txt"
        list.listing = WorkingCopyListing(mode: .list, filter: "txt")
        await list.show([.modified("a.txt"), .modified("b.swift"), .modified("c.txt"), .modified("d.txt")])
        list.select(rows: [1])

        await list.show([.modified("a.txt"), .modified("b.swift"), .modified("d.txt")])
        #expect(list.paths == ["a.txt", "d.txt"] && list.selectedPaths == ["d.txt"])
        await until { session.selectedID?.path == "d.txt" }
    }
}

// MARK: - StatusSource

/// 会话每次刷新读到的状态，测试逐步替换。
actor StatusSource {
    /// 当前的状态快照。
    private(set) var status = WorkingCopyStatus(branch: BranchStatus(head: "main"), entries: [])

    /// 换成新的状态条目。
    func set(_ entries: [StatusEntry]) {
        status = WorkingCopyStatus(branch: BranchStatus(head: "main"), entries: entries)
    }
}

// MARK: - FileListHarness

/// 不建窗口的文件列表：真实的列表视图与桥接器，按给定的显示选项渲染会话里的状态。
@MainActor
final class FileListHarness {
    /// 被测的会话。
    let session: RepositorySession

    /// 状态来源。
    let source: StatusSource

    /// 文件列表的桥接器。
    let coordinator: WorkingCopyFileList.Coordinator

    /// 文件列表，两列与 App 里相同。
    let outline = WorkingCopyFileList.FileOutlineView()

    /// 渲染时的显示选项。
    var listing = WorkingCopyListing(mode: .list)

    /// 当前各行的路径。
    var paths: [String] {
        (0 ..< outline.numberOfRows).compactMap { node(at: $0)?.path }
    }

    /// 当前选中行的路径。
    var selectedPaths: [String] {
        outline.selectedRowIndexes.compactMap { node(at: $0)?.path }
    }

    /// 建立列表并接上会话。
    init(session: RepositorySession, source: StatusSource) {
        self.session = session
        self.source = source
        coordinator = WorkingCopyFileList.Coordinator(session: session)

        for identifier in ["status", "path"] {
            outline.addTableColumn(NSTableColumn(identifier: .init(identifier)))
        }

        outline.outlineTableColumn = outline.tableColumns[1]
        outline.allowsMultipleSelection = true
        outline.sortDescriptors = WorkingCopyPreferences.defaultSortDescriptors
        outline.delegate = coordinator
        outline.dataSource = coordinator
        coordinator.outline = outline
    }

    /// 会话读到新的状态后重新渲染列表。
    func show(_ entries: [StatusEntry]) async {
        await source.set(entries)
        session.refresh()
        await session.refreshTask?.value

        coordinator.update(listing: listing, style: .init(fontSize: .medium, truncation: .beginning))
    }

    /// 像用户一样选中这些行，选择同步给会话。
    func select(rows: IndexSet) {
        outline.selectRowIndexes(rows, byExtendingSelection: false)
        coordinator.syncSelection()
    }

    /// 某一行的节点。
    func node(at row: Int) -> WorkingCopyFileList.Node? {
        outline.item(atRow: row) as? WorkingCopyFileList.Node
    }
}

// MARK: - StatusEntry

extension StatusEntry {
    /// 工作区里改过、还没暂存的文件。
    static func modified(_ path: String) -> Self {
        Self(kind: .tracked, path: path, unstaged: .modified)
    }

    /// 已暂存的新文件。
    static func added(_ path: String) -> Self {
        Self(kind: .tracked, path: path, staged: .added)
    }

    /// 未跟踪的文件。
    static func untracked(_ path: String) -> Self {
        Self(kind: .untracked, path: path)
    }
}
