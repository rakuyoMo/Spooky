// MARK: - NavigationHistory

/// 一个窗口的后退 / 前进记录：按到达顺序排列的视图引用，以及当前所在的位置。
struct NavigationHistory {
    /// 到达过的视图，最早的在前。
    private(set) var entries: [ViewReference] = []

    /// 当前视图在 `entries` 中的位置；还没有记录时为 −1。
    private(set) var index = -1

    /// 当前所在的视图。
    var current: ViewReference? {
        entries.indices.contains(index) ? entries[index] : nil
    }

    /// 当前位置之前还有视图。
    var canGoBack: Bool { index > 0 }

    /// 当前位置之后还有视图。
    var canGoForward: Bool { index < entries.count - 1 }

    /// 记下新到达的视图：与当前视图相同时不记；从中间位置到达新视图时，截掉当前位置之后的记录。
    mutating func record(_ reference: ViewReference) {
        guard reference != current else {
            return
        }

        entries.removeSubrange((index + 1)...)
        entries.append(reference)
        index = entries.count - 1
    }

    /// 退到上一个视图并返回它；已在最前面时返回 nil。
    mutating func goBack() -> ViewReference? {
        guard canGoBack else {
            return nil
        }

        index -= 1
        return entries[index]
    }

    /// 进到下一个视图并返回它；已在最后面时返回 nil。
    mutating func goForward() -> ViewReference? {
        guard canGoForward else {
            return nil
        }

        index += 1
        return entries[index]
    }
}
