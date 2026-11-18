import AppKit
import Testing

@testable import Spooky

// MARK: - AppIconGroupTests

/// 图标组与仓库里的图标资源、包的默认图标、打包脚本写出的壳 App 相互对得上。
@MainActor
struct AppIconGroupTests {
    /// 默认的一组是探身，包里的默认图标（`CFBundleIconFile`）是它的默认图标；每组的四份 icns 都在仓库里，
    /// 打包脚本给每组各写一个壳 App，其它组都要写自定义图标。
    @Test("默认的一组是探身；每组的图标资源与壳 App 齐全，其它组写自定义图标")
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

        let shellNames = AppIconGroup.allCases.map { $0.iconName(for: .standard) }

        let appearance = try #require(NSAppearance(named: .aqua))

        #expect(AppIconGroup.defaultGroup == .rise)
        #expect(info["CFBundleIconFile"] as? String == AppIconGroup.defaultGroup.iconName(for: .standard))
        #expect(shells.contains("icon_names=(" + shellNames.joined(separator: " ") + ")"))

        for group in AppIconGroup.allCases {
            for isDark in [false, true] {
                for isConnected in [false, true] {
                    let name = group.iconName(for: AppIconVariant(isDark: isDark, isConnected: isConnected))
                    let folder = group.iconName(for: .standard).dropFirst("AppIcon".count)

                    let url = root.appending(
                        path: "Sources/Spooky/AppIcon/Icons/\(folder)/\(name).icns",
                        directoryHint: .notDirectory
                    )

                    #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)), "\(name)")
                }
            }

            let customIcon = AppIconController.customIconVariant(for: group, iconTheme: nil, appearance: appearance)

            #expect((customIcon == nil) == (group == .defaultGroup), "\(group)")
        }
    }
}
