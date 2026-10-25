import Foundation

// MARK: - ConfigRecords

/// `config -z --get-regexp` 输出的解析与 Git 写法的取值换算，提交配置与全局配置共用。
enum ConfigRecords {
    /// 解析记录；同一键出现多次时与 Git 一样以最后一个为准。
    ///
    /// 每条记录是 “键、换行、值、NUL”，没有值的布尔键只有 “键、NUL”，此时值为 nil。
    ///
    /// - Parameters:
    ///   - data: 命令的标准输出。
    ///   - pattern: 查询用的键名正则；出现别的键说明输出已错位。
    ///   - context: 解析失败时写进错误的读取名称。
    static func parse(_ data: Data, pattern: String, context: String) throws -> [String: String?] {
        guard data.isEmpty || data.last == 0 else {
            throw RepositoryReadError.malformedOutput(context)
        }

        var values: [String: String?] = [:]

        for record in data.split(separator: 0, omittingEmptySubsequences: false).dropLast() {
            let text = String(decoding: record, as: UTF8.self)
            let parts = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(parts[0])

            guard key.range(of: pattern, options: .regularExpression) != nil else {
                throw RepositoryReadError.malformedOutput(context)
            }

            values.updateValue(parts.count > 1 ? String(parts[1]) : nil, forKey: key)
        }

        return values
    }

    /// 空字符串与缺失同样表示未配置。
    static func nonEmpty(_ value: String??) -> String? {
        guard let value = value ?? nil, !value.isEmpty else {
            return nil
        }

        return value
    }

    /// 按 Git 的布尔写法解析；没有值的键表示 true，数字按是否非零判断。
    static func boolean(_ value: String?) -> Bool {
        guard let value else {
            return true
        }

        switch value.lowercased() {
        case "true", "yes", "on": return true
        case "false", "no", "off", "": return false
        default: return (Int(value) ?? 0) != 0
        }
    }
}
