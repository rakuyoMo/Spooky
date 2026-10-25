import AppKit
import SpookyKit
import SwiftUI

// MARK: - ServerCloneDirectories

/// 每台主机记住的克隆目录：上次在这台主机上克隆时选的目录。
enum ServerCloneDirectories {
    /// 偏好键，值为主机别名到 B 上目录的字典。
    static let key = "serverCloneDirectories"

    /// 这台主机记住的目录；还没有在它上面克隆过时为 nil。
    static func directory(for host: String, in defaults: UserDefaults = .standard) -> String? {
        (defaults.dictionary(forKey: key) as? [String: String])?[host]
    }

    /// 记住在这台主机上克隆时选的目录。
    static func remember(_ directory: String, for host: String, in defaults: UserDefaults = .standard) {
        var directories = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        directories[host] = directory
        defaults.set(directories, forKey: key)
    }

    /// 选择目标机器时列出的主机：书签里服务器仓库的主机与克隆过的主机，按名称排序。
    @MainActor
    static func hosts(in bookmarks: RepositoryBookmarks, defaults: UserDefaults = .standard) -> [String] {
        let bookmarked = bookmarks.repositories.compactMap(\.location?.host)
        let cloned = (defaults.dictionary(forKey: key) as? [String: String]).map { Array($0.keys) } ?? []

        return Set(bookmarked + cloned).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

// MARK: - HostDirectoryPicker

/// 对话框表单里选目标目录的两行：先选本机或一台服务器，再选那台机器上的目录。
///
/// 本机目录经系统的目录面板选择；服务器目录可以手填，也可以浏览 B 上的目录。换到服务器时填入这台主机记住的目录，
/// 没有记住的目录时取 B 上用户的主目录。
struct HostDirectoryPicker: View {
    /// 机器一行的标签，带冒号。
    let label: String

    /// 菜单里列出的服务器主机别名。
    let hosts: [String]

    /// 选中的目录：本机或某台服务器上的绝对路径。
    @Binding
    var directory: RepositoryLocation

    /// 选了 “Other Server…”，主机别名手填。
    @State
    private var choosesOtherHost = false

    /// 正在浏览服务器上的目录。
    @State
    private var isBrowsing = false

    /// 机器、主机别名与目录各占一行。
    var body: some View {
        DialogFormRow(label: label) {
            Picker("", selection: machine) {
                Text(AppLocalization.text("clone.machine.local")).tag(Self.localTag)

                if !hosts.isEmpty {
                    Divider()
                }

                ForEach(hosts, id: \.self) { host in
                    Text(host).tag(host)
                }

                Divider()

                Text(AppLocalization.text("clone.machine.other")).tag(Self.otherTag)
            }
            .labelsHidden()
            .fixedSize()
        }

        if choosesOtherHost {
            DialogFormRow(label: AppLocalization.text("remote.host")) {
                TextField("", text: hostAlias)
                    .accessibilityIdentifier("destination-host")
            }
        }

        DialogFormRow(label: AppLocalization.text("clone.directory")) {
            directoryField
        }
        .sheet(isPresented: $isBrowsing) {
            if let host = directory.host {
                ServerDirectoryBrowser(host: host, path: directory.path) { chosen in
                    isBrowsing = false

                    if let chosen {
                        directory = .remote(host: host, path: chosen)
                    }
                }
            }
        }
    }
}

// MARK: - Private

extension HostDirectoryPicker {
    /// 菜单里 “This Mac” 一项的标记。
    private static let localTag = ""

    /// 菜单里 “Other Server…” 一项的标记，不会是主机别名。
    private static let otherTag = "\u{0}other"

    /// 机器菜单的选择：本机、某台已知主机或手填别名。
    private var machine: Binding<String> {
        Binding(
            get: {
                guard let host = directory.host else { return Self.localTag }
                return choosesOtherHost || !hosts.contains(host) ? Self.otherTag : host
            },
            set: { tag in
                choosesOtherHost = tag == Self.otherTag

                switch tag {
                case Self.localTag:
                    directory = .local(path: CloneDirectory.current)

                case Self.otherTag:
                    directory = .remote(host: "", path: "")

                default:
                    select(host: tag)
                }
            }
        )
    }

    /// 手填的主机别名；改别名时目录换成这台主机记住的目录。
    private var hostAlias: Binding<String> {
        Binding(
            get: { directory.host ?? "" },
            set: { directory = .remote(host: $0, path: ServerCloneDirectories.directory(for: $0) ?? directory.path) }
        )
    }

    /// 本机显示目录与 “Choose…”；服务器是可以手填的路径与 “Browse…”。
    @ViewBuilder
    private var directoryField: some View {
        if let host = directory.host {
            HStack(spacing: 8) {
                TextField("", text: remotePath, prompt: Text(AppLocalization.text("clone.directory.prompt")))
                    .accessibilityIdentifier("destination-path")

                Button(AppLocalization.text("clone.browse")) { isBrowsing = true }
                    .disabled(host.isEmpty)
            }
        } else {
            HStack(spacing: 8) {
                Text(directory.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(AppLocalization.text("bookmarks.create.choose"), action: chooseLocalDirectory)
            }
        }
    }

    /// 服务器路径的输入。
    private var remotePath: Binding<String> {
        Binding(
            get: { directory.path },
            set: { directory = .remote(host: directory.host ?? "", path: $0) }
        )
    }

    /// 换到一台已知主机：填入它记住的目录；没有记住的目录时连接这台主机，取 B 上用户的主目录。
    private func select(host: String) {
        guard let remembered = ServerCloneDirectories.directory(for: host) else {
            directory = .remote(host: host, path: "")

            Task {
                let environment = try? await RemoteConnection.presentingHost(host).connectHost()

                // 等待期间用户可能已换了机器或填了路径
                if directory == .remote(host: host, path: ""), let home = environment?.homeDirectory {
                    directory = .remote(host: host, path: home)
                }
            }

            return
        }

        directory = .remote(host: host, path: remembered)
    }

    /// 以 sheet 弹出系统的目录面板，可以在里面新建目录。
    private func chooseLocalDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: directory.path)
        panel.prompt = AppLocalization.text("bookmarks.create.choosePrompt")

        guard let window = NSApp.keyWindow else {
            return
        }

        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                directory = .local(path: url.path)
            }
        }
    }
}
