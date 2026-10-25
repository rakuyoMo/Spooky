import AppKit
import SpookyKit
import SwiftUI

// MARK: - GitProgramSettingsRow

/// Settings → Git Config 里 Git binary 的两行：本机可用的 Git 与 “选择 Git 程序…”，下一行是 11 pt 的最低版本说明。
///
/// 只影响本机仓库；服务器仓库用服务器上的 Git。
struct GitProgramSettingsRow: View {
    /// 菜单里 “选择 Git 程序…” 一项的标识，不是任何程序的路径。
    private static let chooseTag = ""

    /// 所选的程序。
    let preferences: LocalExecutionPreferences

    /// 版本满足要求的本机 Git，按常见位置的顺序。
    @State
    private var programs: [GitProgram] = []

    /// 所选程序的检查结果；它不在列表里时用来显示它的状态。
    @State
    private var selected: GitProgram?

    /// 用户选了不能使用的文件时显示原因。
    @State
    private var rejected: GitProgram?

    /// 右对齐的标签加 278 pt 宽的弹出菜单，下一行是最低版本。
    var body: some View {
        GridRow {
            Text(AppLocalization.text("settings.gitProgram"))
                .gridColumnAlignment(.trailing)

            picker
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Text(AppLocalization.text("settings.gitProgram.minimum", GitVersion.minimum.description))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 278, alignment: .leading)
        }
    }

    /// 创建 Git binary 一行。
    ///
    /// - Parameter preferences: 读写的偏好；测试使用独立偏好域的实例。
    init(preferences: LocalExecutionPreferences = .shared) {
        self.preferences = preferences
    }
}

// MARK: - Private

extension GitProgramSettingsRow {
    /// 可用的程序、分隔线与 “选择 Git 程序…”；选中最后一项时打开面板，菜单仍停在原来的程序上。
    private var picker: some View {
        Picker(
            "",
            selection: Binding(
                get: { preferences.gitExecutable },
                set: { $0 == Self.chooseTag ? choose() : preferences.selectGitExecutable($0) }
            )
        ) {
            ForEach(menuPaths, id: \.self) { path in
                Text(title(path)).tag(path)
            }

            Divider()

            Text(AppLocalization.text("settings.gitProgram.choose")).tag(Self.chooseTag)
        }
        .labelsHidden()
        .frame(width: 278)
        .accessibilityLabel(AppLocalization.text("settings.gitProgram"))
        .task(id: preferences.gitExecutable) { await load() }
        .alert(
            AppLocalization.text("settings.gitProgram.rejected"),
            isPresented: Binding(
                get: { rejected != nil },
                set: { if !$0 { rejected = nil } }
            )
        ) { } message: {
            Text(rejected.map(Self.reason) ?? "")
        }
    }

    /// 菜单里的路径：可用的程序，再加上不在其中的所选程序。
    private var menuPaths: [String] {
        let paths = programs.map(\.path)

        return paths.contains(preferences.gitExecutable) ? paths : paths + [preferences.gitExecutable]
    }

    /// 文件不能用作 Git 的原因：不是 Git，或版本低于要求。
    private static func reason(_ program: GitProgram) -> String {
        guard let version = program.versionText else {
            return AppLocalization.text("settings.gitProgram.rejected.notGit", program.path)
        }

        return AppLocalization.text(
            "settings.gitProgram.rejected.version",
            program.path,
            version,
            GitVersion.minimum.description
        )
    }

    /// 菜单项的标题：路径加版本，系统 Git 标出 “系统”；还没检查完时只显示路径，无法运行时标出不可用。
    private func title(_ path: String) -> String {
        let program = programs.first { $0.path == path } ?? selected.flatMap { $0.path == path ? $0 : nil }

        guard let program else { return path }

        guard let version = program.versionText else {
            return AppLocalization.text("settings.gitProgram.unavailable", path)
        }

        return program.isSystem
            ? AppLocalization.text("settings.gitProgram.system", path, version)
            : AppLocalization.text("settings.gitProgram.version", path, version)
    }

    /// 检查常见位置、Xcode 自带的 Git 与所选程序的版本。
    private func load() async {
        let xcode = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: "com.apple.dt.Xcode")
            .map { $0.appending(path: "Contents/Developer/usr/bin/git").path }

        async let installed = GitProgram.installed(additionalPaths: xcode)
        async let current = GitProgram.probe(preferences.gitExecutable)

        let (found, probe) = await (installed, current)

        guard !Task.isCancelled else { return }

        programs = found
        selected = probe
    }

    /// 选择一个可执行文件；版本满足要求才换成它，否则说明原因并保留原来的选择。
    private func choose() {
        let panel = NSOpenPanel()
        let filter = ExecutableFileFilter()

        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        panel.delegate = filter

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            // 面板只弱引用代理，关闭前由这里持有过滤器。
            withExtendedLifetime(filter) { }

            guard response == .OK, let url = panel.url else { return }

            Task { await accept(url.path) }
        }

        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    /// 检查用户选的文件，能用就保存为所选程序。
    private func accept(_ path: String) async {
        let program = await GitProgram.probe(path)

        guard program.isSupported else {
            rejected = program
            return
        }

        selected = program
        preferences.selectGitExecutable(path)
    }
}

// MARK: - ExecutableFileFilter

/// 选择 Git 程序的面板只让可执行文件可选，目录仍可进入。
private final class ExecutableFileFilter: NSObject, NSOpenSavePanelDelegate {
    /// 可执行文件与目录可用（目录带执行权限，可以进入但不能选中），其它文件变灰。
    func panel(_: Any, shouldEnable url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }
}
