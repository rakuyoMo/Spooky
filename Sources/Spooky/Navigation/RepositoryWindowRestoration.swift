import AppKit

// MARK: - RepositoryWindowRestoration

/// 系统窗口恢复的入口：重新启动后按仓库窗口保存的视图引用重建窗口。
///
/// 窗口的位置、尺寸与标签组由系统恢复，分栏宽度由各分栏的 autosave 恢复。
final class RepositoryWindowRestoration: NSObject, NSWindowRestoration {
    /// 恢复失败时交给系统的错误；系统据此不再恢复这个窗口。
    private struct RestorationError: Error { }

    /// 仓库窗口的恢复标识。
    static let identifier = NSUserInterfaceItemIdentifier("Spooky.RepositoryWindow")

    /// 由 App 的协调者重建窗口；协调者还不可用或标识不认识时不恢复这个窗口。
    static func restoreWindow(
        withIdentifier identifier: NSUserInterfaceItemIdentifier,
        state: NSCoder,
        completionHandler: @escaping (NSWindow?, (any Error)?) -> Void
    ) {
        MainActor.assumeIsolated {
            guard
                identifier == Self.identifier,
                let coordinator = NSApp.delegate as? SpookyApplicationController,
                let window = coordinator.restoreWindow(from: state)
            else {
                completionHandler(nil, RestorationError())
                return
            }

            completionHandler(window, nil)
        }
    }
}
