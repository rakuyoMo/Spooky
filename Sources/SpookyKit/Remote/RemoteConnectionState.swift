import Foundation

// MARK: - RemoteConnectionState

/// 仓库的 SSH 连接状态，断线不清空上次成功的工作区快照。
public enum RemoteConnectionState: String, Sendable, CaseIterable {
    /// 正在完成首次体检与部署。
    case connecting

    /// 主连接和回调通道可用。
    case connected

    /// 正在重新建立主连接。
    case reconnecting

    /// 当前不可用，保留诊断供重试。
    case unavailable
}
