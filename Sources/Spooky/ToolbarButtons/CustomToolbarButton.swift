import Foundation
import Observation

// MARK: - CustomToolbarButton

/// 工具栏上的自定义按钮：图标、名称与点按时在本机运行的脚本。
struct CustomToolbarButton: Codable, Equatable, Identifiable {
    /// 新按钮的图标。
    static let defaultSymbol = "play"

    /// 按钮的稳定标识，也写进按钮在工具栏里的项标识。
    var id = UUID()

    /// 图标的系统符号名。
    var symbol = defaultSymbol

    /// 按钮的名称，不限长度；工具栏上放不下时截短。
    var name = ""

    /// 点按时运行的脚本。
    var script = ""
}

// MARK: - CustomToolbarButtonStore

/// 自定义按钮的存取：按钮数组以 JSON 存在偏好里，所有仓库窗口共用；设置页增删改后，各窗口的工具栏随之更新。
@MainActor
@Observable
final class CustomToolbarButtonStore {
    /// 偏好键，值为按钮数组的 JSON。
    static let key = "customToolbarButtons"

    /// App 使用的按钮。
    static let shared = CustomToolbarButtonStore(defaults: .standard)

    /// 全部按钮，按添加的先后；自定义工具栏的面板按这个顺序列出。
    private(set) var buttons: [CustomToolbarButton]

    /// 读写的偏好。
    @ObservationIgnored
    private let defaults: UserDefaults

    /// 从偏好读出按钮；内容损坏时视为没有按钮。
    ///
    /// - Parameter defaults: 读写的偏好，测试使用独立的域。
    init(defaults: UserDefaults) {
        self.defaults = defaults

        buttons = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([CustomToolbarButton].self, from: $0) } ?? []
    }

    /// 按标识找按钮。
    ///
    /// - Parameter id: 按钮的标识。
    /// - Returns: 找到的按钮；已删除时为 nil。
    func button(_ id: UUID) -> CustomToolbarButton? {
        buttons.first { $0.id == id }
    }

    /// 保存按钮：已有的原位替换，新的追加到末尾。
    ///
    /// - Parameter button: 要保存的按钮。
    func save(_ button: CustomToolbarButton) {
        if let index = buttons.firstIndex(where: { $0.id == button.id }) {
            buttons[index] = button
        } else {
            buttons.append(button)
        }

        write()
    }

    /// 删除按钮；放在工具栏里的一份由各窗口随之移除。
    ///
    /// - Parameter id: 要删除的按钮的标识。
    func remove(_ id: UUID) {
        buttons.removeAll { $0.id == id }
        write()
    }
}

// MARK: - Private

extension CustomToolbarButtonStore {
    /// 把全部按钮写回偏好。
    private func write() {
        defaults.set(try? JSONEncoder().encode(buttons), forKey: Self.key)
    }
}
