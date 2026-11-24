import Foundation
import Security
import Synchronization

// MARK: - KeychainError

/// 钥匙串没有存下条目。
enum KeychainError: Error, Equatable {
    /// 服务名或账户名带控制字符，或条目写成的命令超出 `security` 一行的上限。
    case unsupportedItem

    /// `security` 以这个非零的退出码结束。
    case exit(Int32)
}

// MARK: - SecurityKeychain

/// 钥匙串里按服务名与账户名存取的密码条目，经系统的 `security` 命令读写。
///
/// 钥匙串只让创建条目的程序不经确认地读它，按代码签名辨认；Spooky 的签名每个版本都不同，
/// 条目由 `security` 创建与读取，换了版本也不用再输钥匙串密码。
///
/// - 内容存成 UTF-8 的 Base64：`security` 读出带非 ASCII 字符的内容时会改写成十六进制
/// - 存下的条目带创建者代码 ``creator``；没有它的是旧版本在本进程里存的条目，读到时重新存一遍
/// - 读过的条目留在内存里，之后的读取不再启动进程
final class SecurityKeychain: Sendable {
    /// App 共用的钥匙串：条目在默认钥匙串里。
    static let shared = SecurityKeychain()

    /// 条目所在钥匙串文件的路径；nil 表示默认钥匙串。
    private let keychain: String?

    /// 读过与存过的条目，值为 nil 的是确认过不存在的条目。
    private let cache = Mutex<[Entry: String?]>([:])

    /// 创建钥匙串。
    ///
    /// - Parameter keychain: 条目所在钥匙串文件的路径，测试传入临时钥匙串；nil 表示默认钥匙串。
    init(keychain: String? = nil) {
        self.keychain = keychain
    }

    /// 读出条目的内容；没有这个条目或读不出时为 nil。
    ///
    /// - Parameters:
    ///   - service: 服务名。
    ///   - account: 账户名。
    func password(service: String, account: String) -> String? {
        let entry = Entry(service: service, account: account)

        if let cached = cache.withLock({ $0[entry] }) {
            return cached
        }

        // 先只读属性：不碰内容，钥匙串对哪个程序都不询问
        let found = run(["find-generic-password", "-s", service, "-a", account] + location)

        guard found.status == 0 else {
            if found.status == Self.notFoundStatus {
                cache.withLock { $0[entry] = .some(nil) }
            }

            return nil
        }

        guard Self.items(in: found.output).first?.isManaged ?? false else {
            return migratedPassword(of: entry)
        }

        let read = run(["find-generic-password", "-s", service, "-a", account, "-w"] + location)
        let encoded = String(decoding: read.output, as: UTF8.self).trimmingCharacters(in: .newlines)

        guard
            read.status == 0,
            let data = Data(base64Encoded: encoded),
            let password = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        cache.withLock { $0[entry] = password }
        return password
    }

    /// 存下条目；同一服务名与账户名已有条目时换掉它。
    ///
    /// - Parameters:
    ///   - password: 条目的内容。
    ///   - service: 服务名。
    ///   - account: 账户名。
    func setPassword(_ password: String, service: String, account: String) throws {
        // 命令逐行读取：名称里的换行会被当成下一条命令
        guard !(service + account).unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else {
            throw KeychainError.unsupportedItem
        }

        let target = "-s " + Self.quoted(service) + " -a " + Self.quoted(account)
        let destination = keychain.map { " " + Self.quoted($0) } ?? ""
        let encoded = Data(password.utf8).base64EncodedString()

        // 已有的条目先删掉再新建：旧版本存的条目不信任 `security`，原地修改会让系统询问钥匙串密码
        let delete = "delete-generic-password " + target + destination
        let add = "add-generic-password " + target + " -c " + Self.creator + " -w " + Self.quoted(encoded) + destination

        // 超出上限的一行会被截成两条命令
        guard add.utf8.count <= Self.maximumLineLength else {
            throw KeychainError.unsupportedItem
        }

        let entry = Entry(service: service, account: account)

        // 内容经标准输入送进去，不出现在进程参数里；退出码是最后一条命令的结果
        let written = run(["-i"], input: delete + "\n" + add + "\n")

        guard written.status == 0 else {
            cache.withLock { $0[entry] = nil }
            throw KeychainError.exit(written.status)
        }

        cache.withLock { $0[entry] = password }
    }

    /// 删除条目；没有这个条目时什么都不做。
    ///
    /// - Parameters:
    ///   - service: 服务名。
    ///   - account: 账户名。
    func removePassword(service: String, account: String) {
        let entry = Entry(service: service, account: account)
        let deleted = run(["delete-generic-password", "-s", service, "-a", account] + location)

        cache.withLock {
            if deleted.status == 0 || deleted.status == Self.notFoundStatus {
                $0[entry] = .some(nil)
            } else {
                $0[entry] = nil
            }
        }
    }

    /// 把一个服务名下的全部条目换到另一个服务名下，账户名不变。
    ///
    /// - Parameters:
    ///   - source: 条目现在的服务名。
    ///   - destination: 换到的服务名。
    func moveItems(fromService source: String, toService destination: String) {
        let listed = run(["dump-keychain"] + location)

        guard listed.status == 0 else {
            return
        }

        for item in Self.items(in: listed.output) where item.service == source {
            guard
                let account = item.account,
                let password = password(service: source, account: account)
            else { continue }

            // 新服务名下存好了才删原来的条目
            guard (try? setPassword(password, service: destination, account: account)) != nil else {
                continue
            }

            removePassword(service: source, account: account)
        }
    }
}

// MARK: - Private

extension SecurityKeychain {
    /// 一个条目的服务名与账户名。
    private struct Entry: Hashable {
        /// 服务名。
        let service: String

        /// 账户名。
        let account: String
    }

    /// `security` 列出的一个条目的属性。
    private struct Item {
        /// 服务名。
        var service: String? = nil

        /// 账户名。
        var account: String? = nil

        /// 是否带创建者代码 ``creator``。
        var isManaged = false
    }

    /// `security` 存下的条目带的创建者代码，四个字符。
    private static let creator = "spky"

    /// `security` 找不到条目时的退出码：`errSecItemNotFound` 的低 8 位。
    private static let notFoundStatus: Int32 = 44

    /// `security` 从标准输入读命令时，一行最多的字节数。
    private static let maximumLineLength = 4096

    /// 命令末尾指明钥匙串的参数；默认钥匙串不用写。
    private var location: [String] {
        keychain.map { [$0] } ?? []
    }

    /// 旧版本在本进程里存的条目：读出内容，再由 `security` 重新存一遍。
    ///
    /// 这种条目只在默认钥匙串里；Spooky 更新过时，系统会询问一次钥匙串密码。
    private func migratedPassword(of entry: Entry) -> String? {
        guard keychain == nil else {
            return nil
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: entry.service,
            kSecAttrAccount as String: entry.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var value: CFTypeRef? = nil

        guard
            SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess,
            let data = value as? Data,
            let password = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        // 重新存不成时条目保持原样，下次读取再试；这一次照常交回内容
        try? setPassword(password, service: entry.service, account: entry.account)

        cache.withLock { $0[entry] = password }
        return password
    }

    /// 执行一次 `security`，等它退出。
    ///
    /// - Parameters:
    ///   - arguments: 进程参数。
    ///   - input: 送进标准输入的命令；没有时标准输入为空。
    /// - Returns: 退出码与标准输出；启动不了时退出码为 -1。
    private func run(_ arguments: [String], input: String? = nil) -> (status: Int32, output: Data) {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/security")
        process.arguments = arguments
        process.standardError = FileHandle.nullDevice

        let output = Pipe()
        process.standardOutput = output

        if let input {
            // 启动前把命令写进管道并关掉写入端：命令远小于管道的缓冲区，进程提前退出时也没有写到一半的管道
            let pipe = Pipe()
            try? pipe.fileHandleForWriting.write(contentsOf: Data(input.utf8))
            try? pipe.fileHandleForWriting.close()
            process.standardInput = pipe
        } else {
            process.standardInput = FileHandle.nullDevice
        }

        // 不用 `waitUntilExit()` 等退出：它在主线程上会转动 run loop，别的主线程任务会插进这次读写中间
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            return (-1, Data())
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        exited.wait()

        return (process.terminationStatus, data)
    }

}

// MARK: - Helpers

extension SecurityKeychain {
    /// 读出 `find-generic-password` 与 `dump-keychain` 列出的条目：每个条目以 `keychain:` 一行开头，属性各占一行。
    private static func items(in output: Data) -> [Item] {
        var items: [Item] = []

        for line in String(decoding: output, as: UTF8.self).split(separator: "\n") {
            if line.hasPrefix("keychain: ") {
                items.append(Item())
                continue
            }

            guard !items.isEmpty, let separator = line.firstIndex(of: "=") else {
                continue
            }

            let value = line[line.index(after: separator)...]

            switch line[..<separator].trimmingCharacters(in: .whitespaces) {
            case "\"svce\"<blob>":
                items[items.count - 1].service = text(of: value)

            case "\"acct\"<blob>":
                items[items.count - 1].account = text(of: value)

            case "\"crtr\"<uint32>":
                items[items.count - 1].isManaged = value == "\"" + creator + "\""

            default:
                continue
            }
        }

        return items
    }

    /// 属性一行里的值：全是可打印字符的写成带引号的原文，其余写成 `0x` 开头的十六进制、后面跟转义过的写法；没有值时为 nil。
    private static func text(of value: Substring) -> String? {
        if value.hasPrefix("0x") {
            let digits = Array(value.dropFirst(2).prefix { $0.isHexDigit })

            let bytes = stride(from: 0, to: digits.count - 1, by: 2).compactMap {
                UInt8(String(digits[$0 ... $0 + 1]), radix: 16)
            }

            return String(bytes: bytes, encoding: .utf8)
        }

        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else {
            return nil
        }

        return String(value.dropFirst().dropLast())
    }

    /// 从标准输入读的命令里的一个参数：包进双引号，里面的反斜杠与双引号转义。
    private static func quoted(_ argument: String) -> String {
        "\"" + argument.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
