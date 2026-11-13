import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - WorkingCopyFileListTests

/// 工作区文件表格的行规则：排序、状态徽标与提示。
@MainActor
struct WorkingCopyFileListTests {
    /// 测试用的条目：大小写不同的文件名、目录里的文件，各有不同的状态。
    private static let entries = [
        StatusEntry(kind: .untracked, path: "README.md"),
        StatusEntry(kind: .tracked, path: "notes.txt", unstaged: .modified),
        StatusEntry(kind: .tracked, path: "docs/b.md", staged: .added),
        StatusEntry(kind: .tracked, path: "docs/A.md", unstaged: .deleted),
    ]

    /// 默认先按路径排、不区分大小写，`notes.txt` 在 `README.md` 之前；按状态排时用两位状态码，可以倒序；
    /// 树形的目录内部同样排序，目录没有状态，按状态升序时排在同层文件之前。
    @Test("表头排序")
    func sorting() {
        let defaults = WorkingCopyPreferences.defaultSortDescriptors
        let rows = Self.entries.map { WorkingCopyFileList.Node(path: $0.path, entry: $0) }
        let list = { (descriptors: [NSSortDescriptor]) in
            WorkingCopyFileList.Coordinator.sorted(rows, by: descriptors).map(\.path)
        }

        #expect(list(defaults) == ["docs/A.md", "docs/b.md", "notes.txt", "README.md"])

        // 状态码依次是 .D、.M、??、A.
        let status = [NSSortDescriptor(key: "status", ascending: true), defaults[0]]
        #expect(list(status) == ["docs/A.md", "notes.txt", "README.md", "docs/b.md"])

        let descending = [NSSortDescriptor(key: "status", ascending: false), defaults[0]]
        #expect(list(descending) == ["docs/b.md", "README.md", "notes.txt", "docs/A.md"])

        // 树形：顶层与目录内部各自排序
        let tree = WorkingCopyFileList.Coordinator.sorted(
            WorkingCopyFileList.Coordinator.tree(Self.entries),
            by: defaults
        )
        #expect(tree.map(\.path) == ["docs", "notes.txt", "README.md"])
        #expect(tree[0].children.map(\.path) == ["docs/A.md", "docs/b.md"])

        let byStatus = WorkingCopyFileList.Coordinator.sorted(tree, by: status)
        #expect(byStatus.map(\.path) == ["docs", "notes.txt", "README.md"])
        #expect(byStatus[0].children.map(\.path) == ["docs/A.md", "docs/b.md"])
    }

    /// 表头排序所有仓库共用一个记录：没有记录时为默认排序，保存的多级排序原样读回；
    /// 记录里有不认识的列或重复的列时回到默认排序。
    @Test("表头排序的保存")
    func storedSort() throws {
        // 偏好写进临时目录里的 plist，测试结束随目录删除
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-sort-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let keys = { (descriptors: [NSSortDescriptor]) in descriptors.map { "\($0.key ?? "")\($0.ascending)" } }

        #expect(keys(WorkingCopyPreferences.sortDescriptors(defaults: defaults)) == ["pathtrue", "statustrue"])

        let changed = [
            NSSortDescriptor(key: "status", ascending: false),
            NSSortDescriptor(key: "path", ascending: true),
        ]
        WorkingCopyPreferences.storeSortDescriptors(changed, defaults: defaults)
        #expect(keys(WorkingCopyPreferences.sortDescriptors(defaults: defaults)) == ["statusfalse", "pathtrue"])

        // 无效的记录各写进一个偏好域：覆盖已有的值后立即读取，可能仍读到旧值
        let invalid: [[[String: Any]]] = [
            [["key": "size", "ascending": true]],
            [["key": "path", "ascending": true], ["key": "path", "ascending": false]],
            [["key": "path"]],
        ]

        for (index, records) in invalid.enumerated() {
            let domain = try #require(UserDefaults(suiteName: directory.appending(path: "invalid-\(index)").path))
            domain.set(records, forKey: WorkingCopyPreferences.sortOrder)

            #expect(keys(WorkingCopyPreferences.sortDescriptors(defaults: domain)) == ["pathtrue", "statustrue"])
        }
    }

    /// 普通文件的提示分两行写出暂存区与工作区的变化，没有变化的一侧写未改动；未跟踪文件两行都写未跟踪，徽标只在右边一格；
    /// 没有改动的补充行不画徽标、没有勾选框，先暂存再标记 assume-unchanged 的行仍有徽标与勾选框。
    @Test("状态徽标与提示")
    func statusBadges() {
        let untrackedName = AppLocalization.text("status.untracked")
        let untracked = FileStatusView(entry: StatusEntry(kind: .untracked, path: "new.txt"))

        #expect(untracked.codes == ("", "?"))
        #expect(untracked.description == AppLocalization.text("status.description", untrackedName, untrackedName))

        let staged = StatusEntry(kind: .tracked, path: "staged.txt", staged: .modified)
        let stagedDescription = AppLocalization.text(
            "status.description",
            AppLocalization.text("status.modified"),
            AppLocalization.text("status.unchanged")
        )

        #expect(FileStatusView(entry: staged).description == stagedDescription)

        // 先暂存再标记：徽标与勾选框都保留，提示说明 Git 不检查它的改动
        let marked = FileStatusView(entry: staged, assumeUnchanged: true)

        #expect(marked.codes == ("M", "") && staged.isStageable)
        #expect(marked.description == AppLocalization.text("files.assumeUnchanged.status"))

        // 补出的无状态行
        let unchanged = StatusEntry(kind: .unchanged, path: "config.local")

        #expect(FileStatusView(entry: unchanged, assumeUnchanged: true).codes == ("", ""))
        #expect(!unchanged.isStageable)
    }

    /// 冲突文件固定画两枚徽标，字母是 Git 的未合并两码：七种组合各自照原样显示，不套用普通的暂存区 / 工作区写法。
    @Test("冲突的两枚徽标")
    func conflictBadges() throws {
        let codes = ["AA", "UU", "DU", "UD", "AU", "UA", "DD"]
        let hash = String(repeating: "a", count: 40)

        // 每种组合一条 porcelain v2 的未合并记录
        let records = codes.enumerated().map { index, xy in
            "u \(xy) N... 100644 100644 100644 100644 \(hash) \(hash) \(hash) file \(index).txt\0"
        }

        let status = try WorkingCopyStatus(porcelainV2: Data(records.joined().utf8))
        let badges = status.entries.map { entry in
            let badge = FileStatusView(entry: entry).codes
            return badge.staged + badge.unstaged
        }

        #expect(status.entries.allSatisfy { $0.kind == .conflicted })
        #expect(badges == codes)
    }
}
