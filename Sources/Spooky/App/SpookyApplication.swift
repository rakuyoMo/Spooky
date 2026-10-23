import AppKit

/// `swift run Spooky` 的原生应用入口。
@main
enum SpookyApplication {
    /// 保持应用委托存活，进入 AppKit 事件循环。
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let controller = SpookyApplicationController()
        application.setActivationPolicy(.regular)
        application.delegate = controller

        withExtendedLifetime(controller) {
            application.run()
        }
    }
}
