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
    /// 画成选中的卡片与箭头：显示一侧时是这一侧，两侧都选时是两侧。
    var highlighted: Set<ConflictSide> {
        switch self {
        case .side(let side): [side]
        case .both: Set(ConflictSide.allCases)
        case .unselected, .current: []
        }
    }

    /// 按选择与当前文件得出结果：选过卡片时按选择；还没有选时，双方修改与双方新增的当前文件等于某侧就显示该侧；
    /// 其余情况手动合并过就显示当前版本，否则提示选择。
    ///
    /// - Parameters:
    ///   - selection: 选中的卡片；还没有单击过卡片时为 nil。
    ///   - contents: 载入的三方内容与当前文件。
    ///   - kind: 冲突类型。
    static func of(selection: Set<ConflictSide>?, contents: ConflictContents, kind: ConflictKind?) -> Self {
        if let selection {
            if selection.count == ConflictSide.allCases.count {
                return .both
            }

            if let side = selection.first {
                return .side(side)
            }
        } else if kind == .bothModified || kind == .bothAdded, let worktree = contents.worktree {
            if worktree == contents.ours {
                return .side(.ours)
            }

            if worktree == contents.theirs {
                return .side(.theirs)
            }
        }

        return contents.isManuallyEdited ? .current : .unselected
    }
}

// MARK: - Selection

extension ConflictSide {
    /// 单击一张卡片后的选择：已选就取消，没选就加入，不看 ⌘。
    ///
    /// - Parameter selection: 单击前画成选中的卡片。
    func toggled(in selection: Set<Self>) -> Set<Self> {
        selection.contains(self) ? selection.subtracting([self]) : selection.union([self])
    }
}
