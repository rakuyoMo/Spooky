import AppKit
import SwiftUI

// MARK: - GitHubLinksSettingsRow

/// Integration 页的 github.com 一行：网页上 “Open with Desktop” 的仓库链接交给哪个 App 打开。
///
/// 菜单列出能打开 `x-github-client://` 链接的 App，选中的 App 同时成为 `x-github-client` 与 `github-mac` 两个协议的默认程序。
struct GitHubLinksSettingsRow: View {
    /// 能打开链接的 App，按名称排序。
    @State
    private var applications: [URL] = []

    /// 当前的默认程序；系统还没有默认程序时为 nil。
    @State
    private var selection: URL?

    /// 右对齐的标签与 278 pt 宽的弹出菜单，下面一行说明。
    var body: some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(AppLocalization.text("settings.github"))
                .gridColumnAlignment(.trailing)

            VStack(alignment: .leading, spacing: 4) {
                Picker("", selection: choice) {
                    ForEach(applications, id: \.self) { application in
                        Text(FileManager.default.displayName(atPath: application.path))
                            .tag(Optional(application))
                    }
                }
                .labelsHidden()
                .frame(width: 278)
                .disabled(applications.isEmpty)
                .accessibilityLabel(AppLocalization.text("settings.github"))

                Text(AppLocalization.text("settings.github.help"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 278, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear(perform: reload)
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

    /// 读出能打开链接的 App 与当前的默认程序。
    private func reload() {
        guard let probe = URL(string: SpookyURL.githubSchemes[0] + "://openRepo/") else {
            return
        }

        applications = NSWorkspace.shared.urlsForApplications(toOpen: probe)
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        selection = NSWorkspace.shared.urlForApplication(toOpen: probe)
    }
}
