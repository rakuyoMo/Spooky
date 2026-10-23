import Foundation

// MARK: - StashEntry

/// 储藏列表中的一条记录；序号随列表增减而变化，哈希唯一确定储藏的内容。
public struct StashEntry: Sendable, Equatable, Identifiable {
    /// `stash@{N}` 中的 N，从 0 开始，取自 Git 的引用日志选择器。
    public let index: Int

    /// 储藏提交的完整哈希，长度由仓库的哈希算法决定。
    public let id: String

    /// 储藏提交的父提交：基准提交、暂存区，带未跟踪文件保存时还有第三个。
    public let parents: [String]

    /// 创建储藏的时间，取提交人日期。
    public let date: Date

    /// 储藏提交信息的标题行，如 `On main: 说明` 或 `WIP on main: abc1234 标题`。
    public let subject: String

    /// 按序号操作储藏时交给 Git 的引用。
    public var reference: String { "stash@{\(index)}" }

    /// 保存储藏时 HEAD 所在的提交。
    public var base: String { parents[0] }

    /// 带未跟踪文件保存时，记录这些文件的根提交。
    public var untrackedCommit: String? { parents.count > 2 ? parents[2] : nil }

    /// 保存储藏时所在的分支；分离 HEAD 时为 Git 写下的 `(no branch)`，无法识别的标题为 nil。
    public var branch: String? { Self.split(subject)?.branch }

    /// 用户写下的说明；Git 自动生成的 `WIP on …` 标题没有说明。
    public var message: String? {
        guard let parts = Self.split(subject) else {
            return subject.isEmpty ? nil : subject
        }

        return parts.isGenerated || parts.rest.isEmpty ? nil : parts.rest
    }

    /// 解析 `stash list -z --format=tformat:%gd%x00%H%x00%P%x00%ct%x00%s` 的输出。
    ///
    /// 每条记录 5 个字段，字段与记录都以 NUL 结束；任何一条不符合格式都拒绝整份列表，避免序号与哈希错位。
    static func parse(_ data: Data) throws -> [Self] {
        guard !data.isEmpty else { return [] }
        guard data.last == 0 else { throw RepositoryReadError.malformedOutput("stash list") }

        let fields = data.dropLast().split(separator: 0, omittingEmptySubsequences: false)
        guard fields.count.isMultiple(of: 5) else { throw RepositoryReadError.malformedOutput("stash list") }

        return try stride(from: 0, to: fields.count, by: 5)
            .map { start in
                let values = fields[start ..< (start + 5)].map { String(decoding: $0, as: UTF8.self) }
                let parents = values[2].split(separator: " ").map(String.init)

                // 储藏提交至少有基准提交与暂存区两个父提交，序号只接受 stash@{N} 的形式
                guard
                    let index = Self.index(in: values[0]),
                    GitObjectID.isValid(values[1]),
                    parents.count >= 2, parents.allSatisfy(GitObjectID.isValid),
                    let time = Int64(values[3])
                else { throw RepositoryReadError.malformedOutput("stash list") }

                return Self(
                    index: index,
                    id: values[1],
                    parents: parents,
                    date: Date(timeIntervalSince1970: Double(time)),
                    subject: values[4]
                )
            }
    }
}

// MARK: - Private

extension StashEntry {
    /// 从 `stash@{N}` 中取出 N；日期形式或其它引用返回 nil。
    private static func index(in selector: String) -> Int? {
        guard selector.hasPrefix("stash@{"), selector.hasSuffix("}") else {
            return nil
        }

        let digits = selector.dropFirst(7).dropLast()
        guard !digits.isEmpty, digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber) else {
            return nil
        }

        return Int(digits)
    }

    /// 拆开 Git 生成的 `WIP on <分支>: …` 与 `On <分支>: <说明>`；分支名不能含冒号，第一个 `: ` 就是分界。
    private static func split(_ subject: String) -> (branch: String, rest: String, isGenerated: Bool)? {
        let generated = subject.hasPrefix("WIP on ")
        let prefix = generated ? "WIP on " : "On "

        guard subject.hasPrefix(prefix) else {
            return nil
        }

        let remainder = subject.dropFirst(prefix.count)
        guard let separator = remainder.range(of: ": ") else {
            return nil
        }

        return (
            String(remainder[..<separator.lowerBound]),
            String(remainder[separator.upperBound...]),
            generated
        )
    }
}
