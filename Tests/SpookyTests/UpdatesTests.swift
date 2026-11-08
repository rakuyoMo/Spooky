import Foundation
import Testing

@testable import Spooky

// MARK: - UpdatesTests

/// 更新通道的偏好与更新失败的提示：通道按记录读取，更新失败时要看得到原始的网络错误。
struct UpdatesTests {
    /// 没有记录或记录无法识别时按稳定通道检查，选过的通道读回原值。
    @Test("更新通道的读取")
    func channelPreference() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.updates." + UUID().uuidString)

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))

        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(UpdateChannel.current(in: defaults) == .stable)

        // 无法识别的记录按稳定通道检查
        defaults.set("nightly", forKey: UpdateChannel.key)
        #expect(UpdateChannel.current(in: defaults) == .stable)

        defaults.set("development", forKey: UpdateChannel.key)
        #expect(UpdateChannel.current(in: defaults) == .development)
    }

    /// 更新失败的提示框把原始的网络错误显示为说明文字，错误的域与代码不变；
    /// 已有恢复建议或没有原始错误时，提示框照原样显示。
    @Test("更新失败时显示原始错误")
    func revealsUnderlyingError() {
        let network = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )

        let error = NSError(
            domain: "SUSparkleErrorDomain",
            code: 2001,
            userInfo: [
                NSLocalizedDescriptionKey: "An error occurred in retrieving update information.",
                NSUnderlyingErrorKey: network,
            ]
        )

        let revealed = UpdateUserDriver.revealingUnderlyingError(error) as NSError

        #expect(revealed.domain == "SUSparkleErrorDomain")
        #expect(revealed.code == 2001)
        #expect(revealed.localizedDescription == "An error occurred in retrieving update information.")
        #expect(revealed.localizedRecoverySuggestion == "The Internet connection appears to be offline.")

        // 已有恢复建议时照样保留，没有原始错误时不加说明
        let suggested = NSError(
            domain: "SUSparkleErrorDomain",
            code: 4,
            userInfo: [
                NSLocalizedRecoverySuggestionErrorKey: "Try again later.",
                NSUnderlyingErrorKey: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut),
            ]
        )

        let plain = NSError(domain: "SUSparkleErrorDomain", code: 1001)

        let keptSuggestion = UpdateUserDriver.revealingUnderlyingError(suggested) as NSError
        let keptPlain = UpdateUserDriver.revealingUnderlyingError(plain) as NSError

        #expect(keptSuggestion.localizedRecoverySuggestion == "Try again later.")
        #expect(keptPlain.localizedRecoverySuggestion == nil)
    }
}
