import Foundation

// MARK: - ServerConfirmation

/// 服务器仓库里删除或覆盖文件前的确认：确认框里可以勾选不再提醒，Settings → General 逐项列出并可以重新打开。
///
/// 丢弃块或行与本机仓库共用 “Warn when discarding changes in a chunk” 这一项。
enum ServerConfirmation: CaseIterable {
    /// 丢弃块或行，覆盖服务器上的文件内容。
    case discardChunks

    /// 丢弃所选文件或全部改动：已跟踪的文件被覆盖，未跟踪文件移进服务器的废纸篓，没有废纸篓时永久删除。
    case discardChanges

    /// 服务器上没有可用的废纸篓时永久删除文件。
    case deletePermanently

    /// 把文件恢复到某个版本，覆盖服务器上的文件。
    case restoreFiles

    /// 偏好键：值为 false 时不再确认，没有设置时确认。
    var key: String {
        switch self {
        case .discardChunks: WorkingCopyPreferences.warnsDiscardingChunks
        case .discardChanges: "serverWarnsDiscardingChanges"
        case .deletePermanently: "serverWarnsDeletingPermanently"
        case .restoreFiles: "serverWarnsRestoringFiles"
        }
    }

    /// Settings → General 里这一项的文案键。
    var titleKey: String {
        switch self {
        case .discardChunks: "settings.warnDiscardingChunks"
        case .discardChanges: "settings.warnDiscardingOnServer"
        case .deletePermanently: "settings.warnDeletingOnServer"
        case .restoreFiles: "settings.warnRestoringOnServer"
        }
    }

    /// 这项确认是否打开。
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - Server Confirmation

extension RepositorySession {
    /// 服务器仓库的删除与覆盖先确认；这项确认已经关掉时直接执行。
    ///
    /// - Parameters:
    ///   - confirmation: 确认的种类，决定读写哪个偏好。
    ///   - title: 确认框的标题，也是确认按钮的标题。
    ///   - message: 写明在服务器上覆盖、移进废纸篓或永久删除的说明。
    ///   - action: 确认后执行的操作。
    func confirmOnServer(
        _ confirmation: ServerConfirmation,
        title: String,
        message: String,
        action: @escaping () -> Void
    ) {
        guard confirmation.isEnabled else {
            action()
            return
        }

        onServerConfirm?(confirmation, title, message, action)
    }
}
