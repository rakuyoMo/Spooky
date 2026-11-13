import AppKit
import SpookyKit
import SwiftUI

// MARK: - WorkingCopyListView

/// 工作区列表保留所有状态条目，刷新期间仍展示旧快照。
struct WorkingCopyListView: View {
    /// 当前仓库会话。
    @Bindable
    var session: RepositorySession

    /// 分支头、提交区与铺到底的状态表；刷新与写入期间不另显示文字。
    ///
    /// 分支头与提交区同一种材质，分支头底边的分隔线画在材质里；提交区与文件表头之间不画线。
    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusView(session: session)
            branchHeader

            WorkingCopyCommitView(session: session)

            WorkingCopyFileList(session: session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { emptyListMessage }
        }
    }

    /// 状态头写出的当前分支：分离 HEAD 写前 8 位哈希与分离状态，没有 HEAD 分支时写专门的说明，未出生分支照写分支名。
    ///
    /// 8 位只是显示缩写，对象读取与解析仍按仓库实际的哈希长度。
    static func branchTitle(_ branch: BranchStatus) -> String {
        if let head = branch.head {
            return head
        }

        if let oid = branch.oid {
            return AppLocalization.text("branch.detached", String(oid.prefix(8)))
        }

        return AppLocalization.text("branch.noHeadBranch")
    }
}

// MARK: - Private

extension WorkingCopyListView {
    /// 列表顶部的分支摘要与视图设置按钮，底边贴一条分隔线；摘要距左 12，按钮距右 8。
    private var branchHeader: some View {
        HStack(spacing: 8) {
            branchSummary

            Spacer(minLength: 0)

            WorkingCopyViewSettingsButton()
                .frame(width: 28, height: 22)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40)
        .background(HeaderMaterial(showsBottomSeparator: true))
    }

    /// 列表为空时的说明：只有搜索没有匹配时写出搜索内容；干净的工作区留空。
    @ViewBuilder
    private var emptyListMessage: some View {
        if let status = session.status, !session.searchText.isEmpty {
            let visible = session.listing.entries(status: status.entries, files: session.workingTreeFiles)

            if visible.isEmpty {
                Text(AppLocalization.text("files.noMatches", session.searchText))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(20)
            }
        }
    }

    /// 一行当前分支、分隔图与跟踪分支，三者首尾相接；有进行中的操作时同样如此，没有上游时明确显示没有上游。
    ///
    /// 两段文字各留 2 pt 的内边距、最小宽 50；空间不够时先截短跟踪分支。
    @ViewBuilder
    private var branchSummary: some View {
        if let branch = session.status?.branch {
            let title = Self.branchTitle(branch)

            HStack(spacing: 0) {
                summaryText(title, color: .secondaryLabelColor)
                    .layoutPriority(1)

                if branch.head != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                        .frame(width: 12, height: 17)
                        .accessibilityHidden(true)

                    summaryText(
                        branch.upstream ?? AppLocalization.text("branch.noTracking"),
                        color: .tertiaryLabelColor
                    )
                }
            }
            .help(title)
        } else {
            Text(AppLocalization.text("workspace.title"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    /// 状态头里的一段 13 pt 文字：单行、截掉末尾，带 2 pt 内边距，最小宽 50。
    private func summaryText(_ text: String, color: NSColor) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: color))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 2)
            .frame(minWidth: 50, alignment: .leading)
    }
}

// MARK: - WorkingCopyViewSettingsButton

/// 状态头的视图设置按钮：工具栏样式的下拉按钮，只显示用次要文字颜色着色的图标。
///
/// 菜单与主菜单的 Working Copy Status 子菜单发送同一组动作，勾选与可用状态由仓库窗口的菜单校验标出。
private struct WorkingCopyViewSettingsButton: NSViewRepresentable {
    /// 菜单项的资源键与动作，nil 表示分隔线。
    private static let items: [(key: String, action: Selector)?] = [
        ("working.tree", #selector(RepositoryWindowController.viewAsTree)),
        ("working.list", #selector(RepositoryWindowController.viewAsList)),
        nil,
        ("files.showNonModified", #selector(RepositoryWindowController.toggleNonModifiedItems)),
        ("files.showIgnored", #selector(RepositoryWindowController.toggleIgnoredItems)),
        ("files.showAssumeUnchanged", #selector(RepositoryWindowController.toggleAssumeUnchangedItems)),
    ]

    /// 下拉按钮不带箭头；第一项只用作按钮上的图标，其余各项沿响应链发送动作。
    func makeNSView(context _: Context) -> NSPopUpButton {
        let title = AppLocalization.text("working.viewMode")
        let button = NSPopUpButton(frame: .zero, pullsDown: true)

        button.bezelStyle = .toolbar
        button.imagePosition = .imageOnly
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = title
        button.setAccessibilityLabel(title)
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow

        // 下拉按钮的第一项不出现在菜单里，只决定按钮上显示什么
        let icon = NSMenuItem()
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)

        icon.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: title)?
            .withSymbolConfiguration(configuration)

        button.menu?.addItem(icon)

        for item in Self.items {
            guard let item else {
                button.menu?.addItem(.separator())
                continue
            }

            button.menu?.addItem(
                NSMenuItem(title: AppLocalization.text(item.key), action: item.action, keyEquivalent: "")
            )
        }

        return button
    }

    /// 按钮没有随 SwiftUI 状态变化的内容。
    func updateNSView(_: NSPopUpButton, context _: Context) { }

    /// 按钮固定 28 × 22，不随系统给出的固有尺寸变化。
    func sizeThatFits(_: ProposedViewSize, nsView _: NSPopUpButton, context _: Context) -> CGSize? {
        CGSize(width: 28, height: 22)
    }
}
