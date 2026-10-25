import AppKit
import SwiftUI

// MARK: - CloneDirectory

/// 克隆仓库时默认放到的本机目录；没有选过时是用户主目录。
enum CloneDirectory {
    /// 偏好键，值为目录的绝对路径。
    static let key = "defaultCloneDirectory"

    /// 当前的默认克隆目录；没有选过时是用户主目录。
    static var current: String {
        UserDefaults.standard.string(forKey: key) ?? NSHomeDirectory()
    }

    /// 弹出菜单里的候选目录：用户主目录、存在时的 `~/Development`，以及已选的目录；同一目录只列一次。
    ///
    /// - Parameters:
    ///   - selected: 当前选中的目录。
    ///   - home: 用户主目录。
    static func candidates(selected: String, home: String = NSHomeDirectory()) -> [String] {
        var isDirectory: ObjCBool = false
        let development = URL(fileURLWithPath: home).appending(path: "Development").path

        let exists = FileManager.default.fileExists(atPath: development, isDirectory: &isDirectory)
        let paths = [home] + (exists && isDirectory.boolValue ? [development] : []) + [selected]

        return paths.reduce(into: []) { result, path in
            if !result.contains(path) {
                result.append(path)
            }
        }
    }
}

// MARK: - CloneDirectoryRow

/// General 页的默认克隆目录：候选目录带 16 pt 的访达图标，末尾的 “Select…” 打开目录选择面板。
struct CloneDirectoryRow: View {
    /// 选中的目录。
    @AppStorage(CloneDirectory.key)
    private var directory = NSHomeDirectory()

    /// 右对齐的标签与 278 pt 宽的弹出菜单。
    var body: some View {
        GridRow {
            Text(AppLocalization.text("settings.cloneDirectory"))
                .gridColumnAlignment(.trailing)

            Picker("", selection: selection) {
                ForEach(CloneDirectory.candidates(selected: directory), id: \.self) { path in
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable()
                            .frame(width: 16, height: 16)
                            .accessibilityHidden(true)

                        Text(FileManager.default.displayName(atPath: path))
                    }
                    .tag(path)
                }

                Divider()

                Text(AppLocalization.text("settings.cloneDirectory.select"))
                    .tag(Self.selectTag)
            }
            .labelsHidden()
            .frame(width: 278)
            .help(directory)
            .accessibilityLabel(AppLocalization.text("settings.cloneDirectory"))
        }
    }
}

// MARK: - Private

extension CloneDirectoryRow {
    /// “Select…” 一项的标记，不是任何目录的路径。
    private static let selectTag = ""

    /// 选中候选目录时直接保存；选中 “Select…” 时打开面板，菜单仍显示原来的目录。
    private var selection: Binding<String> {
        Binding(
            get: { directory },
            set: { path in
                guard path != Self.selectTag else {
                    chooseDirectory()
                    return
                }

                directory = path
            }
        )
    }

    /// 在设置窗口上以 sheet 打开目录选择面板，允许新建目录；选好后保存。
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.resolvesAliases = true
        panel.directoryURL = URL(fileURLWithPath: directory)

        let save: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else {
                return
            }

            directory = url.path
        }

        guard let window = NSApp.keyWindow else {
            save(panel.runModal())
            return
        }

        panel.beginSheetModal(for: window, completionHandler: save)
    }
}
