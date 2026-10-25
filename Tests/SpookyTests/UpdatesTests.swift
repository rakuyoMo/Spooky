import Foundation
import Testing

@testable import Spooky

// MARK: - UpdatesTests

/// 更新通道与更新失败的提示：通道决定还接收清单里哪些带通道的条目，更新失败时要看得到原始的网络错误。
struct UpdatesTests {
    /// 没有记录或记录无法识别时按稳定通道检查，选过的通道读回原值；每个值写进各自的偏好域。
    @Test(
        "更新通道的读写",
        arguments: [
            (nil, UpdateChannel.stable),
            ("beta", .beta),
            ("development", .development),
            ("nightly", .stable),
        ] as [(String?, UpdateChannel)]
    )
    func channelPreference(stored: String?, expected: UpdateChannel) throws {
        let domain = "com.rakuyo.spooky.tests.updates." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }

        if let stored {
            defaults.set(stored, forKey: UpdateChannel.key)
        }

        #expect(UpdateChannel.current(in: defaults) == expected)
    }

    /// 稳定通道只收不带通道的条目；测试通道另收 beta，开发通道再收 development。
    @Test("通道接收的条目")
    func allowedChannels() {
        #expect(UpdateChannel.stable.allowedChannels.isEmpty)
        #expect(UpdateChannel.beta.allowedChannels == ["beta"])
        #expect(UpdateChannel.development.allowedChannels == ["beta", "development"])
    }

    /// 更新失败的提示框把原始的网络错误显示为说明文字；错误的域与代码不变。
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
    }

    /// 已有恢复建议或没有原始错误时，提示框照原样显示。
    @Test("已有说明或没有原始错误时不改动")
    func keepsErrorWithoutUnderlyingCause() {
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
