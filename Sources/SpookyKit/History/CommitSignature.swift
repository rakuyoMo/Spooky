import Foundation

// MARK: - SignatureStatus

/// 签名的校验结果，原始值是 Git `%G?` 的字母。
public enum SignatureStatus: String, Sendable, CaseIterable {
    /// 签名有效且密钥受信任。
    case good = "G"

    /// 签名与内容对不上。
    case bad = "B"

    /// 签名有效，但密钥的可信度未知，或 SSH 密钥不在 allowed signers 里。
    case unknownValidity = "U"

    /// 签名有效但已过期。
    case expiredSignature = "X"

    /// 签名有效但签名密钥已过期。
    case expiredKey = "Y"

    /// 签名有效但签名密钥已吊销。
    case revokedKey = "R"

    /// 带签名但无法校验，如缺少公钥、没有配置 allowed signers 或找不到签名程序。
    case cannotCheck = "E"

    /// 没有签名。
    case unsigned = "N"
}

// MARK: - CommitSignature

/// 提交或附注标签的签名：状态、签名者与密钥。
public struct CommitSignature: Sendable, Equatable {
    /// 与 ``parse(_:)`` 配套的 log 格式：哈希、状态、签名者、签名密钥与主密钥指纹，以 NUL 分隔。
    static let format = "--format=tformat:%H%x00%G?%x00%GS%x00%GK%x00%GP"

    /// 校验结果。
    public let status: SignatureStatus

    /// 签名者：OpenPGP 为密钥的用户 ID，SSH 为 allowed signers 里匹配到的身份；取不到时为空。
    public let signer: String

    /// 签名所用的密钥：OpenPGP 为密钥 ID，SSH 为密钥指纹。
    public let key: String

    /// OpenPGP 主密钥的指纹；SSH 签名为空。
    public let primaryFingerprint: String

    /// 签名者为 “姓名 <邮箱>” 时拆出的姓名；SSH 签名者只有一个身份，没有姓名。
    public var name: String? { identity?.name }

    /// 签名者为 “姓名 <邮箱>” 时拆出的邮箱。
    public var email: String? { identity?.email }

    /// 按最后一组尖括号拆开签名者。
    private var identity: (name: String, email: String)? {
        guard
            signer.hasSuffix(">"),
            let open = signer.range(of: " <", options: .backwards)
        else { return nil }

        let name = signer[..<open.lowerBound].trimmingCharacters(in: .whitespaces)
        let email = signer[open.upperBound...].dropLast()

        guard !name.isEmpty, !email.isEmpty else {
            return nil
        }

        return (name, String(email))
    }

    /// 创建一份签名记录。
    public init(status: SignatureStatus, signer: String = "", key: String = "", primaryFingerprint: String = "") {
        self.status = status
        self.signer = signer
        self.key = key
        self.primaryFingerprint = primaryFingerprint
    }

    /// 解析 ``format`` 的输出，每个提交五个 NUL 字段。
    static func parse(_ data: Data) throws -> [String: Self] {
        guard !data.isEmpty else {
            return [:]
        }

        guard data.last == 0 else {
            throw RepositoryReadError.malformedOutput("signature")
        }

        let fields = data.dropLast()
            .split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }

        guard fields.count.isMultiple(of: 5) else {
            throw RepositoryReadError.malformedOutput("signature")
        }

        var signatures: [String: Self] = [:]

        for start in stride(from: 0, to: fields.count, by: 5) {
            guard
                GitObjectID.isValid(fields[start]),
                let status = SignatureStatus(rawValue: fields[start + 1])
            else { throw RepositoryReadError.malformedOutput("signature") }

            signatures[fields[start]] = Self(
                status: status,
                signer: fields[start + 2],
                key: fields[start + 3],
                primaryFingerprint: fields[start + 4]
            )
        }

        return signatures
    }
}

// MARK: - Commit Signatures

extension RepositoryHistory {
    /// 校验一组提交的签名；校验结果随密钥环与 allowed signers 变化，不按哈希复用。
    ///
    /// SSH 签名在没有配置 allowed signers 时，Git 报告为没有签名；提交对象带签名头时改为无法校验。
    public func signatures(of commits: [String]) async throws -> [String: CommitSignature] {
        guard commits.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }

        guard !commits.isEmpty else {
            return [:]
        }

        let input = Data((commits.joined(separator: "\n") + "\n").utf8)

        // 只列出给定的提交，不沿历史展开
        let output = try await SignatureVerification.run(on: runner) { options in
            try await runner.run(
                options + Self.logOptions + [
                    "log", "--no-walk=unsorted", "--no-color", "--no-patch", "-z", CommitSignature.format,
                    "--stdin", "--",
                ],
                input: input
            )
        }

        var signatures = try CommitSignature.parse(output)
        let unsigned = commits.filter { signatures[$0]?.status == SignatureStatus.unsigned }

        for commit in try await signedObjects(unsigned) {
            signatures[commit] = CommitSignature(status: .cannotCheck)
        }

        return signatures
    }

    /// 对象里带 `gpgsig` 或 `gpgsig-sha256` 头的提交；提交对象只由哈希决定，按哈希复用。
    private func signedObjects(_ commits: [String]) async throws -> [String] {
        guard !commits.isEmpty else {
            return []
        }

        let output = try await runner.immutableRun(
            ["cat-file", "--batch"],
            input: Data((commits.joined(separator: "\n") + "\n").utf8)
        )

        return try CommitObjects.parse(output)
            .filter { CommitObjects.hasSignature($0.content) }
            .map(\.id)
    }
}
