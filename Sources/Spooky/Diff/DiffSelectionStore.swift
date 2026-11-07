import Foundation
import Observation
import SpookyKit

/// 会话当前文件和暂存侧的行选择，按完整块原文字节在成功重载后重新绑定。
@MainActor
@Observable
final class DiffSelectionStore {
    /// 仓库由所属会话区分，存储只记录当前文件行与暂存侧。
    struct Scope: Equatable {
        /// 列表中的文件及条目类型。
        let row: StatusRowID

        /// 当前比较侧。
        let side: DiffSide
    }

    /// 延迟确认捕获的块身份，模型实例阻止切走再切回后清掉新选区。
    struct Target {
        /// 发起动作时的文件与暂存侧。
        let scope: Scope

        /// 完整原始块字节。
        let raw: Data

        /// 发起动作时的选择实例。
        let selection: DiffLineSelection
    }

    /// 当前快照中一个普通块的绑定。
    private struct Entry {
        /// 仅用于当前快照寻址的文件段与块序号。
        let address: [Int]

        /// 跨重载身份只由原始块字节决定。
        let raw: Data

        /// 可复用的逻辑选择模型。
        let selection: DiffLineSelection
    }

    /// 当前范围，切换后不会恢复旧范围的选择。
    private(set) var scope: Scope? = nil

    /// 文件 / 侧 / 设置重置时更新，普通重载不重建整个文本区。
    private(set) var revision = UUID()

    /// 当前快照的行选择映射，供块视图重新绑定。
    private var entries: [Entry] = []

    /// 切换到当前文件 / 侧，退役旧视图仍可能持有的模型。
    func setScope(_ row: StatusRowID?, side: DiffSide) {
        let next = row.map { Scope(row: $0, side: side) }
        guard next != scope else { return }

        reset()
        scope = next
    }

    /// 成功读取后按原文字节逐块匹配，重复原文仍各自保有独立的模型。
    func reconcile(_ diff: RepositoryDiff?) {
        var previous = Dictionary(grouping: entries, by: \.raw)
        var next: [Entry] = []

        for file in diff?.files ?? [] {
            for hunk in file.hunks where hunk.combinedRanges == nil {
                let selection: DiffLineSelection
                if var matches = previous[hunk.rawContent], !matches.isEmpty {
                    selection = matches.removeFirst().selection
                    previous[hunk.rawContent] = matches
                } else {
                    selection = DiffLineSelection()
                }
                selection.bind(hunk)
                selection.end()
                next.append(Entry(address: [file.id, hunk.id], raw: hunk.rawContent, selection: selection))
            }
        }

        for entry in previous.values.joined() { entry.selection.invalidate() }
        entries = next
    }

    /// 当前快照的普通块；组合 Diff 不进入可写选择路径。
    func selection(file: Int, hunk: Int) -> DiffLineSelection? {
        entries.first { $0.address == [file, hunk] }?.selection
    }

    /// 捕获本次确认真正执行后应清空的原文块。
    func target(file: Int, hunk: Int) -> Target? {
        guard let scope, let entry = entries.first(where: { $0.address == [file, hunk] }) else { return nil }

        return Target(scope: scope, raw: entry.raw, selection: entry.selection)
    }

    /// 动作被接受后只清发起块；范围切换或原文变化后的确认不影响新状态。
    func clear(_ target: Target?) {
        guard
            let target, target.scope == scope,
            entries.contains(where: { $0.raw == target.raw && $0.selection === target.selection })
        else { return }

        target.selection.clear()
    }

    /// 设置重置时保留当前范围，但退役全部旧模型和视图身份。
    func reset() {
        for entry in entries { entry.selection.invalidate() }
        entries = []
        revision = UUID()
    }
}
