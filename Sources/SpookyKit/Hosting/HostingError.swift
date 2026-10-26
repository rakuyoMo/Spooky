import Foundation

// MARK: - HostingError

/// 托管服务 API 的失败；带服务端返回的原文，不含令牌与请求地址。
public enum HostingError: Error, Sendable, Equatable {
    /// 令牌无效、过期或已撤销（401）。
    case unauthorized(String)

    /// 令牌缺少权限范围，或账号对这个项目没有权限（403）。
    case forbidden(String)

    /// 超过速率限制；带上限制解除的时间，服务端没有给出时为 nil。
    case rateLimited(reset: Date?, message: String)

    /// 项目或对象不存在，或当前账号看不到它（404）。
    case notFound(String)

    /// 服务端拒绝了请求，如参数不合法、合并条件不满足或状态冲突。
    case rejected(status: Int, message: String)

    /// 服务端出错（5xx）。
    case server(status: Int, message: String)

    /// 连不上实例：找不到主机、连接被拒、超时或离线。
    case unreachable(String)

    /// 实例的证书不受信任。
    case untrustedCertificate(String)

    /// 实例的 API 与 Spooky 不兼容：版本过低，或响应不是预期的格式。
    case incompatible(String)

    /// 浏览器授权的验证码已过期，需要重新开始。
    case authorizationExpired

    /// 用户在浏览器里拒绝了授权。
    case authorizationDenied

    /// 令牌属于另一个用户，重新认证时不能替换成它。
    case differentUser(String)
}
