import SpookyKit

/// 文件头与底栏共用的本地化摘要，不从显示文字反推 Git 数据。
enum DiffSummary {
    /// 按模式变化、新建 / 删除、重命名、二进制、统计的顺序生成摘要。
    static func text(for file: DiffFile) -> String {
        let metadata = file.metadata
        var seen: Set<DiffFileMode> = []
        let oldModes = metadata.oldModes.filter { $0.exists && seen.insert($0).inserted }
        let old = oldModes.map(mode).joined(separator: ", ")
        var parts: [String] = []

        if metadata.isAdded, let new = metadata.newMode {
            parts.append(AppLocalization.text("diff.summary.added", mode(new)))
        } else if metadata.isDeleted, !oldModes.isEmpty {
            parts.append(AppLocalization.text("diff.summary.deleted", old))
        } else if let new = metadata.newMode, new.exists, oldModes.contains(where: { $0 != new }) {
            parts.append(AppLocalization.text("diff.summary.modeChanged", old, mode(new)))
        }

        if let rename = metadata.rename {
            parts.append(AppLocalization.text("diff.summary.renamed", rename.oldPath, rename.newPath, rename.similarity))
        }

        if file.isBinary {
            parts.append(AppLocalization.text("diff.summary.binary"))
        } else {
            let statistics = statistics(in: [file])
            if !statistics.isEmpty { parts.append(statistics) }
        }

        return parts.joined(separator: "\n")
    }

    /// 没有文本块时为空；组合改动按显示逻辑行计一次，不按父侧数重复计算。
    static func statistics(in files: [DiffFile]) -> String {
        let hunks = files.filter { !$0.isBinary }.flatMap(\.hunks)
        guard !hunks.isEmpty else { return "" }

        let lines = hunks.flatMap(\.lines)
        return AppLocalization.text(
            "working.diffSummary",
            count(hunks.count, kind: "chunks"),
            count(lines.filter { $0.prefix == 43 }.count, kind: "insertions"),
            count(lines.filter { $0.prefix == 45 }.count, kind: "deletions")
        )
    }

    /// 各计数独立选单复数，零使用复数键。
    static func count(_ count: Int, kind: String) -> String {
        AppLocalization.text("diff.summary." + kind + (count == 1 ? ".one" : ""), count)
    }

    /// 保留 Git 原模式数值，类别独立本地化。
    private static func mode(_ mode: DiffFileMode) -> String {
        AppLocalization.text(
            "diff.summary.mode",
            mode.value,
            AppLocalization.text("diff.summary.mode." + mode.kind.rawValue)
        )
    }
}
