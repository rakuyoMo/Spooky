import AppKit
import SpookyKit

// MARK: - BookmarkSidebarController

/// 仓库管理的侧边栏：根分组 “Repositories” 下的书签树，底栏的 “+” 菜单，右键菜单、拖放与原地改名。
///
/// 书签的变化来自全部窗口共用的模型，侧边栏随之重新载入并保留展开与选中。
@MainActor
final class BookmarkSidebarController: NSViewController {
    /// 所在窗口的仓库管理。
    let manager: RepositoryManagerController

    /// 书签列表。
    let outlineView = BookmarkOutlineView()

    /// 根分组标题对应的行。
    let header = BookmarkOutlineItem(id: nil)

    /// 书签行对应的对象，按身份复用。
    private var items: [Bookmark.ID: BookmarkOutlineItem] = [:]

    /// 正在按模型设置选中行，期间不把选择写回模型。
    private(set) var isRestoringSelection = false

    /// 创建侧边栏。
    ///
    /// - Parameter manager: 所在窗口的仓库管理。
    init(manager: RepositoryManagerController) {
        self.manager = manager
        super.init(nibName: nil, bundle: nil)
    }

    /// 侧边栏只由代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// 列表占满上方，底部是 28 pt 高的底栏与它上面的分隔线。
    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        let bottomBar = makeBottomBar()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(scrollView)
        container.addSubview(divider)
        container.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 144),

            divider.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            bottomBar.topAnchor.constraint(equalTo: divider.bottomAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 28),
        ])

        view = container
        configureOutlineView()
    }

    /// 首次载入后恢复展开状态，根分组始终展开，再接上模型的变化。
    override func viewDidLoad() {
        super.viewDidLoad()

        reload()

        outlineView.autosaveName = "Spooky.BookmarksSidebar"
        outlineView.autosaveExpandedItems = true
        outlineView.expandItem(header)
        restoreSelection()
        observeModel()
        observeSelection()
        observeClones()
    }

    /// 显示后让列表接收键盘。
    override func viewDidAppear() {
        super.viewDidAppear()

        view.window?.makeFirstResponder(outlineView)
    }
}

// MARK: - Loading

extension BookmarkSidebarController {
    /// 列表里选中的书签，按行的顺序排列。
    var selectedIDs: [Bookmark.ID] {
        outlineView.selectedRowIndexes.compactMap { (outlineView.item(atRow: $0) as? BookmarkOutlineItem)?.id }
    }

    /// 一行对应的书签；根分组标题没有。
    func bookmark(for item: Any?) -> Bookmark? {
        (item as? BookmarkOutlineItem)?.id.flatMap(manager.bookmarks.bookmark)
    }

    /// 一个书签对应的行对象，没有时新建。
    func item(for id: Bookmark.ID) -> BookmarkOutlineItem {
        if let existing = items[id] {
            return existing
        }

        let item = BookmarkOutlineItem(id: id)
        items[id] = item
        return item
    }

    /// 一行对象的子项：根分组标题下是最外层书签，文件夹下是它的子项。
    func children(of item: Any?) -> [Bookmark] {
        guard let item = item as? BookmarkOutlineItem else {
            return []
        }

        guard let id = item.id else {
            return manager.bookmarks.items
        }

        return manager.bookmarks.bookmark(id)?.children ?? []
    }

    /// 书签或失效标记变化后重新载入，展开与选中按身份保留；删掉的书签不再保留行对象。
    func reload() {
        let existing = Set(manager.bookmarks.items.flattened.map(\.id))
        items = items.filter { existing.contains($0.key) }

        outlineView.reloadData()
        outlineView.expandItem(header)
        restoreSelection()
        beginRequestedRename()
    }

    /// 按模型里的选择选中行；文件夹里的书签先展开它的上级。
    func restoreSelection() {
        let rows = IndexSet(manager.selection.compactMap { id -> Int? in
            expandAncestors(of: id)
            let row = outlineView.row(forItem: item(for: id))
            return row >= 0 ? row : nil
        })

        isRestoringSelection = true
        outlineView.selectRowIndexes(rows, byExtendingSelection: false)
        isRestoringSelection = false
    }

    /// 新建文件夹后进入改名：选中那一行并开始编辑名称。
    private func beginRequestedRename() {
        guard let id = manager.renameRequest else {
            return
        }

        manager.renameRequest = nil
        beginRename(id)
    }

    /// 选中并开始编辑一行的名称。
    func beginRename(_ id: Bookmark.ID) {
        expandAncestors(of: id)
        let row = outlineView.row(forItem: item(for: id))

        guard row >= 0 else {
            return
        }

        outlineView.selectRowIndexes([row], byExtendingSelection: false)
        outlineView.scrollRowToVisible(row)
        outlineView.editColumn(0, row: row, with: nil, select: true)
    }

    /// 展开一个书签的全部上级文件夹。
    private func expandAncestors(of id: Bookmark.ID) {
        var chain: [Bookmark.ID] = []
        var current = manager.bookmarks.parent(of: id)

        while let folder = current {
            chain.insert(folder, at: 0)
            current = manager.bookmarks.parent(of: folder)
        }

        for folder in chain {
            outlineView.expandItem(item(for: folder))
        }
    }

    /// 书签、失效标记与改名请求变化后，下一轮主线程重新载入并重新订阅。
    private func observeModel() {
        withObservationTracking {
            _ = manager.bookmarks.items
            _ = manager.bookmarks.missing
            _ = manager.renameRequest
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                // 正在改名时不打断编辑，结束后模型变化会再触发一次
                if outlineView.currentEditor() == nil {
                    reload()
                }

                observeModel()
            }
        }
    }

    /// 克隆开始、推进或结束时只重新配置可见的行，不打断改名与选择。
    private func observeClones() {
        withObservationTracking {
            for activity in manager.coordinator?.clones.items ?? [] {
                _ = activity.state
            }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                let visible = outlineView.rows(in: outlineView.visibleRect)

                if outlineView.currentEditor() == nil, visible.length > 0 {
                    outlineView.reloadData(
                        forRowIndexes: IndexSet(integersIn: visible.location ..< visible.location + visible.length),
                        columnIndexes: [0]
                    )
                }

                observeClones()
            }
        }
    }

    /// 选择由别处改变时（新建文件夹、删除）同步到列表；与列表一致时不动。
    private func observeSelection() {
        withObservationTracking {
            _ = manager.selection
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                if selectedIDs != manager.selection {
                    restoreSelection()
                }

                observeSelection()
            }
        }
    }
}

// MARK: - Bottom Bar

extension BookmarkSidebarController {
    /// 底栏左侧的 “+” 下拉菜单。
    private func makeBottomBar() -> NSView {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.bezelStyle = .accessoryBar
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityLabel(AppLocalization.text("bookmarks.addMenu"))
        button.toolTip = AppLocalization.text("bookmarks.addMenu")
        button.menu = makeAddMenu()

        let bar = NSView()
        bar.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 4),
            button.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 20),
        ])

        return bar
    }
}
