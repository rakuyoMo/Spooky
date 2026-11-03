import AppKit
import SwiftUI

// MARK: - GitErrorDialog

/// Git 错误框：骨架的错误版，挂在仓库窗口上，窗口可以拉大。
///
/// 头部是系统的警告图标、错误标题，说明是原因与恢复步骤，空一行后是类别与仓库位置；
/// Git 原文在默认展开的 “Git Error Message” 区里，随窗口拉大而变大。
/// 底栏只有 Close，打开仓库失败时 Close 左侧另有 Choose Another Folder…。
struct GitErrorDialog: View {
    /// 要报告的错误。
    let failure: AppFailure

    /// 关掉对话框。
    let close: () -> Void

    /// 打开仓库失败时重新选择，对话框已经关掉；为 nil 时底栏只有 Close。
    let chooseAnother: (() -> Void)?

    /// 头部、头部与开关之间 8 pt 的内容区、默认展开的原文区与底栏。
    var body: some View {
        DialogLayout(
            title: failure.title,
            message: failure.message + "\n\n" + failure.context,
            icon: NSImage(named: NSImage.cautionName),
            submitTitle: AppLocalization.text("action.close"),
            alternate: chooseAnother.map { choose in
                (AppLocalization.text("action.chooseAnother"), {
                    close()
                    choose()
                })
            },
            optionsTitle: AppLocalization.text("error.gitMessage"),
            optionsExpanded: true,
            resizable: true,
            cancel: nil,
            submit: close,
            content: {
                Color.clear
                    .frame(height: 8)
            },
            options: {
                // 首选高 175：四周各留 20，中间是原文区；1 pt 的边框是露在原文区四周的边框色
                GitErrorText(text: failure.details)
                    .frame(minHeight: 135, idealHeight: 135, maxHeight: .infinity)
                    .padding(1)
                    .background(AppPalette.color("general_border_color"))
                    .padding(20)
            }
        )
    }
}

// MARK: - GitErrorText

/// Git 原文：可以滚动与选中的等宽 11 pt 次要色文字，底色是控件背景色；外面一圈 1 pt 的边框由调用方画。
private struct GitErrorText: NSViewRepresentable {
    /// 原文。
    let text: String

    /// 只读、可选中的纯文本视图，宽度随滚动区，长行折行。
    func makeNSView(context _: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.borderType = .noBorder
        scroll.backgroundColor = .controlBackgroundColor

        guard let textView = scroll.documentView as? NSTextView else {
            return scroll
        }

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .secondaryLabelColor
        textView.backgroundColor = .controlBackgroundColor
        textView.string = text
        textView.setAccessibilityLabel(AppLocalization.text("error.details"))

        return scroll
    }

    /// 原文变了才重写，免得冲掉已有的选中。
    func updateNSView(_ scroll: NSScrollView, context _: Context) {
        guard let textView = scroll.documentView as? NSTextView, textView.string != text else {
            return
        }

        textView.string = text
    }
}
