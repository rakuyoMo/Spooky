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
            Image(nsImage: Self.icon(path: path, isFolder: folder))
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

    /// 只按名称与已知目录身份取系统图标，不读取本机或服务器文件。
    static func icon(path: String, isFolder: Bool) -> NSImage {
        if isFolder {
            return NSWorkspace.shared.icon(for: .folder)
        }

        let name = RepositorySession.fileName(path)
        let extensionName = name.lastIndex(of: ".").map { String(name[name.index(after: $0)...]) } ?? ""
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
