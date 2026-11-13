import SwiftUI

// MARK: - HistoryLoadingRowPhase

/// 首屏加载行的显示阶段。
enum HistoryLoadingRowPhase: Equatable {
    /// 不显示。
    case hidden

    /// 首屏读取已开始，还没到显示的时候。
    case pending

    /// 正在显示；`settled` 表示已显示满 0.6 s，读完即可收起。
    case shown(settled: Bool)

    /// 显示不满 0.6 s 就读完了，再留一会儿才收起，结果暂不显示。
    case holding

    /// 列表里是否画出加载行。
    var isVisible: Bool {
        switch self {
        case .hidden, .pending: false
        case .shown, .holding: true
        }
    }
}

// MARK: - Loading Row

extension RepositoryHistoryState {
    /// 首屏读取开始：0.5 s 后仍在读取才显示加载行，显示满 0.6 s 后读完即可立即收起。
    func beginLoadingRow() {
        loadingRowTask?.cancel()
        loadingRowPhase = .pending

        let sleep = loadingRowSleep

        loadingRowTask = Task { [weak self] in
            guard (try? await sleep(.milliseconds(500))) != nil, let self, !Task.isCancelled else {
                return
            }

            loadingRowPhase = .shown(settled: false)

            guard (try? await sleep(.milliseconds(600))) != nil, !Task.isCancelled else {
                return
            }

            loadingRowPhase = .shown(settled: true)
            loadingRowTask = nil
        }
    }

    /// 首屏读取结束：加载行还没出现就不再出现；出现不满 0.6 s 时再留 0.7 s 才收起，避免一闪而过。
    func endLoadingRow() {
        loadingRowTask?.cancel()
        loadingRowTask = nil

        guard loadingRowPhase == .shown(settled: false) else {
            loadingRowPhase = .hidden
            return
        }

        loadingRowPhase = .holding

        let sleep = loadingRowSleep

        loadingRowTask = Task { [weak self] in
            guard (try? await sleep(.milliseconds(700))) != nil, let self, !Task.isCancelled else {
                return
            }

            loadingRowPhase = .hidden
            loadingRowTask = nil
        }
    }

    /// 读取被取消时立即收起加载行。
    func hideLoadingRow() {
        loadingRowTask?.cancel()
        loadingRowTask = nil
        loadingRowPhase = .hidden
    }
}

// MARK: - HistoryLoadingRow

/// 列表里的加载行：居中的转圈、读取说明与取消按钮；首屏读取画在第一行，续页画在最后一行。
struct HistoryLoadingRow: View {
    /// 读取说明。
    let title: String

    /// 取消这次读取。
    let cancel: () -> Void

    /// 13 pt 文字，整行居中。
    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)

            Text(title)

            Button(AppLocalization.text("action.cancel"), action: cancel)
                .controlSize(.small)
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
