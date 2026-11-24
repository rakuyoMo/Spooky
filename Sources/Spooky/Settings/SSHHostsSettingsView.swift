import AppKit
import SpookyKit
import SwiftUI

// MARK: - SSHHostsSettingsView

/// SSH Hosts 设置页：`~/.ssh/config` 里的主机别名与各自的服务器地址、用户名、端口和私钥路径，底部可以添加、删除与编辑。
///
/// 页面出现与 App 回到前台时重新读取文件；读写失败的原因写在说明下方。
struct SSHHostsSettingsView: View {
    /// 表格里的一行：别名与它在列表里的位置。
    private struct Row: Identifiable {
        /// 别名在列表里的位置。
        let id: Int

        /// 这一行的别名。
        let alias: SSHHostAlias
    }

    /// 等待确认的删除。
    private struct Deletion {
        /// 要删除的一行。
        let row: Row

        /// 点下删除时列表里的配置。
        let listed: SSHConfigFile
    }

    /// 配置文件的读写状态。
    @State
    private var model: SSHHostsModel

    /// 等待确认的删除。
    @State
    private var deleting: Deletion?

    /// 表格、操作条、说明与读写失败的原因。
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                table

                Divider()

                actions
            }
            .overlay(Rectangle().stroke(AppPalette.color("general_border_color")))

            Text(AppLocalization.text("sshHosts.help"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let failure = model.failure {
                SettingsFailureView(title: Self.title(of: failure), details: Self.details(of: failure))
            }
        }
        .padding(20)
        .frame(width: 900, height: 381)
        .alert(
            AppLocalization.text("sshHosts.delete.title"),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            presenting: deleting
        ) { deletion in
            Button(AppLocalization.text("sshHosts.delete.submit"), role: .destructive) { delete(deletion) }
            Button(AppLocalization.text("action.cancel"), role: .cancel) { deleting = nil }
        } message: { deletion in
            Text(AppLocalization.text("sshHosts.delete.message", deletion.row.alias.alias))
        }
        .onAppear { model.reload() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.reload()
        }
    }

    /// 创建 SSH Hosts 页。
    ///
    /// - Parameter model: 配置文件的读写状态；测试传入读写临时文件的状态。
    init(model: SSHHostsModel = SSHHostsModel()) {
        _model = State(initialValue: model)
    }
}

// MARK: - Private

extension SSHHostsSettingsView {
    /// 列表里的各行。
    private var rows: [Row] {
        model.file.aliases.enumerated().map { Row(id: $0.offset, alias: $0.element) }
    }

    /// 选中的一行。
    private var selected: Row? {
        rows.first { $0.id == model.selection }
    }

    /// 文件读不出：列表不是文件现在的内容，不能在它上面增删改，也不能说没有别名。
    private var isUnreadable: Bool {
        if case .read = model.failure { true } else { false }
    }

    /// 别名、服务器地址、用户名、端口与私钥路径五列。
    private var table: some View {
        Table(rows, selection: $model.selection) {
            TableColumn(AppLocalization.text("sshHosts.column.alias")) { row in
                Text(row.alias.alias)
            }

            TableColumn(AppLocalization.text("sshHosts.column.hostName")) { row in
                Text(row.alias.hostName)
            }

            TableColumn(AppLocalization.text("sshHosts.column.user")) { row in
                Text(row.alias.user)
            }

            TableColumn(AppLocalization.text("sshHosts.column.port")) { row in
                Text(row.alias.port)
            }
            .width(60)

            TableColumn(AppLocalization.text("sshHosts.column.identityFile")) { row in
                Text(row.alias.identityFile)
                    .truncationMode(.middle)
                    .help(row.alias.identityFile)
            }
        }
        .alternatingRowBackgrounds(.disabled)
        .accessibilityIdentifier("ssh-hosts")
        .overlay {
            if rows.isEmpty, !isUnreadable {
                Text(AppLocalization.text("sshHosts.empty"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 底部 22 pt 的操作条：添加、删除与编辑；没有选中别名时后两项不可用，文件读不出时三项都不可用。
    private var actions: some View {
        HStack(spacing: 0) {
            Button {
                edit(nil)
            } label: {
                Image(systemName: "plus").frame(width: 24, height: 20)
            }
            .disabled(isUnreadable)
            .accessibilityLabel(AppLocalization.text("sshHosts.add"))

            Button {
                deleting = selected.map { Deletion(row: $0, listed: model.file) }
            } label: {
                Image(systemName: "minus").frame(width: 24, height: 20)
            }
            .disabled(selected == nil || isUnreadable)
            .accessibilityLabel(AppLocalization.text("sshHosts.delete.title"))

            Spacer(minLength: 0)

            Button(AppLocalization.text("sshHosts.edit")) { edit(selected) }
                .disabled(selected == nil || isUnreadable)
                .padding(.trailing, 8)
        }
        .buttonStyle(.borderless)
        .frame(height: 22)
    }

    /// 失败说明的标题。
    private static func title(of failure: SSHHostsModel.Failure) -> String {
        switch failure {
        case .read: AppLocalization.text("sshHosts.error.read")
        case .write: AppLocalization.text("sshHosts.error.write")
        case .changed: AppLocalization.text("sshHosts.error.changed")
        }
    }

    /// 失败说明的正文：系统给出的原因，或文件被改过时的处理办法。
    private static func details(of failure: SSHHostsModel.Failure) -> String {
        switch failure {
        case .read(let reason), .write(let reason): reason
        case .changed: AppLocalization.text("sshHosts.error.changed.help")
        }
    }

    /// 在设置窗口上打开对话框：给了一行时编辑它，没有时添加别名。
    ///
    /// 对话框开着时列表可能重新读取，保存按打开时的配置核对。
    private func edit(_ row: Row?) {
        let listed = model.file

        SSHHostEditor.present(row?.alias, at: row?.id, in: listed, on: NSApp.keyWindow) { alias in
            save(alias, at: row?.id, from: listed)
        }
    }

    /// 写入对话框里填的别名：编辑的原位更新，添加的写进文件后选中它。
    private func save(_ alias: SSHHostAlias, at index: Int?, from listed: SSHConfigFile) {
        guard let index else {
            var added: Int? = nil

            if model.save(from: listed, { added = $0.add(alias) }) {
                model.selection = added
            }

            return
        }

        model.save(from: listed) { $0.replace(at: index, with: alias) }
    }

    /// 确认后删除别名，其它主机与注释留在文件里。
    private func delete(_ deletion: Deletion) {
        deleting = nil

        if model.save(from: deletion.listed, { $0.remove(at: deletion.row.id) }) {
            model.selection = nil
        }
    }
}
