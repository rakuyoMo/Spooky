import Foundation
import SpookyKit

// MARK: - Hosting

extension AppFailure {
    /// 托管服务失败的文案键、类别、恢复说明与原文；原文是服务端返回的说明，速率限制另写出解除的时间。
    static func classification(
        of hosting: HostingError
    ) -> (key: String, kind: FailureKind, recoveryKey: String, output: GitCommandResult?, diagnostic: String?) {
        switch hosting {
        case .unauthorized(let message):
            ("hosting.error.unauthorized", .environment, "hosting.error.unauthorized.help", nil, message)

        case .forbidden(let message):
            ("hosting.error.forbidden", .environment, "hosting.error.forbidden.help", nil, message)

        case .rateLimited(let reset, let message):
            (
                "hosting.error.rateLimited",
                .environment,
                "hosting.error.rateLimited.help",
                nil,
                [message, reset.map { AppLocalization.text("hosting.error.rateLimited.reset", $0.formatted()) }]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            )

        case .notFound(let message):
            ("hosting.error.notFound", .repository, "hosting.error.notFound.help", nil, message)

        case .rejected(let status, let message):
            ("hosting.error.rejected", .repository, "hosting.error.rejected.help", nil, "HTTP \(status)\n" + message)

        case .server(let status, let message):
            ("hosting.error.server", .environment, "hosting.error.server.help", nil, "HTTP \(status)\n" + message)

        case .unreachable(let message):
            ("hosting.error.unreachable", .connection, "hosting.error.unreachable.help", nil, message)

        case .untrustedCertificate(let message):
            ("hosting.error.certificate", .connection, "hosting.error.certificate.help", nil, message)

        case .incompatible(let message):
            ("hosting.error.incompatible", .version, "hosting.error.incompatible.help", nil, message)

        case .authorizationExpired:
            ("hosting.error.expired", .cancelled, "hosting.error.expired.help", nil, nil)

        case .authorizationDenied:
            ("hosting.error.denied", .cancelled, "hosting.error.denied.help", nil, nil)

        case .differentUser(let username):
            ("hosting.error.differentUser", .repository, "hosting.error.differentUser.help", nil, username)
        }
    }

    /// 钥匙串拒绝保存令牌：原文是钥匙串对状态码的说明。
    static func classification(
        of account: HostingAccountError
    ) -> (key: String, kind: FailureKind, recoveryKey: String, output: GitCommandResult?, diagnostic: String?) {
        switch account {
        case .keychain(let status):
            (
                "hosting.error.keychain",
                .environment,
                "hosting.error.keychain.help",
                nil,
                (SecCopyErrorMessageString(status, nil) as String?) ?? "OSStatus \(status)"
            )
        }
    }
}
