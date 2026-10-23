import AppKit
import SpookyKit
import SwiftUI

// MARK: - SettingsWindowController

/// 设置窗口采用原生工具栏式页签，单例入口为 ⌘,。
@MainActor
final class SettingsWindowController: NSWindowController {
    /// 页签选择变化时同步窗口标题。
    private var selectionObservation: NSKeyValueObservation?

    /// 创建仅含本里程碑设置的窗口，外观继承系统。
    init() {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar

        for (key, symbol, view) in [
            ("settings.general", "gearshape", AnyView(GeneralSettingsView())),
            ("settings.text", "character.cursor.ibeam", AnyView(TextSettingsView())),
            ("settings.editor", "square.and.pencil", AnyView(EditorSettingsView())),
            ("settings.themes", "paintbrush", AnyView(ThemesSettingsView())),
            ("settings.profiles", "rectangle.stack.person.crop", AnyView(UserProfilesSettingsView())),
        ] {
            let controller = NSHostingController(rootView: view)
            let tab = NSTabViewItem(viewController: controller)
            tab.label = AppLocalization.text(key)
            tab.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tab.label)
            tabs.addTabViewItem(tab)
        }

        let window = NSWindow(contentViewController: tabs)
        window.title = AppLocalization.text("settings.title")
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 900, height: 450))
        window.center()
        super.init(window: window)

        selectionObservation = tabs.observe(\.selectedTabViewItemIndex, options: [.initial, .new]) { [weak window] tabs, _ in
            MainActor.assumeIsolated {
                guard tabs.tabViewItems.indices.contains(tabs.selectedTabViewItemIndex) else { return }
                window?.title = tabs.tabViewItems[tabs.selectedTabViewItemIndex].label
            }
        }
    }

    /// 设置窗口只由代码构建。
    required init?(coder _: NSCoder) { nil }
}

// MARK: - GeneralSettingsView

/// 通用设置立即生效，候选仅显示本机已安装的受支持终端。
private struct GeneralSettingsView: View {
    /// 偏好只保存终端 Bundle Identifier。
    @AppStorage("terminalApplication")
    private var terminal = TerminalApplication.terminal.rawValue

    /// 单次补丁的警告阈值，单位为 1000 字节。
    @AppStorage("diffWarningKilobytes")
    private var diffWarning = WorkingCopyOperations.defaultWarningKilobytes

    /// 历史每页条数固定为四个档位。
    @AppStorage("historyPageSize")
    private var historyPageSize = 100

    /// 创建和发布分支时实时规范引用名。
    @AppStorage("cleanRefNames")
    private var cleanRefNames = true

    /// 检出、拉取与合并被本地改动挡住时询问是否先储藏。
    @AppStorage("offerAutoStash")
    private var offerAutoStash = true

    /// 冲突向导覆盖冲突文件之前是否先保留备份。
    @AppStorage(RepositorySession.keepsConflictBackupsKey)
    private var keepsConflictBackups = false

    /// General 表单的控件列固定为 278 pt。
    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            terminalRow

            GridRow {
                Text(AppLocalization.text("working.diffThreshold"))
                    .gridColumnAlignment(.trailing)
                TextField("", value: $diffWarning, format: .number.grouping(.never))
                    .frame(width: 100, alignment: .leading)
                    .accessibilityLabel(AppLocalization.text("working.diffThreshold"))
                    .onChange(of: diffWarning) { diffWarning = max(0, min(diffWarning, 268_435)) }
            }

            GridRow {
                Text(AppLocalization.text("history.pageSize"))
                Picker("", selection: $historyPageSize) {
                    ForEach([100, 200, 500, 1000], id: \.self) {
                        Text(AppLocalization.text("history.commitCount", $0)).tag($0)
                    }
                }
                .labelsHidden()
                .frame(width: 278)
                .accessibilityLabel(AppLocalization.text("history.pageSize"))
            }

            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Toggle(AppLocalization.text("stash.offerAutoStash"), isOn: $offerAutoStash)
                    .frame(width: 278, alignment: .leading)
            }

            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Toggle(AppLocalization.text("branch.cleanNames"), isOn: $cleanRefNames)
                    .frame(width: 278, alignment: .leading)
            }

            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Toggle(AppLocalization.text("conflict.keepBackups"), isOn: $keepsConflictBackups)
                    .frame(width: 278, alignment: .leading)
            }

            WorkingCopySettingsRows()
        }
        .padding(40)
        .frame(width: 900, height: 380, alignment: .top)
    }
}

// MARK: - Private

extension GeneralSettingsView {
    /// 终端选择行，每个候选显示应用图标与名称。
    private var terminalRow: some View {
        GridRow {
            Text(AppLocalization.text("settings.terminal"))
                .gridColumnAlignment(.trailing)

            Picker(AppLocalization.text("settings.terminal"), selection: $terminal) {
                ForEach(TerminalApplication.allCases.filter { $0.applicationURL != nil }) { application in
                    HStack(spacing: 8) {
                        if let url = application.applicationURL {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: 16, height: 16)
                                .accessibilityHidden(true)
                        }

                        Text(application.displayName)
                    }
                    .tag(application.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: 278)
            .accessibilityIdentifier("terminal-application")
        }
    }
}
