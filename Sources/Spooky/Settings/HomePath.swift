import Foundation

// MARK: - HomePath

/// 用户主目录与 `~` 的互换：设置里显示路径时缩写，解析配置里的路径时展开。
enum HomePath {
    /// 把用户主目录缩写成 `~`。
    ///
    /// - Parameters:
    ///   - path: 绝对路径。
    ///   - home: 用户主目录。
    static func abbreviated(_ path: String, home: String = NSHomeDirectory()) -> String {
        path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }

    /// 展开开头的 `~` 或 `~/`；其它写法原样返回。
    ///
    /// - Parameters:
    ///   - path: 配置里的路径。
    ///   - home: 用户主目录。
    static func expanded(_ path: String, home: String = NSHomeDirectory()) -> String {
        path == "~" || path.hasPrefix("~/") ? home + path.dropFirst() : path
    }
}
