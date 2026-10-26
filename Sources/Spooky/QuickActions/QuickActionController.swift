import Foundation

// MARK: - QuickActionController

/// 快捷操作面板的状态与键盘命令：输入、结果列表、选中行与动作模式。
///
/// 平时列出与输入匹配的对象；进入动作模式后头部显示一个对象，列表换成它当前可以执行的动作。
/// 进入动作模式前记下输入与选中行，退出时恢复。文件与提交要执行 Git，停止输入 0.3 s 后才查询，结果追加在列表末尾。
@MainActor
final class QuickActionController {
    /// 键盘命令的结果，由面板决定关闭、响铃或执行。
    enum Outcome: Equatable {
        /// 命令已处理，面板保持打开。
        case handled

        /// 交还给输入框的默认处理，如在输入中间移动光标。
        case ignored

        /// 命令在当前状态下没有意义。
        case beep

        /// 关闭面板，不执行动作。
        case close

        /// 关闭面板，再对对象执行动作。
        case perform(QuickActionObject, QuickAction)
    }

    /// 停止输入后再执行 Git 查询的间隔。
    static let searchDelay = Duration.milliseconds(300)

    /// 对象、动作与可用性的来源。
    let catalog: QuickActionCatalog

    /// 输入框里的文字。
    private(set) var query = ""

    /// 动作模式里头部显示的对象；平时为 nil。
    private(set) var activeObject: QuickActionObject? = nil

    /// 当前列出的行。
    private(set) var items: [QuickActionItem] = []

    /// 选中行的下标；没有结果时为 nil。
    private(set) var selectedIndex: Int? = nil

    /// 文件与提交的查询是否还在等待或执行。
    private(set) var isSearching = false

    /// 输入、列表、选中行或动作模式变化后通知面板刷新。
    var onChange: (() -> Void)? = nil

    /// 进入动作模式前的输入与选中行。
    private var savedState: (query: String, selection: String?)? = nil

    /// HEAD 树中的文件，按 HEAD 的哈希复用。
    private var files: (head: String, paths: [String])? = nil

    /// 当前输入匹配的文件。
    private var fileMatches: [QuickActionObject] = []

    /// 当前输入匹配的提交。
    private var commitMatches: [QuickActionObject] = []

    /// 等待停止输入并查询文件与提交的任务。
    private var searchTask: Task<Void, Never>? = nil

    /// 选中的行。
    var selectedItem: QuickActionItem? {
        selectedIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }
    }

    /// 全部查询结束仍没有结果，列表显示 No Results。
    var showsNoResults: Bool {
        items.isEmpty && !isSearching
    }

    /// 创建空白状态的面板控制器。
    init(catalog: QuickActionCatalog) {
        self.catalog = catalog
    }

    /// 面板显示时按保留的输入重新列出结果。
    func start() {
        rebuild()
        scheduleSearch()
    }

    /// 面板关闭时取消还在进行的查询。
    func stop() {
        searchTask?.cancel()
        isSearching = false
    }

    /// 输入变化：立即重列不需要 Git 的对象，文件与提交在停止输入后再查。
    func setQuery(_ text: String) {
        guard text != query else {
            return
        }

        query = text
        scheduleSearch()
        rebuild()
    }

    /// ↑ / ↓：移动选中行，到两端时停住。
    func moveSelection(by offset: Int) {
        let next = (selectedIndex ?? -1) + offset

        guard items.indices.contains(next) else {
            return
        }

        selectedIndex = next
        onChange?()
    }

    /// 单击或程序选中一行。
    func select(_ index: Int) {
        guard items.indices.contains(index), index != selectedIndex else {
            return
        }

        selectedIndex = index
        onChange?()
    }
}

// MARK: - Keyboard

extension QuickActionController {
    /// ↩：动作行执行该动作，对象行执行默认动作，随后清空并关闭；动作现在不可用时响一声。
    func insertNewline() -> Outcome {
        guard let item = selectedItem else {
            reset()
            return .close
        }

        let action = item.action ?? catalog.defaultAction(for: item.object)

        guard catalog.isAvailable(action, for: item.object) else {
            return .beep
        }

        reset()
        return .perform(item.object, action)
    }

    /// Tab：进入选中对象的动作模式；选中的已是动作行时响一声。
    func insertTab() -> Outcome {
        guard let item = selectedItem else {
            return .handled
        }

        guard item.action == nil else {
            return .beep
        }

        savedState = (query, item.identifier)
        activeObject = item.object
        query = ""
        searchTask?.cancel()
        isSearching = false
        rebuild(selecting: nil)

        return .handled
    }

    /// →：光标在输入末尾且没有选区时同 Tab，否则移动光标。
    func moveRight(atEnd: Bool) -> Outcome {
        atEnd ? insertTab() : .ignored
    }

    /// ←：光标在开头且输入为空时退出动作模式，否则移动光标。
    func moveLeft(atStart: Bool) -> Outcome {
        atStart && leaveActionMode() ? .handled : .ignored
    }

    /// ⇧Tab：清空输入并退出动作模式。
    func insertBacktab() -> Outcome {
        query = ""

        if !leaveActionMode() {
            scheduleSearch()
            rebuild()
        }

        return .handled
    }

    /// Esc：有输入先清空；输入为空时退出动作模式；不在动作模式就关闭面板。
    func cancelOperation() -> Outcome {
        if !query.isEmpty {
            query = ""
            scheduleSearch()
            rebuild()
            return .handled
        }

        return leaveActionMode() ? .handled : .close
    }

    /// 双击：执行这一行并关闭面板。
    func performItem(at index: Int) -> Outcome {
        guard items.indices.contains(index) else {
            return .ignored
        }

        selectedIndex = index
        return insertNewline()
    }
}

// MARK: - Private

extension QuickActionController {
    /// 输入为空且处在动作模式时恢复进入前的输入与选中行。
    private func leaveActionMode() -> Bool {
        guard query.isEmpty, activeObject != nil else {
            return false
        }

        let saved = savedState
        activeObject = nil
        savedState = nil
        query = saved?.query ?? ""
        rebuild(selecting: saved?.selection)

        return true
    }

    /// 执行之后回到空白的对象列表，下次打开从头开始。
    private func reset() {
        searchTask?.cancel()
        isSearching = false
        activeObject = nil
        savedState = nil
        query = ""
        fileMatches = []
        commitMatches = []
        rebuild(selecting: nil)
    }

    /// 输入变化后丢掉旧的文件与提交结果；对象模式下有输入时，停止输入 0.3 s 后再查询。
    private func scheduleSearch() {
        searchTask?.cancel()
        fileMatches = []
        commitMatches = []

        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard activeObject == nil, !text.isEmpty else {
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDelay)

            guard !Task.isCancelled else {
                return
            }

            await self?.search(text)
        }
    }

    /// 文件与提交并行查询；文件先放进列表，提交随后追加，已显示的行不会移动。
    private func search(_ text: String) async {
        async let commits = try? catalog.commits(matching: text)
        let paths = await headPaths()

        // 大仓库的文件多达数十万个，打分与排序放在后台
        let ranked = await Task.detached { QuickActionMatcher.rankFiles(paths, query: text) }.value

        guard !Task.isCancelled else {
            return
        }

        fileMatches = ranked.map(QuickActionObject.file)
        rebuild()

        let found = await commits ?? []

        guard !Task.isCancelled else {
            return
        }

        commitMatches = found
        isSearching = false
        rebuild()
    }

    /// HEAD 树中的文件；HEAD 没变时复用上次读到的清单，读取失败时为空。
    private func headPaths() async -> [String] {
        if let files, files.head == catalog.session.status?.branch.oid {
            return files.paths
        }

        guard let loaded = try? await catalog.headFiles() else {
            return []
        }

        files = loaded
        return loaded.paths
    }

    /// 按当前模式与输入重列结果；选中行按身份找回，找不到时选中第一行。
    private func rebuild() {
        rebuild(selecting: selectedItem?.identifier)
    }

    /// 按当前模式与输入重列结果，并选中指定身份的行。
    private func rebuild(selecting identifier: String?) {
        if let activeObject {
            // 动作按菜单里的顺序列出，输入只做筛选
            items = catalog.actions(for: activeObject)
                .map { QuickActionItem(object: activeObject, action: $0) }
                .filter { QuickActionMatcher.score($0.title, query: query) != nil }
        } else {
            let objects = QuickActionMatcher.rank(catalog.immediateObjects(), query: query)
                + fileMatches
                + commitMatches

            items = objects.map { QuickActionItem(object: $0, action: nil) }
        }

        selectedIndex = identifier.flatMap { id in items.firstIndex { $0.identifier == id } }
            ?? (items.isEmpty ? nil : 0)

        onChange?()
    }
}
