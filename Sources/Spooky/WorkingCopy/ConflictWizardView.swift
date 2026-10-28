import AppKit
import SpookyKit
import SwiftUI

// MARK: - ConflictWizardView

/// 选中冲突文件时的右栏：我方、对方两张版本卡片与合并工具，两侧都要保留时交给合并工具；文件已在别处改过时，多一张手动编辑结果的卡片。
struct ConflictWizardView: View {
    /// 触发载入的请求：文件的三方版本变化或用户要求重新载入时重新读取。
    private struct LoadRequest: Equatable {
        /// 选中的冲突文件，包含三方 stage 的哈希。
        let entry: StatusEntry

        /// 重新载入的请求序号。
        let reloads: Int
    }

    /// 版本卡片对应的一侧。
    private enum Side {
        /// 我方版本。
        case ours

        /// 对方版本。
        case theirs
    }

    /// 当前仓库会话。
    @Bindable
    var session: RepositorySession

    /// 选中的冲突文件。
    let entry: StatusEntry

    /// 最近一次载入的三方内容；重新载入期间继续显示上一份。
    @State
    private var contents: ConflictContents?

    /// 载入失败的原因，保留可复制的原文。
    @State
    private var failure: AppFailure?

    /// 重新载入的请求序号。
    @State
    private var reloads = 0

    /// 设置里选的合并工具，决定合并按钮的标题。
    @AppStorage(ExternalTool.mergeToolKey)
    private var mergeTool = ""

    /// 载入中、失败或向导内容。
    ///
    /// 写入结束、重新连上服务器与切回本程序时自动重新载入：文件可能已在外部编辑器里改过。
    var body: some View {
        Group {
            if let failure {
                FailureDetailsView(failure: failure) { reloads += 1 }
                    .padding(20)
            } else if let contents {
                wizard(contents)
            } else {
                ProgressView(AppLocalization.text("conflict.loading"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: LoadRequest(entry: entry, reloads: reloads)) { await load() }
        .onChange(of: session.isWriting) {
            if !session.isWriting { reloads += 1 }
        }
        .onChange(of: session.connectionState) {
            if session.connectionState == .connected { reloads += 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            reloads += 1
        }
    }
}

// MARK: - Private

extension ConflictWizardView {
    /// 没有进行中的操作时，冲突来自应用补丁或储藏，对方卡片用专门的标题。
    private var isAppliedChange: Bool {
        session.context?.progress == nil
    }

    /// 合并按钮：选过合并工具时写出它的名字，还没有选时先选工具。
    private var mergeToolTitle: String {
        guard let tool = ExternalTool(rawValue: mergeTool), tool.supportsMerge else {
            return AppLocalization.text("externalTool.chooseMergeTool")
        }

        return AppLocalization.text("externalTool.mergeIn", tool.displayName)
    }

    /// 卡片底色。
    private var tile: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(AppPalette.color("repository_mergeconflict_tile_background_light_color"))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppPalette.color("general_border_color")))
    }

    /// 卡片内容区的深一档底色。
    private var innerTile: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(AppPalette.color("repository_mergeconflict_tile_background_dark_color"))
    }

    /// 冲突类型的说明与重新载入。
    private var header: some View {
        HStack(spacing: 8) {
            Label(entry.conflictKind?.title ?? "", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)

            Spacer(minLength: 0)

            Button(AppLocalization.text("conflict.reload")) { reloads += 1 }
        }
    }

    /// 可以按文本显示的内容：不含 NUL 且是有效的 UTF-8。
    private static func text(_ data: Data) -> String? {
        guard !data.contains(0) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// 冲突类型与重新载入、两张版本卡片、合并工具，以及手动编辑结果的卡片。
    private func wizard(_ contents: ConflictContents) -> some View {
        #warning("TODO: 制造冲突后打开向导核对：版本卡片是否显示原文，合并工具按钮位于卡片下方还是两张卡片之间；只影响冲突向导右栏的卡片内容与按钮位置")

        return VStack(alignment: .leading, spacing: 16) {
            header

            HStack(alignment: .top, spacing: 12) {
                versionCard(.ours, data: contents.ours)
                versionCard(.theirs, data: contents.theirs)
            }

            if entry.conflict?.hasRegularFilesOnBothSides ?? false {
                Button(mergeToolTitle) { session.openMergeTool(entry) }
                    .disabled(!session.canOpenMergeTool([entry]))
                    .frame(maxWidth: .infinity)
            }

            if contents.isManuallyEdited {
                editedCard(contents)
            }
        }
        .padding(20)
    }

    /// 一侧的版本：标题、打开与导出菜单、原文预览和采用这一侧的按钮。
    private func versionCard(_ side: Side, data: Data?) -> some View {
        let name = side == .ours ? session.oursName : session.theirsName
        let applied = side == .theirs && isAppliedChange

        let title = applied
            ? AppLocalization.text("conflict.version.applied")
            : AppLocalization.text("conflict.version", name)

        let resolveTitle = applied
            ? AppLocalization.text("conflict.resolveUsing.applied")
            : AppLocalization.text("conflict.resolveUsing", name)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(title)

                Spacer(minLength: 0)

                versionMenu(name: name, data: data)
            }

            preview(data, label: title)

            Button(resolveTitle) { session.resolve([entry], theirs: side == .theirs) }
                .disabled(!session.canResolve([entry]))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tile)
    }

    /// 打开或导出这一侧的原文；这一侧删除了文件时两项都不可用，只显示动作名。
    private func versionMenu(name: String, data: Data?) -> some View {
        Menu {
            if let data {
                Button(AppLocalization.text("conflict.open", name)) { open(data) }

                Divider()

                Button(AppLocalization.text("conflict.export", name)) { export(data) }
            } else {
                Button(AppLocalization.text("conflict.open.missing")) { }
                    .disabled(true)

                Divider()

                Button(AppLocalization.text("conflict.export.missing")) { }
                    .disabled(true)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(AppLocalization.text("conflict.versionMenu", name))
    }

    /// 工作区里已经改过的当前文件，可以直接用它标记解决。
    private func editedCard(_ contents: ConflictContents) -> some View {
        let title = AppLocalization.text("conflict.result")

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            preview(contents.worktree, label: title)

            Button(AppLocalization.text("conflict.resolveCurrent")) { session.stage([entry], staged: true) }
                .disabled(!session.canResolve([entry]))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tile)
    }

    /// 只读预览；删除了文件的一侧与二进制内容只显示说明。
    @ViewBuilder
    private func preview(_ data: Data?, label: String) -> some View {
        if let data, let string = Self.text(data) {
            ConflictTextView(text: string)
                .background(innerTile)
                .accessibilityLabel(label)
        } else {
            Text(AppLocalization.text(data == nil ? "conflict.missing" : "conflict.binary"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(innerTile)
        }
    }

    /// 读取三方内容；被新的请求取代的结果直接丢弃。
    private func load() async {
        do {
            let loaded = try await session.conflictContents(of: entry)

            guard !Task.isCancelled else { return }

            contents = loaded
            failure = nil
        } catch {
            guard !Task.isCancelled else { return }

            failure = AppFailure(error: error, opening: false, location: session.repository)
        }
    }

    /// 用默认程序打开这一侧的原文；副本放在会话的本机缓存里，服务器路径不交给本机程序。
    private func open(_ data: Data) {
        guard let cache = session.fileCache else { return }

        do {
            NSWorkspace.shared.open(try cache.store(data, named: entry.path))
        } catch {
            session.onFailure?(AppFailure(error: error, opening: false, location: session.repository))
        }
    }

    /// 把这一侧的原文导出到用户选择的位置；服务器上的版本在载入时已经取到本机。
    private func export(_ data: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = entry.path.split(separator: "/").last.map(String.init) ?? entry.path

        let repository = session.repository
        let report = session.onFailure

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                try data.write(to: url)
            } catch {
                report?(AppFailure(error: error, opening: false, location: repository))
            }
        }

        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }
}

// MARK: - ConflictKind

extension ConflictKind {
    /// 冲突类型的本地化名称，向导标题与文件行的悬停提示共用。
    var title: String {
        switch self {
        case .bothModified: AppLocalization.text("conflict.kind.bothModified")
        case .bothAdded: AppLocalization.text("conflict.kind.bothAdded")
        case .bothDeleted: AppLocalization.text("conflict.kind.bothDeleted")
        case .addedByUs: AppLocalization.text("conflict.kind.addedByUs")
        case .addedByThem: AppLocalization.text("conflict.kind.addedByThem")
        case .deletedByUs: AppLocalization.text("conflict.kind.deletedByUs")
        case .deletedByThem: AppLocalization.text("conflict.kind.deletedByThem")
        }
    }
}

// MARK: - ConflictTextView

/// 冲突内容的只读等宽文本区：可以选中复制，大文件交给 NSTextView 排版。
private struct ConflictTextView: NSViewRepresentable {
    /// 显示的文本。
    let text: String

    /// 关闭编辑，保留选择与复制。
    func makeNSView(context _: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false

        guard let view = scroll.documentView as? NSTextView else {
            return scroll
        }

        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.isRichText = false
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 4, height: 4)
        view.string = text
        return scroll
    }

    /// 内容变化时才替换，选区保持不变。
    func updateNSView(_ scroll: NSScrollView, context _: Context) {
        guard let view = scroll.documentView as? NSTextView, view.string != text else { return }

        view.string = text
    }
}
