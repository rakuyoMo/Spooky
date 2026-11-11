import Foundation

// MARK: - MemoryDefaults

/// 只存在内存里的偏好，注入给按 `UserDefaults` 读写的类型。
///
/// 临时目录下的路径偏好域在系统重读各个来源之后，先读到的是重读时盘上的值：之后覆盖或删除的键，读回的仍是旧值。
/// 测试要覆盖或删除偏好再读回时用它；按键读写，以及按 `name` 读、写、删整个域，都只作用于内存里的这一份。
public final class MemoryDefaults: UserDefaults {
    /// 偏好域的名字，交给按域名读写的接口。
    public let name: String

    /// 保护 `values` 的锁：与系统的偏好一样，可以在任意线程读写。
    private let lock = NSLock()

    /// 域里的键值，只在 `lock` 内读写。
    private nonisolated(unsafe) var values: [String: Any] = [:]

    /// 建一个空的偏好域，名字每次都不同。
    public init() {
        let name = "com.rakuyo.spooky.tests.memory." + UUID().uuidString
        self.name = name

        // 只有名字是 App 自己的 Bundle ID 或全局域时才建不出来
        // swiftlint:disable:next force_unwrapping
        super.init(suiteName: name)!
    }

    /// 读一个键；各类型的读取都经过这里。
    /// - Parameter defaultName: 键名
    override public func object(forKey defaultName: String) -> Any? {
        lock.withLock { values[defaultName] }
    }

    /// 写一个键，nil 表示删除；各类型的写入都经过这里。
    /// - Parameters:
    ///   - value: 要写的值
    ///   - defaultName: 键名
    override public func set(
        _ value: Any?,
        forKey defaultName: String
    ) {
        lock.withLock { values[defaultName] = value }
    }

    /// 删除一个键。
    /// - Parameter defaultName: 键名
    override public func removeObject(forKey defaultName: String) {
        lock.withLock { values[defaultName] = nil }
    }

    /// 读整个域；名字不是 `name` 时交给系统。
    /// - Parameter domainName: 偏好域的名字
    override public func persistentDomain(forName domainName: String) -> [String: Any]? {
        guard domainName == name else {
            return super.persistentDomain(forName: domainName)
        }

        return lock.withLock { values }
    }

    /// 整个替换域里的键值；名字不是 `name` 时交给系统。
    /// - Parameters:
    ///   - domain: 新的键值
    ///   - domainName: 偏好域的名字
    override public func setPersistentDomain(
        _ domain: [String: Any],
        forName domainName: String
    ) {
        guard domainName == name else {
            super.setPersistentDomain(domain, forName: domainName)

            return
        }

        lock.withLock { values = domain }
    }

    /// 删掉整个域；名字不是 `name` 时交给系统。
    /// - Parameter domainName: 偏好域的名字
    override public func removePersistentDomain(forName domainName: String) {
        guard domainName == name else {
            super.removePersistentDomain(forName: domainName)

            return
        }

        lock.withLock { values = [:] }
    }
}
