import Foundation

// MARK: - Repository Identity

extension WorkingCopyOperations {
    /// 删除仓库本地配置里的提交人姓名与邮箱，此后提交改用全局或系统配置的身份。
    ///
    /// 签名配置不变；两项本来就没有时什么也不做。
    public func clearIdentity() async throws {
        // 两项在同一仓库写锁中依次删除；键不存在时 Git 以 5 退出，按已删除处理。
        try await runner.writeTransaction {
            for key in ["user.name", "user.email"] {
                _ = try await runner.execute(["config", "--local", "--unset-all", key], acceptedExitCodes: [0, 5])
            }
        }
    }
}
