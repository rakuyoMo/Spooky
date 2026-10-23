import AppKit
import SpookyKit
import SwiftUI

// MARK: - ConflictWizardView

/// 选中冲突文件时的右栏：我方、对方两张版本卡片与可以手动编辑的结果卡片，提供采用一方、保存编辑、标记解决和重新载入。
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

    /// 结果卡片里正在编辑的文本。
    @State
    private var text = ""

    /// 载入时工作区文件的文本；文件不在工作区或不是 UTF-8 文本时为 nil，结果卡片不可编辑。
    @State
    private var loadedText: String?

    /// 重新载入的请求序号。
    @State
    private var reloads = 0

    /// 载入中、失败或向导内容；写入结束与重新连上服务器后，没有未保存的编辑时自动重新载入。
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
            if !session.isWriting, !isEdited { reloads += 1 }
        }
        .onChange(of: session.connectionState) {
            if session.connectionState == .connected, !isEdited { reloads += 1 }
        }
    }
}

// MARK: - Private

extension ConflictWizardView {
    /// 结果卡片里有尚未保存的编辑。
    private var isEdited: Bool {
        loadedText.map { $0 != text } ?? false
    }

    /// 卡片底色与描边。
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

    /// 冲突类型的说明。
    private var kindTitle: String {
        switch entry.conflictKind ?? .bothModified {
        case .bothModified: AppLocalization.text("conflict.kind.bothModified")
        case .bothAdded: AppLocalization.text("conflict.kind.bothAdded")
        case .bothDeleted: AppLocalization.text("conflict.kind.bothDeleted")
        case .addedByUs: AppLocalization.text("conflict.kind.addedByUs")
        case .addedByThem: AppLocalization.text("conflict.kind.addedByThem")
        case .deletedByUs: AppLocalization.text("conflict.kind.deletedByUs")
        case .deletedByThem: AppLocalization.text("conflict.kind.deletedByThem")
        }
    }

    /// 可以按文本显示与编辑的内容：不含 NUL 且是有效的 UTF-8。
    private static func text(_ data: Data) -> String? {
        guard !data.contains(0) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// 冲突类型、两张版本卡片、结果卡片与备份文件。
    private func wizard(_ contents: ConflictContents) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(kindTitle, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)

            HStack(alignment: .top, spacing: 12) {
                versionCard(.ours, data: contents.ours)
                versionCard(.theirs, data: contents.theirs)
            }
            .frame(height: 220)

            resultCard(contents)

            ConflictBackupsView(session: session)
        }
        .padding(20)
    }

    /// 一侧的版本：标题、打开与导出菜单、原文预览和采用这一侧的按钮。
    private func versionCard(_ side: Side, data: Data?) -> some View {
        let name = side == .ours ? session.oursName : session.theirsName
        let title = AppLocalization.text("conflict.version", name)

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

            Button(AppLocalization.text("conflict.resolveUsing", name)) {
                session.resolve([entry], theirs: side == .theirs)
            }
            .disabled(!session.canResolve([entry]))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tile)
    }

    /// 打开或导出这一侧的原文；这一侧删除了文件时不可用。
    private func versionMenu(name: String, data: Data?) -> some View {
        Menu {
            Button(AppLocalization.text("conflict.open", name)) {
                if let data { open(data) }
            }

            Button(AppLocalization.text("conflict.export", name)) {
                if let data { export(data) }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(data == nil)
        .accessibilityLabel(AppLocalization.text("conflict.versionMenu", name))
    }

    /// 工作区里的当前文件：文本可编辑并保存；保存前后都可以重新载入或用它标记解决。
    private func resultCard(_ contents: ConflictContents) -> some View {
        let title = AppLocalization.text("conflict.result")

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            if loadedText != nil {
                ConflictTextView(text: $text, editable: session.canWrite)
                    .background(innerTile)
                    .accessibilityLabel(title)
            } else {
                placeholder(contents.worktree == nil ? "conflict.worktreeMissing" : "conflict.binary")
            }

            HStack(spacing: 8) {
                Button(AppLocalization.text("conflict.reload")) { reloads += 1 }

                Spacer(minLength: 0)

                Button(AppLocalization.text("conflict.save")) { save(contents) }
                    .disabled(!isEdited || !session.canWrite)

                Button(AppLocalization.text("conflict.resolveCurrent")) {
                    session.stage([entry], staged: true)
                }
                .disabled(isEdited || !session.canResolve([entry]))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tile)
    }

    /// 版本原文的只读预览；删除了文件的一侧与二进制内容只显示说明。
    @ViewBuilder
    private func preview(_ data: Data?, label: String) -> some View {
        if let data, let string = Self.text(data) {
            ConflictTextView(text: .constant(string), editable: false)
                .background(innerTile)
                .accessibilityLabel(label)
        } else {
            placeholder(data == nil ? "conflict.missing" : "conflict.binary")
        }
    }

    /// 内容区里居中的说明文字。
    private func placeholder(_ key: String) -> some View {
        Text(AppLocalization.text(key))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(innerTile)
    }

    /// 读取三方内容；被新的请求取代的结果直接丢弃。
    private func load() async {
        do {
            let loaded = try await session.conflictContents(of: entry)

            guard !Task.isCancelled else { return }

            contents = loaded
            failure = nil
            loadedText = loaded.worktree.flatMap(Self.text)
            text = loadedText ?? ""
        } catch {
            guard !Task.isCancelled else { return }

            failure = AppFailure(error: error, opening: false, location: session.repository)
        }
    }

    /// 保存编辑结果，写入成功后重新载入，让编辑区与磁盘一致。
    private func save(_ contents: ConflictContents) {
        session.saveConflictResolution(text, for: entry, replacing: contents.worktree) {
            reloads += 1
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

    /// 把这一侧的原文导出到用户选择的位置。
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

// MARK: - ConflictBackupsView

/// 冲突向导在当前仓库生成的备份文件与清理入口；没有备份时不占位置。
struct ConflictBackupsView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 备份文件的路径可以选中复制，清理前要确认。
    var body: some View {
        let backups = session.currentConflictBackups

        if !backups.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.text("conflict.backups"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(backups, id: \.self) { path in
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(path)
                }

                Button(AppLocalization.text("conflict.removeBackups")) { session.removeConflictBackups() }
                    .controlSize(.small)
                    .disabled(!session.canWrite)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - ConflictTextView

/// 冲突内容的等宽文本区：版本卡片只读，结果卡片可编辑；大文件交给 NSTextView 排版。
private struct ConflictTextView: NSViewRepresentable {
    /// 把编辑同步回绑定。
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        /// 最新绑定。
        var text: Binding<String>

        /// 保存初始绑定。
        init(text: Binding<String>) {
            self.text = text
        }

        /// 每次编辑后写回绑定。
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            text.wrappedValue = view.string
        }
    }

    /// 显示与编辑的文本。
    @Binding
    var text: String

    /// 是否允许编辑。
    let editable: Bool

    /// 创建同步编辑的协调器。
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    /// 关闭自动替换，保存的内容与输入的字符一致。
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false

        guard let view = scroll.documentView as? NSTextView else {
            return scroll
        }

        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.isRichText = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.textContainerInset = NSSize(width: 4, height: 4)
        view.delegate = context.coordinator
        view.string = text
        view.isEditable = editable
        return scroll
    }

    /// 内容只在与绑定不同时替换，编辑中的光标与撤销记录保持不变。
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.text = $text

        guard let view = scroll.documentView as? NSTextView else { return }

        view.isEditable = editable

        if view.string != text {
            view.string = text
        }
    }
}
