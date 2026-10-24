import SwiftUI

// MARK: - AutoFetchSettingsRow

/// Settings → General 里自动获取间隔的一行：从只手动获取到每小时一次。
struct AutoFetchSettingsRow: View {
    /// 自动获取的间隔，单位秒；0 表示只手动获取。
    @AppStorage(RepositoryAutoFetch.intervalKey)
    private var interval = RepositoryAutoFetch.defaultInterval

    /// 右对齐的标签与 278 pt 宽的弹出菜单。
    var body: some View {
        GridRow {
            Text(AppLocalization.text("settings.autoFetch"))
                .gridColumnAlignment(.trailing)

            Picker("", selection: $interval) {
                ForEach(RepositoryAutoFetch.intervals, id: \.self) { seconds in
                    Text(Self.title(seconds)).tag(seconds)
                }
            }
            .labelsHidden()
            .frame(width: 278)
            .accessibilityLabel(AppLocalization.text("settings.autoFetch"))
        }
    }

    /// 间隔的显示名称。
    private static func title(_ seconds: Int) -> String {
        switch seconds {
        case 0: AppLocalization.text("settings.autoFetch.never")
        case 3600: AppLocalization.text("settings.autoFetch.hour")
        default: AppLocalization.text("settings.autoFetch.minutes", seconds / 60)
        }
    }
}
