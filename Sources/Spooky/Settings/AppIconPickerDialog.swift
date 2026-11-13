import AppKit
import SwiftUI

// MARK: - AppIconPickerDialog

/// 选择应用图标的对话框：对话框骨架里每组一行的单选列表，底栏是取消与 Choose。
///
/// 按 Choose 或双击一行时先写入或清除 App 包的自定义图标，写完才关闭；写不进去时错误区写出原因，对话框不关，所选的组不变。
struct AppIconPickerDialog: View {
    /// 列表一行的高度：48 pt 的图标，加上列表给每行上下各留的 4 pt。
    private static let rowHeight: CGFloat = 56

    /// App 图标的控制器。
    let controller: AppIconController

    /// 关闭对话框。
    let close: () -> Void

    /// 列表里选中的组；打开时是当前所选的组。
    @State
    private var selection: AppIconGroup

    /// 写入失败的说明；为 nil 时错误区收起。
    @State
    private var error: String? = nil

    /// 是否正在写入：底栏的按钮与列表都不可用。
    @State
    private var isWriting = false

    /// 列表是否有键盘焦点：打开时就给它，↑ ↓ 直接换行。
    @FocusState
    private var listFocused: Bool

    /// 对话框骨架里放对齐输入列的列表；写入期间底栏两个按钮都不可用。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("appIcon.choose"),
            message: AppLocalization.text("appIcon.choose.message"),
            submitTitle: AppLocalization.text("appIcon.choose.submit"),
            error: error,
            submitting: isWriting,
            cancel: close,
            submit: choose
        ) {
            DialogForm {
                DialogFormField {
                    list
                }
            }
        }
    }

    /// 创建对话框，列表选中当前所选的组。
    /// - Parameters:
    ///   - controller: App 图标的控制器
    ///   - close: 关闭对话框
    init(
        controller: AppIconController,
        close: @escaping () -> Void
    ) {
        self.controller = controller
        self.close = close
        _selection = State(initialValue: controller.group)
    }
}

// MARK: - Presenting

extension AppIconPickerDialog {
    /// 在设置窗口上以 sheet 打开对话框；没有窗口时不打开。
    ///
    /// - Parameters:
    ///   - controller: App 图标的控制器。
    ///   - window: 设置窗口。
    static func present(controller: AppIconController, in window: NSWindow?) {
        guard let window else {
            return
        }

        DialogWindow.present(on: window) { close in
            AppIconPickerDialog(controller: controller, close: close)
        }
    }
}

// MARK: - Private

extension AppIconPickerDialog {
    /// 每组一行，双击一行等于按 Choose；高度刚好露出全部的组，另加列表上下各 1 pt 的边框，不出现滚动条。
    private var list: some View {
        List(selection: selectionBinding) {
            ForEach(AppIconGroup.allCases) { group in
                row(group)
                    .tag(group)
            }
        }
        .listStyle(.bordered)
        .frame(height: CGFloat(AppIconGroup.allCases.count) * Self.rowHeight + 2)
        .focused($listFocused)
        .disabled(isWriting)
        .contextMenu(forSelectionType: AppIconGroup.self) { _ in
            EmptyView()
        } primaryAction: { groups in
            // 双击的那一行此时已经选中
            if let group = groups.first {
                selection = group
            }

            choose()
        }
        .onAppear { listFocused = true }
    }

    /// 单选列表的选择：点空白处不会清空，总有一组选中。
    private var selectionBinding: Binding<AppIconGroup?> {
        Binding(
            get: { selection },
            set: { group in
                if let group {
                    selection = group
                }
            }
        )
    }

    /// 一组：左侧是组名，右侧是当前深浅下指示灯灭着与亮着的两张 48 pt 图标；VoiceOver 只读组名。
    /// - Parameter group: 这一行的组
    private func row(_ group: AppIconGroup) -> some View {
        HStack(spacing: 8) {
            Text(group.title)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach([false, true], id: \.self) { isConnected in
                Image(nsImage: controller.bundledIcon(of: group, isConnected: isConnected) ?? NSImage())
                    .resizable()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
            }
        }
    }

    /// 换成选中的组：写完关闭对话框；写不进去时在错误区写出原因，对话框不关。
    private func choose() {
        // 写入期间双击列表也会走到这里
        guard !isWriting else {
            return
        }

        isWriting = true
        error = nil

        Task {
            do {
                try await controller.select(selection)
                close()
            } catch {
                self.error = error.localizedDescription
                isWriting = false
            }
        }
    }
}
