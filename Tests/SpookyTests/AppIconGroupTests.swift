import AppKit
import Testing

@testable import Spooky

// MARK: - AppIconGroupTests

/// 图标组与仓库里的图标资源、包的默认图标、打包脚本写出的壳 App 相互对得上。
@MainActor
struct AppIconGroupTests {
    /// 默认的一组是服务器幽灵，包里的默认图标（`CFBundleIconFile`）是它的默认图标；每组的四份 icns 都在仓库里，
    /// 其它组都要写自定义图标，打包脚本给它们各写一个壳 App。
    @Test("默认的一组是服务器幽灵；每组的图标资源齐全，其它组各有壳 App")
    func groupsMatchBundledResources() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let infoData = try Data(
            contentsOf: root.appending(path: "Sources/Spooky/Info.plist", directoryHint: .notDirectory)
        )

        let info = try #require(
            PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any]
        )

        let shells = try String(
            contentsOf: root.appending(path: "scripts/make-icon-shells.sh", directoryHint: .notDirectory),
            encoding: .utf8
        )

        let shellNames = AppIconGroup.allCases
            .filter { $0 != .defaultGroup }
            .map { $0.iconName(for: .standard) }

        let appearance = try #require(NSAppearance(named: .aqua))

        #expect(AppIconGroup.defaultGroup == .serverGhost)
        #expect(info["CFBundleIconFile"] as? String == AppIconGroup.defaultGroup.iconName(for: .standard))
        #expect(shells.contains("icon_names=(" + shellNames.joined(separator: " ") + ")"))

        for group in AppIconGroup.allCases {
            for isDark in [false, true] {
                for isConnected in [false, true] {
                    let name = group.iconName(for: AppIconVariant(isDark: isDark, isConnected: isConnected))
                    let url = root.appending(path: "Sources/Spooky/AppIcon/Icons/\(name).icns", directoryHint: .notDirectory)

                    #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)), "\(name)")
                }
            }

            let customIcon = AppIconController.customIconVariant(for: group, iconTheme: nil, appearance: appearance)

            #expect((customIcon == nil) == (group == .defaultGroup), "\(group)")
        }
    }
}
