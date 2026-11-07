// MARK: - EmptyCommitRequest

/// 进行中的操作没有任何改动时，提交或继续前的空提交确认。
struct EmptyCommitRequest {
    /// 序列中的一步：备选是跳过这一步；否则是中止当前操作。
    let isSequence: Bool

    /// 保留空提交：单个操作建空提交，序列保留这一步再继续；此时对话框已经关闭。
    let commit: () -> Void

    /// 单个操作中止，序列跳过这一步；此时对话框已经关闭。
    let alternate: () -> Void
}
