import SpookyKit
import SwiftUI

// MARK: - EnvironmentSettingsView

/// Settings → Environment：从登录 shell 读到的环境变量，以及在本机执行 Git 时附加的自定义变量。
///
/// 纵向排列、间距 8 pt：复选框、只读的变量表（只在开启时显示）、自定义变量表与底部的 + / − 操作条，说明这些设置只作用于本机，
/// 最后是检查服务器非交互环境的一栏。
struct EnvironmentSettingsView: View {
    /// 偏好与登录 shell 的读取状态。
    let preferences: LocalExecutionPreferences

    /// 表格里正在编辑的自定义变量；提交编辑或增删一行时整表保存。
    @State
    private var rows: [CustomEnvironmentVariable] = []

    /// 自定义变量表格里选中的行。
    @State
    private var selection = Set<UUID>()

    /// 新增后要开始编辑变量名的行。
    @State
    private var editingRow: Int?

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
            EnvironmentTable(
                variables: shellVariables,
                label: AppLocalization.text("settings.environment.loginShell")
            )
            .frame(height: 200)
            .overlay(Rectangle().stroke(AppPalette.color("general_border_color")))

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
            EnvironmentTable(
                variables: rows.map { EnvironmentTable.Variable(name: $0.name, value: $0.value) },
                selection: selectedRows,
                commit: commit,
                editRequest: $editingRow,
                label: AppLocalization.text("settings.environment.custom")
            )

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
    private var shellVariables: [EnvironmentTable.Variable] {
        preferences.loginShellVariables
            .map { EnvironmentTable.Variable(name: $0.key, value: $0.value) }
            .sorted { $0.name < $1.name }
    }

    /// 自定义变量表里选中的行号，与按身份记下的选区互相换算；超出现有行的行号忽略。
    private var selectedRows: Binding<IndexSet> {
        Binding(
            get: { IndexSet(rows.indices.filter { selection.contains(rows[$0].id) }) },
            set: { indexes in
                selection = Set(indexes.filter(rows.indices.contains).map { rows[$0].id })
            }
        )
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
        editingRow = rows.count - 1
        save()
    }

    /// 结束编辑一个格子时改写那一行，再保存整张表。
    private func commit(row: Int, column: EnvironmentTable.Column, text: String) {
        guard rows.indices.contains(row) else {
            return
        }

        switch column {
        case .name: rows[row].name = text
        case .value: rows[row].value = text
        }

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
