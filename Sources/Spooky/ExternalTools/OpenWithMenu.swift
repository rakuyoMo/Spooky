import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - OpenWithApplications

/// Open With ▸ 列出的程序：默认程序在前，其余能打开全部文件的程序按名称排序，默认程序不重复列出。
struct OpenWithApplications: Equatable {
    /// 全部文件共同的默认程序；各文件的默认程序不同时为 nil。
    let defaultApplication: URL?

    /// 其余能打开全部文件的程序。
    let others: [URL]

    /// 没有能打开这些文件的程序。
    var isEmpty: Bool {
        defaultApplication == nil && others.isEmpty
    }

    /// 按本机文件读取，适用于本机工作区里的文件。
    static func load(for files: [URL]) -> Self {
        combine(
            defaults: files.map { NSWorkspace.shared.urlForApplication(toOpen: $0) },
            candidates: files.map { NSWorkspace.shared.urlsForApplications(toOpen: $0) }
        )
    }

    /// 按文件名读取，适用于还没有取到本机的服务器文件与历史版本；没有扩展名的文件按普通数据判断。
    static func load(forNames names: [String]) -> Self {
        let types = names.map { name in
            UTType(filenameExtension: URL(fileURLWithPath: name).pathExtension) ?? .data
        }

        return combine(
            defaults: types.map { NSWorkspace.shared.urlForApplication(toOpen: $0) },
            candidates: types.map { NSWorkspace.shared.urlsForApplications(toOpen: $0) }
        )
    }

    /// 合并多个文件的结果：各文件的默认程序相同才有默认程序；其余程序取能打开全部文件的交集，按名称排序。
    ///
    /// - Parameters:
    ///   - defaults: 各文件的默认程序。
    ///   - candidates: 各文件能用的程序。
    static func combine(defaults: [URL?], candidates: [[URL]]) -> Self {
        let defaultPaths = Set(defaults.map { $0?.standardizedFileURL.path })
        let defaultApplication = defaultPaths.count == 1 ? defaults.first?.map(\.standardizedFileURL) : nil

        // 只保留每个文件都能用的程序，同一程序只列一次
        var shared = candidates.first.map { $0.map(\.standardizedFileURL) } ?? []

        for list in candidates.dropFirst() {
            let paths = Set(list.map(\.standardizedFileURL.path))
            shared = shared.filter { paths.contains($0.path) }
        }

        var seen = Set(defaultApplication.map { [$0.path] } ?? [])
        let others = shared
            .filter { seen.insert($0.path).inserted }
            .sorted { name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending }

        return Self(defaultApplication: defaultApplication, others: others)
    }

    /// 程序在菜单里显示的名字。
    static func name(of application: URL) -> String {
        FileManager.default.displayName(atPath: application.path)
    }

    /// 菜单里 16 pt 的程序图标。
    static func icon(of application: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: application.path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}

// MARK: - OpenWithMenu

/// AppKit 右键菜单里的 Open With ▸ 子菜单：打开时在后台读取程序列表，读取期间显示 “Loading”。
@MainActor
final class OpenWithMenu: NSObject, NSMenuDelegate {
    /// 交给父菜单项的子菜单。
    let menu = NSMenu()

    /// 在后台读取程序列表。
    private let load: @Sendable () -> OpenWithApplications

    /// 用选中的程序打开文件。
    private let open: (URL) -> Void

    /// Other…：让用户自己选程序。
    private let other: () -> Void

    /// 正在进行或已完成的读取；同一个子菜单只读取一次。
    private var loading: Task<Void, Never>?

    /// 创建子菜单，读取推迟到第一次展开。
    ///
    /// - Parameters:
    ///   - load: 在后台读取程序列表。
    ///   - open: 用选中的程序打开文件。
    ///   - other: 让用户自己选程序。
    init(
        load: @escaping @Sendable () -> OpenWithApplications,
        open: @escaping (URL) -> Void,
        other: @escaping () -> Void
    ) {
        self.load = load
        self.open = open
        self.other = other
        super.init()

        menu.autoenablesItems = false
        menu.delegate = self
    }

    /// 带子菜单的 “Open With” 菜单项；菜单项持有本对象，子菜单关闭前不会释放。
    func item(enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: AppLocalization.text("files.openWith"), action: nil, keyEquivalent: "")
        item.isEnabled = enabled
        item.representedObject = self

        if enabled {
            item.submenu = menu
        }

        return item
    }

    /// 第一次展开时显示 “Loading”，在后台读取程序列表后换成程序菜单项。
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard loading == nil else {
            return
        }

        menu.removeAllItems()

        let placeholder = NSMenuItem(title: AppLocalization.text("files.openWith.loading"), action: nil, keyEquivalent: "")
        placeholder.isEnabled = false
        menu.addItem(placeholder)

        let load = load

        loading = Task { [weak self] in
            let applications = await Task.detached { load() }.value
            self?.show(applications)
        }
    }

    /// 默认程序标 (Default)，其后是分隔线与其余程序；没有程序时是 “<None>”；最后是 Other…。
    private func show(_ applications: OpenWithApplications) {
        menu.removeAllItems()

        if let application = applications.defaultApplication {
            let title = AppLocalization.text("files.openWith.default", OpenWithApplications.name(of: application))
            menu.addItem(applicationItem(application, title: title))
            menu.addItem(.separator())
        }

        for application in applications.others {
            menu.addItem(applicationItem(application, title: OpenWithApplications.name(of: application)))
        }

        if applications.isEmpty {
            let none = NSMenuItem(title: AppLocalization.text("files.openWith.none"), action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }

        menu.addItem(.separator())

        let other = NSMenuItem(
            title: AppLocalization.text("files.openWith.other"),
            action: #selector(chooseOther),
            keyEquivalent: ""
        )
        other.target = self
        menu.addItem(other)
    }

    /// 一个程序的菜单项：图标、名字，选中时用它打开文件。
    private func applicationItem(_ application: URL, title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(openWithApplication(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = application
        item.image = OpenWithApplications.icon(of: application)
        return item
    }

    /// 用菜单项对应的程序打开文件。
    @objc
    private func openWithApplication(_ sender: NSMenuItem) {
        guard let application = sender.representedObject as? URL else { return }
        open(application)
    }

    /// 让用户自己选程序。
    @objc
    private func chooseOther() {
        other()
    }
}

// MARK: - OpenWithMenuItems

/// SwiftUI 右键菜单里 Open With ▸ 的内容：菜单打开时按文件名读取程序列表。
struct OpenWithMenuItems: View {
    /// 要打开的文件名，用来判断能打开它们的程序。
    let names: [String]

    /// 用选中的程序打开文件。
    let open: (URL) -> Void

    /// Other…：让用户自己选程序。
    let other: () -> Void

    /// 默认程序、其余程序、没有程序时的 “<None>” 与 Other…。
    var body: some View {
        let applications = OpenWithApplications.load(forNames: names)

        if let application = applications.defaultApplication {
            button(application, title: AppLocalization.text("files.openWith.default", OpenWithApplications.name(of: application)))
            Divider()
        }

        ForEach(applications.others, id: \.self) { application in
            button(application, title: OpenWithApplications.name(of: application))
        }

        if applications.isEmpty {
            Button(AppLocalization.text("files.openWith.none")) { }
                .disabled(true)
        }

        Divider()

        Button(AppLocalization.text("files.openWith.other"), action: other)
    }

    /// 一个程序的菜单项：图标与名字。
    private func button(_ application: URL, title: String) -> some View {
        Button {
            open(application)
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(nsImage: OpenWithApplications.icon(of: application))
            }
        }
    }
}
