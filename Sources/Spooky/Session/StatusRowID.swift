import SpookyKit

// MARK: - StatusRowID

/// 文件行的稳定标识，区分 `rm --cached` 后同路径的已跟踪与未跟踪记录。
struct StatusRowID: Hashable {
    /// Git 给出的相对路径。
    let path: String

    /// 同一路径可以同时拥有已跟踪和未跟踪状态。
    let kind: StatusEntry.Kind
}
