import Foundation

// MARK: - ConfigEntry

/// Git 配置里的一项，按配置文件中的顺序保存；撤销时据此原样写回。
public struct ConfigEntry: Sendable, Equatable {
    /// 完整的键，节名与变量名是 Git 输出的小写形式，如 `remote.origin.url`。
    let key: String

    /// 配置值；只写键不写值时为 nil。
    let value: String?

    /// 解析 `config -z --get-regexp` 的输出，保留输出顺序与重复的键。
    ///
    /// 每条记录是 “键、换行、值、NUL”，没有值的键只有 “键、NUL”。
    static func parse(_ data: Data) -> [Self] {
        data.split(separator: 0).map { record in
            Self(
                key: String(decoding: record.prefix { $0 != 10 }, as: UTF8.self),
                value: record.firstIndex(of: 10).map { String(decoding: record[($0 + 1)...], as: UTF8.self) }
            )
        }
    }
}
