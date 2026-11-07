import SpookyKit

// MARK: - ConflictSide

/// 冲突向导里的一张版本卡片。
enum ConflictSide: Hashable, CaseIterable {
    /// 我方版本。
    case ours

    /// 对方版本。
    case theirs
}

// MARK: - ConflictResult

/// 结果框显示的内容，决定结果框下的动作按钮。
enum ConflictResult: Equatable {
    /// 还没有选版本，当前文件也不是某一侧或手动合并的结果。
    case unselected

    /// 选中了一侧，或当前文件等于这一侧。
    case side(ConflictSide)

    /// 两侧都选中，交给合并工具。
    case both

    /// 当前文件与两侧都不同且没有冲突标记，是手动编辑或合并工具的结果。
    case current
}

extension ConflictResult {
    /// 按选择与当前文件得出结果：选择优先；没有选择时当前文件等于某侧就显示该侧，手动合并过就显示当前版本。
    ///
    /// - Parameters:
    ///   - selection: 选中的卡片。
    ///   - contents: 载入的三方内容与当前文件。
    static func of(selection: Set<ConflictSide>, contents: ConflictContents) -> Self {
        if selection.count == ConflictSide.allCases.count {
            return .both
        }

        if let side = selection.first {
            return .side(side)
        }

        guard let worktree = contents.worktree else {
            return .unselected
        }

        if worktree == contents.ours {
            return .side(.ours)
        }

        if worktree == contents.theirs {
            return .side(.theirs)
        }

        return contents.isManuallyEdited ? .current : .unselected
    }
}

// MARK: - Selection

extension ConflictSide {
    /// 单击一张卡片后的选择：再单击已选的卡片取消它；按住 ⌘ 时加入已有的选择，否则只选这一张。
    ///
    /// - Parameters:
    ///   - selection: 单击前的选择。
    ///   - adding: 单击时按住了 ⌘。
    func toggled(in selection: Set<Self>, adding: Bool) -> Set<Self> {
        if selection.contains(self) {
            return selection.subtracting([self])
        }

        return adding ? selection.union([self]) : [self]
    }
}
