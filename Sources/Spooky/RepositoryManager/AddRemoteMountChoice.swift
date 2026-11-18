import AppKit
import Observation
import SpookyKit
import SwiftUI

// MARK: - AddRemoteMountChoice

/// 添加服务器仓库时 “挂载到本机” 的选择：弹出菜单点开时按主机别名检测可用的挂载方式，选 sshfs 时要选挂载到的文件夹。
///
/// 改了主机别名后回到不挂载，检测结果作废。
@MainActor
@Observable
final class AddRemoteMountChoice {
    /// 弹出菜单的一项。
    enum Item: Hashable {
        /// 不挂载（本机位置是自动查找），或一种挂载方式。
        case method(ServerLocalLocation.Method)

        /// 还在检测时的不可选项。
        case checking

        /// 两种挂载方式都不可用时的不可选项。
        case unavailable

        /// 菜单里的标题。
        var title: String {
            switch self {
            case .method(.smbMount): AppLocalization.text("remote.mount.smb")
            case .method(.sshfsMount): AppLocalization.text("remote.mount.sshfs")
            case .method: AppLocalization.text("remote.mount.none")
            case .checking: AppLocalization.text("localLocation.checking")
            case .unavailable: AppLocalization.text("remote.mount.unavailable")
            }
        }
    }

    /// 选中的方式；不挂载是自动查找。
    private(set) var method = ServerLocalLocation.Method.automatic

    /// sshfs 挂载到的文件夹；还没有选时为 nil。
    private(set) var mountFolder: URL? = nil

    /// 选了不空的挂载文件夹时的说明。
    private(set) var mountFolderProblem: String? = nil

    /// 现在的主机别名可用的挂载方式；还没检测完时为 nil。
    private(set) var methods: Set<RemoteMountMethod>? = nil

    /// 检测可用条件；测试换成不做真实检测的实现。
    @ObservationIgnored
    var mounter = RemoteMounter.live

    /// 现在的主机别名。
    @ObservationIgnored
    private var host = ""

    /// 进行中的检测。
    @ObservationIgnored
    private var detection: Task<Void, Never>? = nil

    /// 弹出菜单的各项：不挂载总在；检测中是 “正在检测”，检测完列出可用的方式，都不可用时是 “没有可用的挂载方式”。
    var items: [Item] {
        guard let methods else {
            return [.method(.automatic), .checking]
        }

        let available = ServerLocalLocation.Method.allCases.filter { method in
            method.mounting.map(methods.contains) ?? false
        }

        return [.method(.automatic)] + (available.isEmpty ? [.unavailable] : available.map(Item.method))
    }

    /// 主按钮能不能按：选 sshfs 时要选了能用的文件夹。
    var isReady: Bool {
        method != .sshfsMount || (mountFolder != nil && mountFolderProblem == nil)
    }

    /// 仓库打开后记下并挂载的本机位置；不挂载时为 nil。
    var location: ServerLocalLocation? {
        switch method {
        case .smbMount: .smbMount(share: nil)
        case .sshfsMount: mountFolder.map(ServerLocalLocation.sshfsMount)
        case .automatic, .chosenFolder: nil
        }
    }

    /// 主机别名变了：回到不挂载，检测结果作废。
    ///
    /// - Parameter host: 新的主机别名。
    func setHost(_ host: String) {
        guard host != self.host else {
            return
        }

        self.host = host
        method = .automatic
        methods = nil
        detection = nil
    }

    /// 弹出菜单点开时检测；主机别名为空、已检测过或正在检测时不再检测。
    func detect() {
        guard !host.isEmpty, methods == nil, detection == nil else {
            return
        }

        let host = host

        detection = Task {
            let methods = await mounter.methods(host)

            // 检测期间改了主机别名时，结果不再采用
            guard host == self.host else { return }

            self.methods = methods
        }
    }

    /// 选一项；不可选的提示项不响应。
    func select(_ item: Item) {
        guard case .method(let method) = item else {
            return
        }

        self.method = method
    }

    /// 选定 sshfs 挂载到的文件夹；不空时说明原因，不能用。
    ///
    /// - Parameter folder: 选定的本机文件夹。
    func selectMountFolder(_ folder: URL) {
        mountFolder = folder
        mountFolderProblem = LocalLocationForm.problem(ofMountFolder: folder)
    }
}

// MARK: - AddRemoteMountPopUp

/// “挂载到本机” 的弹出按钮：点开时开始检测，提示项不可选；检测结果在菜单打开期间换上。
struct AddRemoteMountPopUp: NSViewRepresentable {
    /// 菜单的各项。
    let items: [AddRemoteMountChoice.Item]

    /// 选中的一项。
    let selected: AddRemoteMountChoice.Item

    /// 菜单点开。
    let open: () -> Void

    /// 选了一项。
    let select: (AddRemoteMountChoice.Item) -> Void

    /// 菜单代理与选择动作的目标。
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 系统样式的弹出按钮，菜单项的可用性由各项自己决定。
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.autoenablesItems = false
        button.menu?.delegate = context.coordinator
        button.target = context.coordinator
        button.action = #selector(Coordinator.choose(_:))
        button.setAccessibilityLabel(AppLocalization.text("remote.mount"))

        return button
    }

    /// 各项变了才重建菜单，再选中选中的一项；表单不可用时按钮随之不可用。
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let coordinator = context.coordinator
        coordinator.open = open
        coordinator.select = select
        button.isEnabled = context.environment.isEnabled

        if coordinator.items != items {
            coordinator.items = items
            button.removeAllItems()

            for item in items {
                let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")

                // 检测中与都不可用时的提示项不可选
                menuItem.isEnabled = ![.checking, .unavailable].contains(item)

                button.menu?.addItem(menuItem)
            }
        }

        button.selectItem(at: items.firstIndex(of: selected) ?? 0)
    }
}

// MARK: AddRemoteMountPopUp.Coordinator

extension AddRemoteMountPopUp {
    /// 弹出按钮的菜单代理与选择动作的目标。
    @MainActor
    final class Coordinator: NSObject, NSMenuDelegate {
        /// 菜单现在的各项，与菜单项一一对应。
        var items: [AddRemoteMountChoice.Item] = []

        /// 菜单点开。
        var open: () -> Void = { }

        /// 选了一项。
        var select: (AddRemoteMountChoice.Item) -> Void = { _ in }

        /// 菜单点开时开始检测。
        func menuWillOpen(_: NSMenu) {
            open()
        }

        /// 按下的菜单项换成对应的一项。
        @objc
        func choose(_ sender: NSPopUpButton) {
            let index = sender.indexOfSelectedItem

            guard items.indices.contains(index) else {
                return
            }

            select(items[index])
        }
    }
}
