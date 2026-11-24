import Foundation
import Testing

@testable import Spooky

// MARK: - SecurityKeychainTests

/// 钥匙串条目经 `security` 读写：令牌与保存的凭据靠它在 Spooky 更新后照常读出，存错、读错或换错服务名都会让账号失效。
struct SecurityKeychainTests {
    /// 服务名、账户名与内容里的空格、引号、反斜杠、换行与非 ASCII 字符原样存取，内容不因 `security` 的输出格式走样；
    /// 同一条目再存是替换。没有创建者代码的条目是别的程序存的，`security` 不去读它的内容，再存时换掉它。
    /// 名称带换行或命令超出一行上限时不存，原有的内容不变。换服务名只动这个服务名下的条目。
    @Test("存取、替换与删除条目，换服务名")
    func storesItems() throws {
        let temporary = try TemporaryKeychain()
        defer { temporary.remove() }

        let keychain = SecurityKeychain(keychain: temporary.path)
        let service = "com.rakuyo.spooky.tests.https://git.example.com/a b/"
        let account = "账号 “a” \\ \"b\" it's"
        let password = "{\"token\":\"口令 \\\\ \\\"x\\\"\"}\n第二行"

        /// 不经缓存，由另一个实例读钥匙串里实际存下的内容。
        func stored(_ service: String, _ account: String) -> String? {
            SecurityKeychain(keychain: temporary.path).password(service: service, account: account)
        }

        // 没有条目时读不出，删除也不出错
        #expect(keychain.password(service: service, account: account) == nil)
        keychain.removePassword(service: service, account: account)

        // 存取：特殊字符原样读回
        try keychain.setPassword(password, service: service, account: account)

        #expect(keychain.password(service: service, account: account) == password)
        #expect(stored(service, account) == password)

        // 再存是替换，别的账户名不受影响
        try keychain.setPassword("first", service: service, account: "other")
        try keychain.setPassword("renewed", service: service, account: account)

        #expect(stored(service, account) == "renewed")
        #expect(stored(service, "other") == "first")

        // 不能存的条目：名称带换行，或命令超出一行的上限；原有的内容不变
        #expect(throws: KeychainError.unsupportedItem) {
            try keychain.setPassword("x", service: service, account: "a\nb")
        }

        #expect(throws: KeychainError.unsupportedItem) {
            try keychain.setPassword(String(repeating: "x", count: 4096), service: service, account: account)
        }

        #expect(keychain.password(service: service, account: account) == "renewed")
        #expect(stored(service, account) == "renewed")

        // 没有创建者代码的条目：内容不经 `security` 读，再存时换掉
        try temporary.run(["add-generic-password", "-s", service, "-a", "foreign", "-w", "raw", temporary.path])

        #expect(keychain.password(service: service, account: "foreign") == nil)

        try keychain.setPassword("replaced", service: service, account: "foreign")

        #expect(stored(service, "foreign") == "replaced")

        // 删除：只删这一个条目
        keychain.removePassword(service: service, account: "foreign")

        #expect(keychain.password(service: service, account: "foreign") == nil)
        #expect(stored(service, "foreign") == nil)
        #expect(stored(service, "other") == "first")

        // 换服务名：这个服务名下的条目都换过去，账户名不变；别的服务名下的不动
        let renamed = "com.rakuyo.spooky.tests.服务器 “b”"
        let unrelated = service + "c"

        try keychain.setPassword("kept", service: unrelated, account: "other")
        keychain.moveItems(fromService: service, toService: renamed)

        #expect(stored(renamed, account) == "renewed")
        #expect(stored(renamed, "other") == "first")
        #expect(stored(service, account) == nil)
        #expect(stored(service, "other") == nil)
        #expect(keychain.password(service: service, account: account) == nil)
        #expect(stored(unrelated, "other") == "kept")

        // 服务名带非 ASCII 字符时照样认得出，能再换回去
        keychain.moveItems(fromService: renamed, toService: service)

        #expect(stored(service, account) == "renewed")
        #expect(stored(renamed, account) == nil)
    }
}

// MARK: - TemporaryKeychain

/// 测试用的临时钥匙串：建在临时目录里，不进用户的钥匙串搜索列表。
struct TemporaryKeychain {
    /// 钥匙串所在的临时目录。
    private let directory: URL

    /// 钥匙串文件的路径。
    var path: String {
        directory.appending(path: "test.keychain-db").path
    }

    /// 建一个解锁的空钥匙串。
    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.keychain." + UUID().uuidString)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try run(["create-keychain", "-p", "", path])
    }

    /// 执行一次 `security`；以非零的退出码结束时抛出错误。
    func run(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/security")
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        // 等退出不转动 run loop：主线程上别的测试不会插进来
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        try process.run()
        exited.wait()

        guard process.terminationStatus == 0 else {
            throw KeychainError.exit(process.terminationStatus)
        }
    }

    /// 删掉钥匙串与它所在的目录。
    func remove() {
        try? run(["delete-keychain", path])
        try? FileManager.default.removeItem(at: directory)
    }
}
