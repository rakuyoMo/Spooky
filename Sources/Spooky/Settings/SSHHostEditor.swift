import AppKit
import SpookyKit
import SwiftUI

// MARK: - SSHHostEditor

/// 添加或编辑主机别名的对话框：别名、服务器地址、用户名、端口与私钥路径。
///
/// 只有别名必填，留空的选项不写进配置。各项保存前去掉首尾的空白；
/// 值不合规、别名与文件里别的主机重名时不能保存，原因显示在错误区。
struct SSHHostEditor: View {
    /// 编辑中的副本。
    @State
    private var alias: SSHHostAlias

    /// 编辑的别名在列表里的位置；添加时为 nil。
    let index: Int?

    /// 打开对话框时的配置，用来检查重名。
    let file: SSHConfigFile

    /// 保存回调。
    let onSave: (SSHHostAlias) -> Void

    /// 关闭对话框。
    let close: () -> Void

    /// 对话框骨架里放标签右对齐的五行表单。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text(index == nil ? "sshHosts.add" : "sshHosts.update.title"),
            message: AppLocalization.text(index == nil ? "sshHosts.create.message" : "sshHosts.update.message"),
            submitTitle: AppLocalization.text(index == nil ? "sshHosts.create.submit" : "sshHosts.update.submit"),
            error: Self.problem(of: trimmed, at: index, in: file),
            canSubmit: Self.canSave(trimmed, at: index, in: file),
            cancel: close,
            submit: {
                onSave(trimmed)
                close()
            }
        ) {
            DialogForm {
                field("sshHosts.alias", text: $alias.alias)
                field("sshHosts.hostName", text: $alias.hostName)
                field("sshHosts.user", text: $alias.user)
                field("sshHosts.port", text: $alias.port)
                field("sshHosts.identityFile", text: $alias.identityFile)
            }
        }
    }

    /// 以别名的副本创建对话框。
    ///
    /// - Parameters:
    ///   - alias: 要编辑的别名；添加时是各项都空的别名。
    ///   - index: 编辑的别名在列表里的位置；添加时为 nil。
    ///   - file: 打开对话框时的配置。
    ///   - onSave: 保存回调。
    ///   - close: 关闭对话框。
    init(
        alias: SSHHostAlias,
        index: Int?,
        file: SSHConfigFile,
        onSave: @escaping (SSHHostAlias) -> Void,
        close: @escaping () -> Void
    ) {
        _alias = State(initialValue: alias)
        self.index = index
        self.file = file
        self.onSave = onSave
        self.close = close
    }
}

// MARK: - Rules

extension SSHHostEditor {
    /// 别名能否保存：填了别名，各项的值合规，别名没有与文件里别的主机重名。
    ///
    /// - Parameters:
    ///   - alias: 去掉首尾空白之后的别名。
    ///   - index: 编辑的别名在列表里的位置；添加时为 nil。
    ///   - file: 用来检查重名的配置。
    static func canSave(_ alias: SSHHostAlias, at index: Int?, in file: SSHConfigFile) -> Bool {
        alias.invalidField == nil && !file.containsHost(named: alias.alias, except: index)
    }

    /// 显示在错误区的原因；能保存或还没有填别名时为 nil。
    ///
    /// - Parameters:
    ///   - alias: 去掉首尾空白之后的别名。
    ///   - index: 编辑的别名在列表里的位置；添加时为 nil。
    ///   - file: 用来检查重名的配置。
    static func problem(of alias: SSHHostAlias, at index: Int?, in file: SSHConfigFile) -> String? {
        guard !alias.alias.isEmpty else {
            return nil
        }

        switch alias.invalidField {
        case .alias: return AppLocalization.text("sshHosts.invalid.alias")
        case .hostName: return AppLocalization.text("sshHosts.invalid.hostName")
        case .user: return AppLocalization.text("sshHosts.invalid.user")
        case .port: return AppLocalization.text("sshHosts.invalid.port")
        case .identityFile: return AppLocalization.text("sshHosts.invalid.identityFile")
        case nil: break
        }

        return file.containsHost(named: alias.alias, except: index)
            ? AppLocalization.text("sshHosts.invalid.duplicate")
            : nil
    }
}

// MARK: - Presenting

extension SSHHostEditor {
    /// 在设置窗口上以 sheet 打开对话框；没有窗口时不打开。
    ///
    /// - Parameters:
    ///   - alias: 要编辑的别名；为 nil 时添加别名。
    ///   - index: 编辑的别名在列表里的位置；添加时为 nil。
    ///   - file: 打开对话框时的配置。
    ///   - window: 设置窗口。
    ///   - save: 保存回调。
    @MainActor
    static func present(
        _ alias: SSHHostAlias?,
        at index: Int?,
        in file: SSHConfigFile,
        on window: NSWindow?,
        save: @escaping (SSHHostAlias) -> Void
    ) {
        guard let window else {
            return
        }

        DialogWindow.present(on: window) { close in
            SSHHostEditor(
                alias: alias ?? SSHHostAlias(alias: ""),
                index: index,
                file: file,
                onSave: save,
                close: close
            )
        }
    }
}

// MARK: - Private

extension SSHHostEditor {
    /// 各项去掉首尾空白之后的别名，校验与保存都用它。
    private var trimmed: SSHHostAlias {
        SSHHostAlias(
            alias: alias.alias.trimmingCharacters(in: .whitespacesAndNewlines),
            hostName: alias.hostName.trimmingCharacters(in: .whitespacesAndNewlines),
            user: alias.user.trimmingCharacters(in: .whitespacesAndNewlines),
            port: alias.port.trimmingCharacters(in: .whitespacesAndNewlines),
            identityFile: alias.identityFile.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// 一行标签与输入框。
    private func field(_ label: String, text: Binding<String>) -> some View {
        DialogFormRow(label: AppLocalization.text(label)) {
            TextField("", text: text)
        }
    }
}
