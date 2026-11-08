import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// Diff 上下文行数的偏好：菜单与底栏都按它取当前的档位。
@MainActor
struct DiffMenuTests {
    /// 偏好里没有记录或记录了不在档位中的值时，按默认的 3 行处理。
    @Test("上下文行数偏好的取值")
    func contextPreference() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-context-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let key = DiffPreferences.contextLinesKey

        #expect(DiffPreferences.options(defaults: defaults).contextLines == DiffOptions.defaultContextLines)

        defaults.set(7, forKey: key)
        #expect(DiffPreferences.options(defaults: defaults).contextLines == 7)

        // 不在档位中的值写进另一个偏好域：覆盖已有的值后立即读取，可能仍读到旧值
        let invalid = try #require(UserDefaults(suiteName: directory.appending(path: "invalid").path))
        invalid.set(11, forKey: key)

        #expect(DiffPreferences.options(defaults: invalid).contextLines == DiffOptions.defaultContextLines)

        defaults.set(true, forKey: DiffPreferences.ignoresWhitespaceKey)
        let options = DiffPreferences.options(showsEntireFile: true, defaults: defaults)

        #expect(options.ignoresWhitespace)
        #expect(options.showsEntireFile)
    }
}
