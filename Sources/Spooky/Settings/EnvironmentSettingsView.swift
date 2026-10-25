import SpookyKit
import SwiftUI

// MARK: - EnvironmentSettingsView

/// Settings → Environment：从登录 shell 读到的环境变量，以及在本机执行 Git 时附加的自定义变量。
///
/// 纵向排列、间距 8 pt：复选框、只读的变量表（只在开启时显示）、自定义变量表与底部的 + / − 操作条，说明这些设置只作用于本机，
/// 最后是检查服务器非交互环境的一栏。
struct EnvironmentSettingsView: View {
    /// 正在编辑的格子；离开一个格子即保存整张表。
    private enum Field: Hashable {
        /// 某一行的变量名。
        case name(UUID)

        /// 某一行的值。
        case value(UUID)
    }

    /// 只读表格里的一个变量，以变量名作为身份。
    private struct ShellVariable: Identifiable {
        /// 变量名。
        let name: String

        /// 变量的值。
        let value: String

        /// 变量名在一份环境里唯一。
        var id: String { name }
    }

    /// 偏好与登录 shell 的读取状态。
    let preferences: LocalExecutionPreferences

    /// 表格里正在编辑的自定义变量；提交编辑或增删一行时整表保存。
    @State
    private var rows: [CustomEnvironmentVariable] = []

    /// 自定义变量表格里选中的行。
    @State
    private var selection = Set<UUID>()

    /// 正在编辑的格子。
    @FocusState
    private var focus: Field?

    /// 自上而下的五部分，页面宽 900 pt。
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                AppLocalization.text("settings.environment.loginShell"),
                isOn: Binding(
                    get: { preferences.usesLoginShell },
                    set: { preferences.setUsesLoginShell($0) }
                )
            )

            if preferences.usesLoginShell {
                loginShellTable
            }

            Text(AppLocalization.text("settings.environment.custom"))

            customTable

            Text(AppLocalization.text("settings.environment.localOnly"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            ServerEnvironmentCheck()
        }
        .padding(20)
        .frame(width: 900, height: 660, alignment: .topLeading)
        .onAppear { rows = preferences.customVariables }
        .onDisappear(perform: save)
    }

    /// 创建 Environment 页。
    ///
    /// - Parameter preferences: 读写的偏好；测试使用独立偏好域的实例。
    init(preferences: LocalExecutionPreferences = .shared) {
        self.preferences = preferences
    }
}

// MARK: - Tables

extension EnvironmentSettingsView {
    /// 登录 shell 的变量，按名称排序，高 200 pt；这次没有读到时在下方说明。
    private var loginShellTable: some View {
        VStack(alignment: .leading, spacing: 4) {
            Table(shellVariables) {
                TableColumn(AppLocalization.text("settings.environment.key")) { Text($0.name) }
                    .width(min: 40, ideal: 260)

                TableColumn(AppLocalization.text("settings.environment.value")) { Text($0.value) }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: false))
            .frame(height: 200)
            .accessibilityLabel(AppLocalization.text("settings.environment.loginShell"))

            if preferences.loginShellState == .failed {
                Text(AppLocalization.text("settings.environment.loginShellFailed"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 可编辑的自定义变量表，底部是 18 pt 高的 + / − 操作条。
    private var customTable: some View {
        VStack(spacing: 0) {
            Table(rows, selection: $selection) {
                TableColumn(AppLocalization.text("settings.environment.key")) { row in
                    cell(row.id, \.name, field: .name(row.id), label: "settings.environment.key")
                }
                .width(min: 40, ideal: 260)

                TableColumn(AppLocalization.text("settings.environment.value")) { row in
                    cell(row.id, \.value, field: .value(row.id), label: "settings.environment.value")
                }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: false))
            .onSubmit(save)
            .onChange(of: focus) { save() }

            Divider()

            actionBar
        }
        .frame(minHeight: 100)
        .overlay(Rectangle().stroke(AppPalette.color("general_border_color")))
    }

    /// 新增一行与删除选中的行；没有选中的行时 − 不可用。
    private var actionBar: some View {
        HStack(spacing: 8) {
            barButton("plus", label: "settings.environment.add", action: addRow)

            barButton("minus", label: "settings.environment.remove", action: removeRows)
                .disabled(selection.isEmpty)

            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .frame(height: 18)
    }

    /// 按名称排序的登录 shell 变量。
    private var shellVariables: [ShellVariable] {
        preferences.loginShellVariables
            .map { ShellVariable(name: $0.key, value: $0.value) }
            .sorted { $0.name < $1.name }
    }

    /// 表格里的一个可编辑格子。
    private func cell(
        _ id: UUID,
        _ keyPath: WritableKeyPath<CustomEnvironmentVariable, String>,
        field: Field,
        label key: String
    ) -> some View {
        TextField(
            "",
            text: Binding(
                get: { rows.first { $0.id == id }?[keyPath: keyPath] ?? "" },
                set: { text in
                    guard let index = rows.firstIndex(where: { $0.id == id }) else { return }

                    rows[index][keyPath: keyPath] = text
                }
            )
        )
        .textFieldStyle(.plain)
        .focused($focus, equals: field)
        .accessibilityLabel(AppLocalization.text(key))
    }

    /// 操作条上 16 pt 的图标按钮。
    private func barButton(_ symbol: String, label key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(AppLocalization.text(key))
        .accessibilityLabel(AppLocalization.text(key))
    }
}

// MARK: - Actions

extension EnvironmentSettingsView {
    /// 在末尾加一个空行，选中它并开始编辑变量名。
    private func addRow() {
        let row = CustomEnvironmentVariable(name: "", value: "")

        rows.append(row)
        selection = [row.id]
        focus = .name(row.id)
        save()
    }

    /// 删除选中的行。
    private func removeRows() {
        rows.removeAll { selection.contains($0.id) }
        selection = []
        save()
    }

    /// 把整张表交给偏好保存；没有变化时偏好不会重复写入。
    private func save() {
        preferences.saveCustomVariables(rows)
    }
}
