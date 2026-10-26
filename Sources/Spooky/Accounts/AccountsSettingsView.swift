import SpookyKit
import SwiftUI

// MARK: - AccountsSettingsView

/// Accounts 设置页：已登录账号的服务、实例地址与用户名，底部可以添加、移除与重新认证。
///
/// 令牌被托管服务拒绝过的账号在用户名旁标出，需要重新认证。
struct AccountsSettingsView: View {
    /// App 共用的账号。
    var accounts = HostingAccounts.shared

    /// 选中的账号。
    @State
    private var selection: HostingAccount.ID?

    /// 正在添加或重新认证的对话框。
    @State
    private var dialog: AccountDialog.Purpose?

    /// 等待确认移除的账号。
    @State
    private var removing: HostingAccount?

    /// 表格、操作条与说明。
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                table

                Divider()

                actions
            }
            .overlay(Rectangle().stroke(AppPalette.color("general_border_color")))

            Text(AppLocalization.text("accounts.help"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 900, height: 381)
        .sheet(item: $dialog) { purpose in
            AccountDialog(purpose: purpose, accounts: accounts) { dialog = nil }
        }
        .alert(
            AppLocalization.text("accounts.remove.title"),
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            presenting: removing
        ) { account in
            Button(AppLocalization.text("accounts.remove.submit"), role: .destructive) { accounts.remove(account) }
            Button(AppLocalization.text("action.cancel"), role: .cancel) { removing = nil }
        } message: { account in
            Text(AppLocalization.text("accounts.remove.message", account.username, account.instance.displayName))
        }
    }
}

// MARK: - Private

extension AccountsSettingsView {
    /// 服务、实例与用户名三列。
    private var table: some View {
        Table(accounts.items, selection: $selection) {
            TableColumn(AppLocalization.text("accounts.service")) { account in
                Text(Self.serviceTitle(account.instance))
            }

            TableColumn(AppLocalization.text("accounts.instance")) { account in
                Text(account.instance.displayName)
                    .textSelection(.enabled)
            }

            TableColumn(AppLocalization.text("accounts.username")) { account in
                HStack(spacing: 4) {
                    Text(account.username)

                    if account.needsReauthentication {
                        Label(
                            AppLocalization.text("accounts.needsReauthentication"),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                        .font(.system(size: 11))
                    }
                }
            }
        }
        .alternatingRowBackgrounds(.disabled)
        .overlay {
            if accounts.items.isEmpty {
                Text(AppLocalization.text("accounts.empty"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 底部 20 pt 的操作条：添加菜单、移除与重新认证；没有选中账号时后两项不可用。
    private var actions: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach(AccountDialog.Kind.allCases, id: \.self) { kind in
                    Button(kind.menuTitle) { dialog = .add(kind) }
                }
            } label: {
                Image(systemName: "plus").frame(width: 24, height: 20)
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(AppLocalization.text("accounts.add"))

            Button {
                removing = selected
            } label: {
                Image(systemName: "minus").frame(width: 24, height: 20)
            }
            .disabled(selected == nil)
            .accessibilityLabel(AppLocalization.text("accounts.remove"))

            Spacer(minLength: 0)

            Button(AppLocalization.text("accounts.reauthenticate")) {
                selected.map { dialog = .reauthenticate($0) }
            }
            .disabled(selected == nil)
            .padding(.trailing, 8)
        }
        .buttonStyle(.borderless)
        .frame(height: 22)
    }

    /// 选中的账号。
    private var selected: HostingAccount? {
        accounts.items.first { $0.id == selection }
    }

    /// 服务名：GitHub、GitLab 与私有部署的 GitLab。
    static func serviceTitle(_ instance: HostingInstance) -> String {
        switch instance.service {
        case .github: AppLocalization.text("accounts.kind.github")
        case .gitlab: AppLocalization.text(instance.isSelfManaged ? "accounts.kind.gitlabSelfManaged" : "accounts.kind.gitlab")
        }
    }
}
