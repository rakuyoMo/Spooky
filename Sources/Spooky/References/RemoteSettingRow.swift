import AppKit
import SpookyKit
import SwiftUI

// MARK: - SettingTableMetrics

/// 设置表格的尺寸：仓库管理的详情、仓库设置与远端、子模块、工作树详情共用。
enum SettingTableMetrics {
    /// 表格两侧的边距。
    static let inset: CGFloat = 20

    /// 标签列的宽度，标签在列里右对齐。
    static let labelWidth: CGFloat = 242

    /// 值列与标签列之间的间距。
    static let valueSpacing: CGFloat = 18

    /// 值列左缘到表格左缘的距离，也是行间分隔线的起点。
    static let valueColumn = inset + labelWidth + valueSpacing

    /// 普通行的最小高度。
    static let rowHeight: CGFloat = 36

    /// 分组标题行的高度。
    static let groupHeight: CGFloat = 57
}

// MARK: - SettingTable

/// 设置表格：按顺序排出分组标题行与普通行，在相邻两个普通行之间画一条从值列左缘到右侧的 1 pt 线。
///
/// 分组标题行下的线由标题行自己画，所以紧接在标题下的第一行上面不再画线；警告行与失败说明这类不是普通行的内容上下都不画线。
struct SettingTable<Content: View>: View {
    /// 表格的各行。
    @ViewBuilder
    let content: () -> Content

    /// 各行依次排列，普通行与上一行都是普通行时在上缘画线。
    var body: some View {
        Group(subviews: content()) { subviews in
            VStack(alignment: .leading, spacing: 0) {
                ForEach(subviews.indices, id: \.self) { index in
                    subviews[index]
                        .overlay(alignment: .top) {
                            if Self.drawsLine(above: index, in: subviews) {
                                SettingTableLine()
                                    .padding(.leading, SettingTableMetrics.valueColumn)
                            }
                        }
                }
            }
        }
    }

    /// 这一行与上一行都是普通行时，在它的上缘画线。
    ///
    /// - Parameters:
    ///   - index: 行的序号。
    ///   - subviews: 表格的全部行。
    private static func drawsLine(above index: Int, in subviews: SubviewsCollection) -> Bool {
        index > 0
            && subviews[index].containerValues.isSettingRow
            && subviews[index - 1].containerValues.isSettingRow
    }
}

// MARK: - SettingTableRow

/// 设置表格普通行的骨架：右对齐的次级色标签占标签列，值列放调用方给的内容；行高至少 36 pt。
struct SettingTableRow<Value: View>: View {
    /// 左侧标签；空字符串表示延续上一行的标签。
    let label: String

    /// 行的最小高度。
    var minHeight = SettingTableMetrics.rowHeight

    /// 值列的内容，从值列左缘排到行的右端。
    @ViewBuilder
    let value: () -> Value

    /// 标签列与值列横向排列。
    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(width: SettingTableMetrics.labelWidth, alignment: .trailing)
                .padding(.trailing, SettingTableMetrics.valueSpacing)

            value()
        }
        .padding(.horizontal, SettingTableMetrics.inset)
        .frame(minHeight: minHeight)
        .containerValue(\.isSettingRow, true)
    }
}

// MARK: - RemoteSettingAction

/// 设置表格一行的一个操作按钮。
struct RemoteSettingAction: Identifiable {
    /// 按钮标题，也是操作的身份。
    let title: String

    /// 仓库不可写时禁用。
    let isEnabled: Bool

    /// 点按后的动作。
    let perform: () -> Void

    /// 一行里的标题各不相同。
    var id: String { title }
}

// MARK: - RemoteSettingRow

/// 设置表格的一行：标签、可选中的 13 pt 值、可选的在 Finder 打开按钮，以及悬停或获得键盘焦点时出现的操作按钮。
///
/// 按钮淡出时仍在原处，用 Tab 可以移到它们上面；VoiceOver 把整行读作一个元素，操作经辅助功能动作执行。
struct RemoteSettingRow: View {
    /// 左侧标签；空字符串表示延续上一行的标签。
    let label: String

    /// 值。
    let value: String

    /// 值是否用次级色，如沿用获取地址的推送地址。
    var secondary = false

    /// 值右边的跟随链接按钮在 Finder 打开的本机目录；为 nil 时没有这个按钮。
    var folder: URL?

    /// 行尾的操作按钮。
    var actions: [RemoteSettingAction] = []

    /// 鼠标是否在行内。
    @State
    private var isHovering = false

    /// 获得键盘焦点的操作按钮。
    @FocusState
    private var focusedAction: String?

    /// 标签、值、跟随链接按钮与操作按钮横向排列。
    var body: some View {
        SettingTableRow(label: label) {
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(secondary ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .textSelection(.enabled)

            if let folder {
                FollowLinkButton(folder: folder)
                    .padding(.leading, 6)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(actions) { action in
                    Button(action.title, action: action.perform)
                        .controlSize(.small)
                        .disabled(!action.isEnabled)
                        .focused($focusedAction, equals: action.id)
                }
            }
            .opacity(isHovering || focusedAction != nil ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityActions {
            if let folder {
                Button(FollowLinkButton.title) { NSWorkspace.shared.open(folder) }
            }

            ForEach(actions.filter(\.isEnabled)) { action in
                Button(action.title, action: action.perform)
            }
        }
    }
}

// MARK: - RemoteSettingRow + Path

extension RemoteSettingRow {
    /// 路径一行：本机路径把家目录缩写成 “~”，右边带在 Finder 打开的按钮；服务器上的路径带主机前缀，没有按钮。
    ///
    /// - Parameters:
    ///   - label: 左侧标签。
    ///   - location: 要写的目录；为 nil 时值为空。
    ///   - canReveal: 本机目录能否在 Finder 打开，目录已不存在时为 false。
    init(label: String, location: RepositoryLocation?, canReveal: Bool = true) {
        let isLocal = location?.host == nil

        self.init(
            label: label,
            value: isLocal ? HomePath.abbreviated(location?.path ?? "") : location?.displayPath ?? "",
            folder: isLocal && canReveal ? location.map { URL(fileURLWithPath: $0.path) } : nil
        )
    }
}

// MARK: - IdentitySettingRow

/// 设置表格的提交人一行：标签、带身份档案菜单的 42 pt 头像、上下两行的姓名与邮箱，以及悬停或获得键盘焦点时出现的操作按钮。
///
/// 仓库管理的详情与仓库设置共用；VoiceOver 把整行读作一个元素，操作经辅助功能动作执行。
struct IdentitySettingRow<ProfileMenu: View>: View {
    /// 提交人；身份无法确定时为 nil，姓名一行写明未设置。
    let identity: RepositorySummary.Identity?

    /// 头像菜单是否可用。
    let isMenuEnabled: Bool

    /// 行尾的操作按钮。
    let actions: [RemoteSettingAction]

    /// 头像弹出的身份档案菜单。
    @ViewBuilder
    let menu: () -> ProfileMenu

    /// 鼠标是否在行内。
    @State
    private var isHovering = false

    /// 获得键盘焦点的操作按钮。
    @FocusState
    private var focusedAction: String?

    /// 标签、头像菜单、姓名与邮箱、操作按钮横向排列。
    var body: some View {
        SettingTableRow(label: AppLocalization.text("bookmarks.detail.identity"), minHeight: 56) {
            Menu(content: menu) {
                InitialsAvatar(name: name, email: identity?.email, size: 42)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(!isMenuEnabled)
            .accessibilityLabel(AppLocalization.text("profiles.menu"))

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                Text(identity?.email ?? "")
            }
            .font(.system(size: 13))
            .lineLimit(1)
            .truncationMode(.tail)
            .textSelection(.enabled)
            .padding(.leading, 6)

            Spacer(minLength: 8)

            actionButtons
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text("bookmarks.detail.identity"))
        .accessibilityValue(name + " " + (identity?.email ?? ""))
        .accessibilityActions {
            ForEach(actions.filter(\.isEnabled)) { action in
                Button(action.title, action: action.perform)
            }
        }
    }
}

// MARK: - RemoteSettingsGroup

/// 设置表格的分组标题行：大写的组名写在标签列里、右对齐，组的按钮常显在值列起点；行下一条从标签列左缘画起的线。
struct RemoteSettingsGroup: View {
    /// 组名，显示为大写。
    let title: String

    /// 分组的按钮；有几个时连成一组。
    var actions: [RemoteSettingAction] = []

    /// 组名与按钮在 57 pt 高的行里靠下排列。
    var body: some View {
        HStack(spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: SettingTableMetrics.labelWidth, alignment: .trailing)
                .padding(.trailing, SettingTableMetrics.valueSpacing)
                .accessibilityAddTraits(.isHeader)

            if !actions.isEmpty {
                ControlGroup {
                    ForEach(actions) { action in
                        Button(action.title, action: action.perform)
                            .disabled(!action.isEnabled)
                    }
                }
                .fixedSize()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SettingTableMetrics.inset)
        .padding(.top, 8)
        .frame(height: SettingTableMetrics.groupHeight)
        .overlay(alignment: .bottom) {
            SettingTableLine()
                .padding(.leading, SettingTableMetrics.inset)
        }
    }
}

// MARK: - SettingWarningRow

/// 状态提示行：缩进 20 pt 的提示文字与可选的常显按钮，铺警告底色。
struct SettingWarningRow: View {
    /// 提示文字。
    let text: String

    /// 行尾的按钮；为 nil 时只有文字。
    var action: RemoteSettingAction?

    /// 文字与按钮横向排列。
    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let action {
                Button(action.title, action: action.perform)
                    .controlSize(.small)
                    .disabled(!action.isEnabled)
            }
        }
        .padding(.leading, 40)
        .padding(.trailing, 20)
        .padding(.vertical, 6)
        .frame(minHeight: 30)
        .background(AppPalette.color("general_warning_bg_color"))
    }
}

// MARK: - ContainerValues + SettingRow

extension ContainerValues {
    /// 是否为设置表格的普通行；相邻两个普通行之间画分隔线。
    @Entry
    var isSettingRow = false
}

// MARK: - Private

extension IdentitySettingRow {
    /// 提交人的姓名；身份无法确定时写明未设置。
    private var name: String {
        identity?.name ?? AppLocalization.text("bookmarks.detail.noIdentity")
    }

    /// 悬停或获得焦点时淡入的按钮；淡出时仍在原处，Tab 可以移到它们上面。
    private var actionButtons: some View {
        HStack(spacing: 4) {
            ForEach(actions) { action in
                Button(action.title, action: action.perform)
                    .controlSize(.small)
                    .disabled(!action.isEnabled)
                    .focused($focusedAction, equals: action.id)
            }
        }
        .opacity(isHovering || focusedAction != nil ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}

// MARK: - FollowLinkButton

/// 值右边 18 × 18 的跟随链接按钮，在 Finder 打开一个本机目录。
private struct FollowLinkButton: View {
    /// 系统的跟随链接图，辅助功能描述由系统给出。
    static let image = NSImage(named: NSImage.followLinkFreestandingTemplateName)

    /// 按钮的辅助功能名称，取系统给图的描述。
    static var title: String { image?.accessibilityDescription ?? "" }

    /// 要打开的目录。
    let folder: URL

    /// 无边框的图形按钮。
    var body: some View {
        Button {
            NSWorkspace.shared.open(folder)
        } label: {
            if let image = Self.image {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 18, height: 18)
        .accessibilityLabel(Self.title)
    }
}

// MARK: - SettingTableLine

/// 设置表格里 1 pt 高的分隔线。
private struct SettingTableLine: View {
    /// 系统分隔线颜色的细线。
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
    }
}
