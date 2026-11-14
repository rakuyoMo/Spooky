import AppKit
import SpookyKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - WorkingCopyFileHeader

/// 工作区单文件或目录的头部：类型图标、末级名称、动作与比较侧。
struct WorkingCopyFileHeader: View {
    /// 文件动作与比较侧所属的仓库会话。
    @Bindable
    var session: RepositorySession

    /// 完整相对路径，悬停时显示。
    let path: String

    /// 合成目录没有状态条目。
    let entry: StatusEntry?

    /// 当前目标是否为普通目录；子模块不使用目录的动作规则。
    let isDirectory: Bool

    /// 鼠标是否位于头部。
    @State
    private var hovering = false

    /// 文件名中间截断，宽度不足时动作组按原生分段比例压缩。
    var body: some View {
        let actions = session.workingCopyFileActions(path, entry: entry, isDirectory: isDirectory)
        let folder = isDirectory || session.submodules.items.contains { $0.path == path }
        let name = RepositorySession.fileName(path)

        HStack(spacing: 8) {
            Image(nsImage: Self.icon(path: path, isFolder: folder, root: session.repository?.localURL))
                .resizable()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(name)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(nsColor: .headerTextColor))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(path)
                .frame(minWidth: minimumNameWidth(name), alignment: .leading)
                .layoutPriority(-1)

            Spacer(minLength: 0)

            FileActionBar(actions: actions, hovering: hovering)

            if let entry, entry.hasWorkingCopyDiff, !isDirectory {
                DiffSidePicker(
                    side: $session.diffSide,
                    staged: entry.hasStagedChanges,
                    unstaged: entry.hasUnstagedChanges,
                    enabled: entry.kind == .tracked && (entry.hasStagedChanges || entry.hasUnstagedChanges)
                )
                .fixedSize()
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 40)
        .background(FileHeaderBackground())
        .modifier(FileActionHeader(actions: actions, hovering: $hovering))
    }

    /// 文件或目录的系统图标。
    ///
    /// 本机仓库里存在的文件取它实际的图标；服务器仓库、已删除的文件与目录按名称与身份取，
    /// 以点开头、其后没有其它点的名字（如 `.gitignore`）没有扩展名。
    ///
    /// - Parameters:
    ///   - path: 相对仓库根目录的路径。
    ///   - isFolder: 是否按目录显示。
    ///   - root: 本机仓库的根目录；服务器仓库传 `nil`。
    static func icon(path: String, isFolder: Bool, root: URL? = nil) -> NSImage {
        if isFolder {
            return NSWorkspace.shared.icon(for: .folder)
        }

        // 本机文件交给系统读取实际图标，自定义图标与应用程序包都能显示
        if let root {
            let file = root.appending(path: path)

            if FileManager.default.fileExists(atPath: file.path) {
                return NSWorkspace.shared.icon(forFile: file.path)
            }
        }

        let name = RepositorySession.fileName(path)
        let dot = name.lastIndex(of: ".").flatMap { $0 == name.startIndex ? nil : $0 }
        let extensionName = dot.map { String(name[name.index(after: $0)...]) } ?? ""
        let type = UTType(filenameExtension: extensionName) ?? .data

        return NSWorkspace.shared.icon(for: type)
    }

    /// 为中间截断预留首尾字符与省略号的宽度，短文件名则保留原宽。
    private func minimumNameWidth(_ name: String) -> CGFloat {
        let text = name.count > 2 ? "\(name.prefix(1))…\(name.suffix(1))" : name
        let font = NSFont.boldSystemFont(ofSize: 13)
        return ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width)
    }
}
