// MARK: - ConfirmationRequest

/// 会话请窗口确认的一次操作：窗口以对话框骨架的确认版呈现，用户确认后才执行。
struct ConfirmationRequest {
    /// 对话框的标题，是一个名词短语。
    let title: String

    /// 写明影响范围的说明。
    let message: String

    /// 主按钮的标题，写出要执行的动作。
    let submitTitle: String

    /// 内容区 “Do not ask me again” 对应的确认项，勾选并确认后关掉它；为 nil 时没有这个勾选框。
    var suppression: ServerConfirmation? = nil

    /// 确认后执行，此时对话框已经关闭。
    let action: () -> Void
}
