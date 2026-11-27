import SwiftUI

// MARK: - SidebarWorkingCopyProgress

/// Working Copy 入口图标上的进度，侧边栏的行与极窄版式的视图导航共用。
///
/// 刷新中或占用工作区的写操作执行中，图标原位换成进度，入口的宽度不变；
/// 很快结束的加载不显示进度，进度出现后至少停留一阵，不会一闪而过。
struct SidebarWorkingCopyProgress: ViewModifier {
    /// 加载持续这么久之后才显示进度。
    private static let delay = Duration.milliseconds(300)

    /// 进度显示后至少停留的时间。
    private static let minimumDuration = Duration.milliseconds(500)

    /// 当前窗口会话。
    let session: RepositorySession

    /// 是否在图标的位置显示进度。
    @State
    private var showsProgress = false

    /// 这一次进度开始显示的时刻。
    @State
    private var shownAt = ContinuousClock.now

    /// 是否正在刷新，或有占用工作区的写操作正在执行。
    private var isLoading: Bool {
        session.isRefreshing || session.workspaceProgress != nil
    }

    /// 显示进度时图标变透明、仍占着原来的位置，进度叠在上面。
    func body(content: Content) -> some View {
        content
            .opacity(showsProgress ? 0 : 1)
            .overlay {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(
                            session.workspaceProgress?.title ?? AppLocalization.text("loading.status")
                        )
                }
            }
            .task(id: isLoading) {
                await follow(loading: isLoading)
            }
    }
}

// MARK: - Private

extension SidebarWorkingCopyProgress {
    /// 跟着加载状态显示或撤下进度；加载状态在等待期间又变了时，这次等待随任务一起取消。
    ///
    /// - Parameter loading: 现在是否在加载。
    private func follow(loading: Bool) async {
        // 开始加载：持续过一阵才显示，已经显示着的继续显示
        if loading {
            guard !showsProgress, await wait(Self.delay) else {
                return
            }

            showsProgress = true
            shownAt = .now
            return
        }

        // 加载结束：已经显示的进度留满最短时间再撤下
        guard
            showsProgress,
            await wait(Self.minimumDuration - shownAt.duration(to: .now))
        else {
            return
        }

        showsProgress = false
    }

    /// 等过给定的时长，时长不为正时立即返回；等待期间任务被取消时返回 false。
    ///
    /// - Parameter duration: 要等的时长。
    private func wait(_ duration: Duration) async -> Bool {
        try? await Task.sleep(for: duration)
        return !Task.isCancelled
    }
}
