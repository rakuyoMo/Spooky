import Foundation

// MARK: - Global Identity

extension WorkingCopyOperations {
    /// 把身份写进仓库所在机器上当前用户的全局 Git 配置；没有自己身份的仓库都用它提交。
    ///
    /// - Parameters:
    ///   - name: 写入 `user.name` 的姓名。
    ///   - email: 写入 `user.email` 的邮箱。
    public func applyGlobalIdentity(name: String, email: String) async throws {
        // 两项在同一写锁中依次写入，值经独立参数传递，以短横线开头也不会被当作选项
        try await runner.writeTransaction {
            for (key, value) in [("user.name", name), ("user.email", email)] {
                _ = try await runner.run(["config", "--global", "--replace-all", "--", key, value])
            }
        }
    }
}
