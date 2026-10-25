import Observation
import Sparkle
import SwiftUI

// MARK: - UpdatesSettingsView

/// Settings → Updates：更新通道、自动检查与自动下载、检查间隔，以及最近一次检查的时间。
///
/// 通道存在 App 自己的偏好里，其余各项直接读写 Sparkle 的更新器，与它的计划和更新窗口保持一致。
struct UpdatesSettingsView: View {
    /// 自动检查的间隔，单位秒：每小时、每天、每周。
    private static let intervals: [TimeInterval] = [3600, 86_400, 604_800]

    /// 所选的更新通道，保存 `UpdateChannel.rawValue`。
    @AppStorage(UpdateChannel.key)
    private var channel = UpdateChannel.stable.rawValue

    /// 更新器各项设置的当前值，随 Sparkle 的改动刷新。
    @State
    private var state = UpdaterState(updater: UpdateController.shared.updater)

    /// 通道一组，与下方的检查设置之间用分隔线隔开；标签右对齐，控件列 250 pt。
    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            channelRow

            Divider()
                .gridCellUnsizedAxes(.horizontal)

            checkRows
        }
        .padding(40)
        .frame(width: 900, alignment: .top)
    }
}

// MARK: - Private

extension UpdatesSettingsView {
    /// 更新通道的弹出菜单。
    private var channelRow: some View {
        GridRow {
            Text(AppLocalization.text("updates.channel"))
                .gridColumnAlignment(.trailing)

            Picker("", selection: $channel) {
                ForEach(UpdateChannel.allCases) {
                    Text($0.title).tag($0.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: 250)
            .accessibilityLabel(AppLocalization.text("updates.channel"))
        }
    }

    /// 自动检查、自动下载、检查间隔与最近一次检查的时间。
    @ViewBuilder
    private var checkRows: some View {
        let updater = state.updater

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Toggle(
                AppLocalization.text("updates.automaticChecks"),
                isOn: Binding(
                    get: { state.automaticallyChecks },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                )
            )
            .frame(width: 250, alignment: .leading)
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            // 自动下载依赖自动检查；Bundle 所在位置不能写入时 Sparkle 也不允许自动安装
            Toggle(
                AppLocalization.text("updates.automaticDownloads"),
                isOn: Binding(
                    get: { state.automaticallyDownloads },
                    set: { updater.automaticallyDownloadsUpdates = $0 }
                )
            )
            .frame(width: 250, alignment: .leading)
            .disabled(!state.automaticallyChecks || !state.allowsAutomaticUpdates)
        }

        intervalRow

        lastCheckRow
    }

    /// 自动检查间隔的弹出菜单；关闭自动检查时禁用。
    private var intervalRow: some View {
        let updater = state.updater

        return GridRow {
            Text(AppLocalization.text("updates.interval"))
                .gridColumnAlignment(.trailing)

            Picker(
                "",
                selection: Binding(
                    get: { state.checkInterval },
                    set: { updater.updateCheckInterval = $0 }
                )
            ) {
                ForEach(Self.intervals, id: \.self) {
                    Text(Self.intervalTitle($0)).tag($0)
                }
            }
            .labelsHidden()
            .frame(width: 250)
            .disabled(!state.automaticallyChecks)
            .accessibilityLabel(AppLocalization.text("updates.interval"))
        }
    }

    /// 最近一次检查的时间；从未检查时以次要颜色显示 Never。
    private var lastCheckRow: some View {
        GridRow {
            Text(AppLocalization.text("updates.lastCheck"))
                .gridColumnAlignment(.trailing)

            Group {
                if let date = state.lastCheck {
                    Text(date.formatted(date: .long, time: .shortened))
                } else {
                    Text(AppLocalization.text("updates.never"))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 250, alignment: .leading)
        }
    }

    /// 间隔的显示名称。
    private static func intervalTitle(_ seconds: TimeInterval) -> String {
        switch seconds {
        case 3600: AppLocalization.text("updates.interval.hourly")
        case 604_800: AppLocalization.text("updates.interval.weekly")
        default: AppLocalization.text("updates.interval.daily")
        }
    }
}

// MARK: - UpdaterState

/// Updates 页显示的更新器设置：经 KVO 跟随 Sparkle 的改动，包括更新窗口里改的自动下载与每次检查后的时间。
///
/// 只读取；改动直接写给更新器，再由 KVO 传回这里。
@MainActor
@Observable
private final class UpdaterState {
    /// 读写设置的更新器。
    let updater: SPUUpdater

    /// 是否按计划自动检查。
    private(set) var automaticallyChecks = false

    /// 找到更新后是否自动下载，并在退出时安装。
    private(set) var automaticallyDownloads = false

    /// Sparkle 是否允许自动下载与安装。
    private(set) var allowsAutomaticUpdates = false

    /// 自动检查的间隔，单位秒。
    private(set) var checkInterval: TimeInterval = 0

    /// 最近一次检查的时间；从未检查时为 `nil`。
    private(set) var lastCheck: Date? = nil

    /// 各项设置的 KVO 观察，随状态一起释放。
    @ObservationIgnored
    private var observations: [NSKeyValueObservation] = []

    /// 读入更新器的当前设置，并在其中任一项变化时重新读取。
    init(updater: SPUUpdater) {
        self.updater = updater
        refresh()

        observations = [
            observe(\.automaticallyChecksForUpdates),
            observe(\.automaticallyDownloadsUpdates),
            observe(\.allowsAutomaticUpdates),
            observe(\.updateCheckInterval),
            observe(\.lastUpdateCheckDate),
        ]
    }

    /// 观察更新器的一项属性，变化时重新读取全部设置。
    ///
    /// Sparkle 只在主线程修改这些属性，回调与界面处于同一执行域。
    private func observe(_ keyPath: KeyPath<SPUUpdater, some Any>) -> NSKeyValueObservation {
        updater.observe(keyPath) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    /// 从更新器读取全部设置。
    private func refresh() {
        automaticallyChecks = updater.automaticallyChecksForUpdates
        automaticallyDownloads = updater.automaticallyDownloadsUpdates
        allowsAutomaticUpdates = updater.allowsAutomaticUpdates
        checkInterval = updater.updateCheckInterval
        lastCheck = updater.lastUpdateCheckDate
    }
}
