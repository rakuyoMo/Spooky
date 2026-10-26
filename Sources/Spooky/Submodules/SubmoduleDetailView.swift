import SpookyKit
import SwiftUI

// MARK: - SubmoduleDetailView

/// 子模块视图：头部是图标、子模块名与 General | Shared Config | Local Config 分段，下面是设置表格；
/// 配置不完整时整页换成空状态，提供修复与删除。
struct SubmoduleDetailView: View {
    /// 三个分段。
    enum Page: Hashable {
        /// 状态与生效的配置。
        case general

        /// `.gitmodules` 里的设置。
        case shared

        /// 仓库本地配置里的设置。
        case local
    }

    /// 所在窗口的会话。
    let session: RepositorySession

    /// 当前分段，不随仓库保存。
    @State
    private var page = Page.general

    /// 头部固定 52 pt，内容区可滚动。
    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let submodule = session.submodules.selected {
                if submodule.isValid {
                    settings(of: submodule)
                } else {
                    invalidState(submodule)
                }
            } else if session.submodules.isLoaded {
                EmptyStateView(
                    title: AppLocalization.text("submodule.missing"),
                    message: AppLocalization.text("submodule.missing.message", session.submodules.selectedPath ?? ""),
                    symbol: "shippingbox"
                )
                .frame(maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(minWidth: 480, minHeight: 300)
    }
}

// MARK: - Layout

extension SubmoduleDetailView {
    /// 32 pt 图标、子模块名与右侧分段；配置不完整时没有分段。
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 22))
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Text(session.submodules.selected?.name ?? session.submodules.selectedPath ?? "")
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()

            if session.submodules.selected?.isValid ?? false {
                Picker("", selection: $page) {
                    Text(AppLocalization.text("submodule.page.general")).tag(Page.general)
                    Text(AppLocalization.text("submodule.page.shared")).tag(Page.shared)
                    Text(AppLocalization.text("submodule.page.local")).tag(Page.local)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(AppLocalization.text("submodule.page"))
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    /// 当前分段的设置表格。
    private func settings(of submodule: Submodule) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch page {
                case .general:
                    SubmoduleGeneralSettings(session: session, submodule: submodule)

                case .shared:
                    SubmoduleConfigurationSettings(session: session, submodule: submodule, scope: .shared)

                case .local:
                    SubmoduleConfigurationSettings(session: session, submodule: submodule, scope: .local)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 配置不完整的子模块：空状态与修复、删除两个按钮。
    private func invalidState(_ submodule: Submodule) -> some View {
        VStack(spacing: 16) {
            EmptyStateView(
                title: AppLocalization.text("submodule.invalid"),
                message: AppLocalization.text("submodule.invalid.message"),
                symbol: "exclamationmark.triangle"
            )

            HStack(spacing: 8) {
                Button(AppLocalization.text("submodule.repair.submit")) {
                    session.requestSubmodule(.repair(submodule))
                }

                Button(AppLocalization.text("submodule.delete.submit")) {
                    session.requestSubmodule(.delete(submodule))
                }
            }
            .disabled(!session.canWrite)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SubmoduleGeneralSettings

/// General 分段：状态提示、名称、路径、状态、本地改动、检出的版本与指针，以及生效的地址与三个选项。
private struct SubmoduleGeneralSettings: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 显示的子模块。
    let submodule: Submodule

    /// 子模块仓库里远端的地址，只在需要同步时读取。
    @State
    private var remoteURL: String?

    /// 各行依次排列，提示行在最前。
    var body: some View {
        warnings

        RemoteSettingsGroup(title: AppLocalization.text("submodule.group.general"))

        RemoteSettingRow(label: AppLocalization.text("submodule.field.name"), value: submodule.name)
        RemoteSettingRow(label: AppLocalization.text("submodule.field.path"), value: submodule.path)
        RemoteSettingRow(label: AppLocalization.text("submodule.field.status"), value: submodule.state.title)

        if let changes = session.submodules.summaries[submodule.path]?.changes, changes > 0 {
            RemoteSettingRow(
                label: AppLocalization.text("submodule.field.localChanges"),
                value: AppLocalization.text("workspace.changed", changes)
            )
        }

        RemoteSettingRow(
            label: AppLocalization.text("submodule.field.checkedOut"),
            value: checkedOut,
            small: submodule.checkedOut != nil,
            secondary: submodule.checkedOut == nil
        )

        RemoteSettingRow(
            label: AppLocalization.text("submodule.field.pointer"),
            value: submodule.pointer ?? AppLocalization.text("submodule.notAvailable"),
            small: submodule.pointer != nil,
            secondary: submodule.pointer == nil
        )

        RemoteSettingsGroup(title: AppLocalization.text("submodule.group.active"))

        RemoteSettingRow(label: AppLocalization.text("submodule.field.url"), value: submodule.url ?? "", small: true)

        if submodule.needsSynchronizing {
            RemoteSettingRow(
                label: AppLocalization.text("submodule.field.remoteURL"),
                value: submodule.isPopulated ? remoteURL ?? "" : AppLocalization.text("submodule.notInitialized"),
                small: true
            )
            .task(id: submodule) { await loadRemoteURL() }
        }

        RemoteSettingRow(
            label: AppLocalization.text("submodule.field.fetchMode"),
            value: submodule.fetchMode.map(\.title) ?? defaultTitle(SubmoduleFetchMode.onDemand.title)
        )

        RemoteSettingRow(
            label: AppLocalization.text("submodule.field.ignoreMode"),
            value: submodule.ignoreMode.map(\.title) ?? defaultTitle(SubmoduleIgnoreMode.nothing.title)
        )

        RemoteSettingRow(
            label: AppLocalization.text("submodule.field.updateStrategy"),
            value: submodule.updateStrategy.map(\.title) ?? defaultTitle(SubmoduleUpdateStrategy.checkout.title)
        )
    }

    /// 没有初始化与地址需要同步时的提示行，各带一个按钮。
    @ViewBuilder
    private var warnings: some View {
        if submodule.state == .uninitialized {
            SettingWarningRow(
                text: AppLocalization.text("submodule.warning.uninitialized"),
                action: RemoteSettingAction(
                    title: AppLocalization.text("submodule.update.submit"),
                    isEnabled: session.canModify(submodule)
                ) { session.requestSubmodule(.update(submodule)) }
            )
        }

        if submodule.needsSynchronizing {
            SettingWarningRow(
                text: AppLocalization.text("submodule.warning.synchronize"),
                action: RemoteSettingAction(
                    title: AppLocalization.text("submodule.synchronize.submit"),
                    isEnabled: session.canSynchronize(submodule)
                ) { session.requestSubmodule(.synchronize(submodule)) }
            )
        }
    }

    /// 检出的版本：没有初始化、读不到与提交哈希三种写法。
    private var checkedOut: String {
        if submodule.state == .uninitialized {
            return AppLocalization.text("submodule.notInitialized")
        }

        return submodule.checkedOut ?? AppLocalization.text("submodule.notAvailable")
    }

    /// 没有配置时按 Git 的默认值显示，并标出是默认值。
    private func defaultTitle(_ title: String) -> String {
        AppLocalization.text("submodule.default", title)
    }

    /// 读出子模块仓库里远端的地址，与本地配置里的对照。
    private func loadRemoteURL() async {
        guard submodule.isPopulated, let runner = session.runner else {
            return
        }

        remoteURL = try? await RepositorySubmodules(runner: runner).remoteURL(of: submodule)
    }
}

// MARK: - SubmoduleConfigurationSettings

/// Shared Config 与 Local Config 分段：名称、路径、地址与三个选项；共享配置可以改名与移动，本地配置的地址可以同步。
private struct SubmoduleConfigurationSettings: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 显示的子模块。
    let submodule: Submodule

    /// 这一分段对应的配置。
    let scope: SubmoduleConfigurationScope

    /// 各行依次排列。
    var body: some View {
        let settings = scope == .shared ? submodule.shared : submodule.local

        RemoteSettingsGroup(
            title: AppLocalization.text(scope == .shared ? "submodule.group.shared" : "submodule.group.local")
        )

        if scope == .shared {
            RemoteSettingRow(
                label: AppLocalization.text("submodule.field.name"),
                value: submodule.name,
                actions: [action("submodule.action.rename") { session.requestSubmodule(.rename(submodule)) }]
            )

            RemoteSettingRow(
                label: AppLocalization.text("submodule.field.path"),
                value: submodule.path,
                actions: [action("submodule.action.move") { session.requestSubmodule(.move(submodule)) }]
            )
        }

        RemoteSettingRow(
            label: AppLocalization.text("submodule.field.remoteURLConfig"),
            value: settings?.url ?? AppLocalization.text("submodule.noValue"),
            small: settings?.url != nil,
            secondary: settings?.url == nil,
            actions: urlActions
        )

        SubmoduleOptionRow(
            label: AppLocalization.text("submodule.field.fetchMode"),
            value: settings?.fetchRecurseSubmodules,
            choices: SubmoduleFetchMode.allCases.map { ($0.rawValue, $0.title) },
            isEnabled: session.canModify(submodule)
        ) { session.setSubmoduleOption(.fetchRecurseSubmodules, to: $0, for: submodule, in: scope) }

        SubmoduleOptionRow(
            label: AppLocalization.text("submodule.field.ignoreMode"),
            value: settings?.ignore,
            choices: SubmoduleIgnoreMode.allCases.map { ($0.rawValue, $0.title) },
            isEnabled: session.canModify(submodule)
        ) { session.setSubmoduleOption(.ignore, to: $0, for: submodule, in: scope) }

        SubmoduleOptionRow(
            label: AppLocalization.text("submodule.field.updateStrategy"),
            value: settings?.update,
            choices: SubmoduleUpdateStrategy.allCases.map { ($0.rawValue, $0.title) },
            isEnabled: session.canModify(submodule)
        ) { session.setSubmoduleOption(.update, to: $0, for: submodule, in: scope) }
    }

    /// 地址行的按钮：本地地址与共享地址不同时可以同步，两处都可以编辑。
    private var urlActions: [RemoteSettingAction] {
        let edit = action("submodule.action.edit") { session.requestSubmodule(.editURL(submodule, scope)) }

        guard scope == .local, submodule.needsSynchronizing else {
            return [edit]
        }

        let synchronize = RemoteSettingAction(
            title: AppLocalization.text("submodule.synchronize.submit"),
            isEnabled: session.canSynchronize(submodule)
        ) { session.requestSubmodule(.synchronize(submodule)) }

        return [synchronize, edit]
    }

    /// 仓库可写时可用的按钮。
    private func action(_ key: String, perform: @escaping () -> Void) -> RemoteSettingAction {
        RemoteSettingAction(title: AppLocalization.text(key), isEnabled: session.canModify(submodule), perform: perform)
    }
}

// MARK: - SubmoduleOptionRow

/// 选项行：240 pt 宽的次级色标签与弹出菜单；第一项是沿用默认值，配置里认不出的原值另列一项。
private struct SubmoduleOptionRow: View {
    /// 左侧标签。
    let label: String

    /// 配置里的原值；没有配置时为 nil。
    let value: String?

    /// 可选的配置值与标题。
    let choices: [(value: String, title: String)]

    /// 仓库可写时可用。
    let isEnabled: Bool

    /// 选择变化后写入；nil 表示删除这一项。
    let change: (String?) -> Void

    /// 标签与菜单横向排列。
    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 240, alignment: .leading)

            Picker(label, selection: selection) {
                Text(AppLocalization.text("submodule.useDefault")).tag(String?.none)

                Divider()

                ForEach(choices, id: \.value) { choice in
                    Text(choice.title).tag(Optional(choice.value))
                }

                if let unknown {
                    Text(verbatim: unknown).tag(Optional(unknown))
                }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(!isEnabled)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 30)
    }

    /// 选中的配置值：认得出的原值换成对应选项的写法，大小写与布尔写法不同也算同一项。
    private var selection: Binding<String?> {
        Binding(
            get: { matched ?? unknown },
            set: { newValue in
                guard newValue != (matched ?? unknown) else { return }
                change(newValue)
            }
        )
    }

    /// 与原值对应的选项值。
    private var matched: String? {
        guard let value else {
            return nil
        }

        return choices.first { $0.value == value.lowercased() }?.value
            ?? SubmoduleFetchMode(configValue: value).flatMap { mode in choices.first { $0.value == mode.rawValue } }?.value
    }

    /// 认不出的原值，如自定义的更新命令。
    private var unknown: String? {
        guard let value, matched == nil else {
            return nil
        }

        return value
    }
}

// MARK: - Titles

extension SubmoduleState {
    /// 界面上的状态名。
    var title: String {
        switch self {
        case .unknown: AppLocalization.text("submodule.state.unknown")
        case .uninitialized: AppLocalization.text("submodule.state.uninitialized")
        case .clean: AppLocalization.text("submodule.state.clean")
        case .updated: AppLocalization.text("submodule.state.updated")
        case .unmerged: AppLocalization.text("submodule.state.unmerged")
        }
    }
}

extension SubmoduleFetchMode {
    /// 界面上的选项名。
    var title: String {
        switch self {
        case .never: AppLocalization.text("submodule.fetchMode.never")
        case .always: AppLocalization.text("submodule.fetchMode.always")
        case .onDemand: AppLocalization.text("submodule.fetchMode.onDemand")
        }
    }
}

extension SubmoduleIgnoreMode {
    /// 界面上的选项名。
    var title: String {
        switch self {
        case .nothing: AppLocalization.text("submodule.ignoreMode.none")
        case .all: AppLocalization.text("submodule.ignoreMode.all")
        case .untracked: AppLocalization.text("submodule.ignoreMode.untracked")
        case .dirty: AppLocalization.text("submodule.ignoreMode.dirty")
        }
    }
}

extension SubmoduleUpdateStrategy {
    /// 界面上的选项名。
    var title: String {
        switch self {
        case .skip: AppLocalization.text("submodule.updateStrategy.none")
        case .checkout: AppLocalization.text("submodule.updateStrategy.checkout")
        case .rebase: AppLocalization.text("submodule.updateStrategy.rebase")
        case .merge: AppLocalization.text("submodule.updateStrategy.merge")
        }
    }
}
