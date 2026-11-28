import AppKit
import SpookyKit

// MARK: - RepositoryToolbar + Custom Buttons

extension RepositoryToolbar {
    /// 自定义按钮的标签最宽 120 pt，超出时截短。
    static let customButtonLabelWidth: CGFloat = 120

    /// 自定义按钮项标识的前缀，后接按钮的标识。
    private static let customButtonPrefix = "customButton."

    /// 自定义按钮在工具栏里的项标识。
    ///
    /// - Parameter button: 自定义按钮。
    static func identifier(of button: CustomToolbarButton) -> NSToolbarItem.Identifier {
        NSToolbarItem.Identifier(customButtonPrefix + button.id.uuidString)
    }

    /// 项标识对应的自定义按钮的标识。
    ///
    /// - Parameter identifier: 工具栏项的标识。
    /// - Returns: 按钮的标识；不是自定义按钮的项为 nil。
    static func customButtonID(of identifier: NSToolbarItem.Identifier) -> UUID? {
        guard identifier.rawValue.hasPrefix(customButtonPrefix) else {
            return nil
        }

        return UUID(uuidString: String(identifier.rawValue.dropFirst(customButtonPrefix.count)))
    }

    /// 自定义按钮在工具栏上的标签：按工具栏标签的 11 pt 系统字体量，名称宽过 ``customButtonLabelWidth`` 时，
    /// 截成放得下的最长前缀，末尾加省略号。
    ///
    /// 工具栏不截断标签，标签多宽按钮就多宽。
    ///
    /// - Parameter name: 按钮的名称。
    static func customButtonLabel(_ name: String) -> String {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let width = { (text: String) in
            NSAttributedString(string: text, attributes: [.font: font]).size().width
        }

        guard width(name) > customButtonLabelWidth else {
            return name
        }

        // 按字符二分，找加上省略号后仍放得下的最长前缀
        let characters = Array(name)
        var low = 0
        var high = characters.count

        while low < high {
            let middle = (low + high + 1) / 2

            if width(String(characters[..<middle]) + "…") <= customButtonLabelWidth {
                low = middle
            } else {
                high = middle - 1
            }
        }

        let prefix = String(characters[..<low])

        // 截在空白处时不在省略号前留下空格
        return String(prefix.reversed().drop { $0.isWhitespace }.reversed()) + "…"
    }
}

// MARK: - Custom Buttons

extension RepositoryWindowController {
    /// 自定义面板里列出的自定义按钮，按添加的先后，排在内置项之后。
    var customButtonIdentifiers: [NSToolbarItem.Identifier] {
        toolbarButtons.buttons.map(RepositoryToolbar.identifier(of:))
    }

    /// 按项标识创建自定义按钮。
    ///
    /// - Parameter identifier: 工具栏项的标识。
    /// - Returns: 工具栏项；标识不是自定义按钮，或按钮已删除时为 nil，以前保存的排布里留着的已删除按钮由系统跳过。
    func makeCustomButtonItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        guard
            let id = RepositoryToolbar.customButtonID(of: identifier),
            let button = toolbarButtons.button(id)
        else { return nil }

        let item = NSToolbarItem(itemIdentifier: identifier)
        item.target = self
        item.action = #selector(runCustomButton(_:))
        configure(item, with: button)

        return item
    }

    /// 自定义按钮：在本机运行它的脚本；没能运行或没有正常结束时，在本窗口弹出错误框。
    ///
    /// - Parameter sender: 工具栏里的按钮，或按钮在溢出菜单里的一项。
    @objc
    func runCustomButton(_ sender: Any?) {
        let toolbarID = (sender as? NSToolbarItem)
            .flatMap { RepositoryToolbar.customButtonID(of: $0.itemIdentifier) }

        let id = toolbarID ?? (sender as? NSMenuItem)?.representedObject as? UUID

        guard
            let id,
            let button = toolbarButtons.button(id),
            let location = session.repository
        else { return }

        let branch = session.status?.branch

        // 服务器断开时读不到远端配置，不等连接，不设远端的变量
        let readsRemotes = location.host == nil || session.connectionState == .connected
        let runner = readsRemotes ? session.runner : nil

        Task { [weak self] in
            var remotes: [RemoteConfiguration] = []

            if let runner {
                remotes = (try? await RepositoryRemotes(runner: runner).configurations()) ?? []
            }

            let variables = CustomToolbarScript.variables(location: location, branch: branch, remotes: remotes)

            do {
                try await CustomToolbarScript.run(button.script, variables: variables, location: location)
            } catch {
                self?.showFailure(AppFailure(error: error, opening: false, location: location))
            }
        }
    }

    /// 按钮增删改后更新工具栏：已删除的按钮从工具栏移除，其余的重写标签、图标与提示；每次变化后接着观察。
    func observeToolbarButtons() {
        withObservationTracking {
            _ = toolbarButtons.buttons
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                updateCustomButtonItems()
                observeToolbarButtons()
            }
        }
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 按按钮写入工具栏项：截短的名称作标签、面板里的名字与溢出菜单里的标题，提示写完整的名称，系统符号作图标。
    ///
    /// 这台 Mac 上没有的符号换成新按钮的默认图标。
    private func configure(_ item: NSToolbarItem, with button: CustomToolbarButton) {
        item.label = RepositoryToolbar.customButtonLabel(button.name)
        item.paletteLabel = item.label
        item.toolTip = button.name

        item.image = AppSymbol.image(button.symbol, side: 18, accessibilityDescription: button.name)
            ?? AppSymbol.image(CustomToolbarButton.defaultSymbol, side: 18, accessibilityDescription: button.name)

        // 溢出菜单里的一项以按钮的标识认出是哪个按钮
        let menuItem = NSMenuItem(
            title: item.label,
            action: #selector(runCustomButton(_:)),
            keyEquivalent: ""
        )

        menuItem.target = self
        menuItem.representedObject = button.id
        menuItem.image = item.image
        item.menuFormRepresentation = menuItem
    }

    /// 让工具栏里的自定义按钮跟上按钮的现状。
    ///
    /// 同一标识的工具栏同步增删，别的窗口已经移除的项在本窗口里也已不在，本窗口只处理自己工具栏里还有的项；从后往前删，前面的下标不变。
    private func updateCustomButtonItems() {
        guard let toolbar = window?.toolbar else {
            return
        }

        for index in toolbar.items.indices.reversed() {
            let item = toolbar.items[index]

            guard let id = RepositoryToolbar.customButtonID(of: item.itemIdentifier) else {
                continue
            }

            guard let button = toolbarButtons.button(id) else {
                toolbar.removeItem(at: index)
                continue
            }

            configure(item, with: button)
        }
    }
}
