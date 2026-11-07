import AppKit
import SpookyKit
import SwiftUI

// MARK: - ConflictVersionMenu

/// 版本卡片的菜单：打开、指定程序打开，导出，与另一侧比较、与共同祖先比较。
///
/// 这一侧删除了文件时打开与导出不可用；比较用冲突的 stage 对象，缺少任一版本时不可用。
struct ConflictVersionMenu: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 冲突文件。
    let entry: StatusEntry

    /// 菜单所在的一侧。
    let side: ConflictSide

    /// 这一侧的原文；这一侧删除了文件时为 nil。
    let data: Data?

    /// 三组菜单项，按钮是省略号图标。
    var body: some View {
        Menu {
            openItems

            Divider()

            Button(exportTitle) {
                if let data { export(data) }
            }
            .disabled(data == nil)

            Divider()

            Button(AppLocalization.text("conflict.compareOther")) { compareOther() }
                .disabled(!session.canCompare([entry], .oursToTheirs))

            Button(AppLocalization.text("conflict.compareBase")) { session.compare([entry], baseComparison) }
                .disabled(!session.canCompare([entry], baseComparison))
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(AppLocalization.text("conflict.versionMenu", name))
    }
}

// MARK: - Private

extension ConflictVersionMenu {
    /// 这一侧的引用名。
    private var name: String {
        ConflictVersionCard.name(of: side, in: session)
    }

    /// 导出的标题；删除了文件的一侧只写动作名。
    private var exportTitle: String {
        data == nil
            ? AppLocalization.text("conflict.export.missing")
            : AppLocalization.text("conflict.export", name)
    }

    /// 与共同祖先比较时用的比较方式。
    private var baseComparison: WorkingCopyComparison {
        side == .ours ? .oursToBase : .theirsToBase
    }

    /// 打开与指定程序打开；删除了文件的一侧两项都不可用，只显示动作名。
    @ViewBuilder
    private var openItems: some View {
        if let data {
            Button(AppLocalization.text("conflict.open", name)) { open(data, with: nil) }

            Menu(AppLocalization.text("conflict.openWith", name)) {
                OpenWithMenuItems(
                    names: [entry.path],
                    open: { open(data, with: $0) },
                    other: { RepositorySession.chooseApplication { open(data, with: $0) } }
                )
            }
        } else {
            Button(AppLocalization.text("conflict.open.missing")) { }
                .disabled(true)

            Button(AppLocalization.text("conflict.openWith.missing")) { }
                .disabled(true)
        }
    }

    /// 与另一侧比较：右侧总是这张卡片的版本。
    private func compareOther() {
        guard side == .theirs else {
            session.compare([entry], .oursToTheirs)
            return
        }

        guard let stages = entry.conflict else { return }

        session.openDiffTool(
            [ComparedFile(path: entry.path, originalPath: nil)],
            left: .blob(stages.ours),
            right: .blob(stages.theirs),
            names: (
                AppLocalization.text("externalTool.side.mine"),
                AppLocalization.text("externalTool.side.theirs")
            )
        )
    }

    /// 用默认程序或指定的程序打开这一侧的原文；副本放在会话的本机缓存里，服务器路径不交给本机程序。
    ///
    /// - Parameters:
    ///   - data: 这一侧的原文。
    ///   - application: 打开它的程序；nil 表示默认程序。
    private func open(_ data: Data, with application: URL?) {
        guard let cache = session.fileCache else { return }

        let report = session.onFailure
        let repository = session.repository

        do {
            let url = try cache.store(data, named: entry.path)

            Task {
                do {
                    try await RepositorySession.open([url], with: application)
                } catch {
                    report?(AppFailure(error: error, opening: false, location: repository))
                }
            }
        } catch {
            report?(AppFailure(error: error, opening: false, location: repository))
        }
    }

    /// 把这一侧的原文导出到用户选择的位置；服务器上的版本在载入时已经取到本机。
    private func export(_ data: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = RepositorySession.fileName(entry.path)

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
