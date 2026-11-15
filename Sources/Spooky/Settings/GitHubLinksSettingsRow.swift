import AppKit
import SwiftUI

// MARK: - GitHubLinksSettingsRow

/// Integration 页的 github.com 一行：网页上 “Open with Desktop” 的仓库链接交给哪个 App 打开。
///
/// 菜单列出能打开 `x-github-client://` 链接的 App 与它们的图标，写成 “名称 (版本)”，同一 Bundle ID 只列一项；
/// 选中的 App 同时成为 `x-github-client` 与 `github-mac` 两个协议的默认程序。
struct GitHubLinksSettingsRow: View {
    /// 能打开链接的 App，按标题排序。
    @State
    private var applications: [URL] = []

    /// 当前的默认程序；系统还没有默认程序时为 nil。
    @State
    private var selection: URL?

    /// 右对齐的标签与占满控件列的弹出菜单。
    var body: some View {
        SettingsRow(AppLocalization.text("settings.github")) {
            Picker("", selection: choice) {
                ForEach(applications, id: \.self) { application in
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.menuIcon(forFile: application.path))
                            .accessibilityHidden(true)

                        Text(Self.title(of: application))
                    }
                    .tag(Optional(application))
                }
            }
            .labelsHidden()
            .settingsColumnWidth()
            .disabled(applications.isEmpty)
            .accessibilityLabel(AppLocalization.text("settings.github"))
        }
        .onAppear(perform: reload)
    }

    /// 菜单的候选：每个 Bundle ID 只留系统为它选定的那一份，没有 Bundle ID 的 App 照列；按标题排序。
    ///
    /// - Parameters:
    ///   - applications: 能打开链接的全部 App。
    ///   - resolve: 按 Bundle ID 找系统选定的那一份 App。
    static func candidates(
        _ applications: [URL],
        resolve: (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    ) -> [URL] {
        var identifiers: Set<String> = []
        var result: [URL] = []

        for application in applications {
            guard let identifier = Bundle(url: application)?.bundleIdentifier else {
                result.append(application)
                continue
            }

            // 同一 Bundle ID 的几份拷贝只列一次
            if identifiers.insert(identifier).inserted {
                result.append(resolve(identifier) ?? application)
            }
        }

        return result.sorted { title(of: $0).localizedStandardCompare(title(of: $1)) == .orderedAscending }
    }

    /// 菜单项的标题：“名称 (版本)”；读不到版本时只写名称，读不到名称时写 Bundle ID，两者都没有时写文件名。
    ///
    /// - Parameter application: App 的位置。
    static func title(of application: URL) -> String {
        let bundle = Bundle(url: application)
        let info = bundle?.infoDictionary

        guard let name = info?["CFBundleName"] as? String, !name.isEmpty else {
            return bundle?.bundleIdentifier ?? FileManager.default.displayName(atPath: application.path)
        }

        guard let version = info?["CFBundleShortVersionString"] as? String, !version.isEmpty else {
            return name
        }

        return "\(name) (\(version))"
    }
}

// MARK: - Private

extension GitHubLinksSettingsRow {
    /// 菜单的选择；选中后把两个协议的默认程序都换成它，再按系统的结果刷新。
    private var choice: Binding<URL?> {
        Binding(
            get: { selection },
            set: { application in
                guard let application else {
                    return
                }

                selection = application

                Task {
                    for scheme in SpookyURL.githubSchemes {
                        try? await NSWorkspace.shared.setDefaultApplication(at: application, toOpenURLsWithScheme: scheme)
                    }

                    reload()
                }
            }
        )
    }

    /// 读出能打开链接的 App 与当前的默认程序；默认程序按 Bundle ID 对上候选里的那一份。
    private func reload() {
        guard let probe = URL(string: SpookyURL.githubSchemes[0] + "://openRepo/") else {
            return
        }

        applications = Self.candidates(NSWorkspace.shared.urlsForApplications(toOpen: probe))

        let current = NSWorkspace.shared.urlForApplication(toOpen: probe)
        let identifier = current.flatMap { Bundle(url: $0)?.bundleIdentifier }

        selection = applications.first { application in
            identifier != nil && Bundle(url: application)?.bundleIdentifier == identifier
        } ?? current
    }
}
