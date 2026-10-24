import Foundation

// MARK: - RepositoryReferences

extension RepositoryReferences {
    /// 检出标签所指的提交，HEAD 成为分离状态；只接受完整的标签引用名，`--` 阻止名字被当成选项。
    public func checkoutTag(_ reference: String) async throws {
        guard reference.hasPrefix("refs/tags/"), reference.count > "refs/tags/".count else {
            throw RepositoryReadError.invalidQuery
        }

        _ = try await runner.run(["switch", "--detach", "--", reference])
    }
}
