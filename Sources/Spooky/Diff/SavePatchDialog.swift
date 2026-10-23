import SwiftUI

// MARK: - SavePatchDialog

/// 保存补丁的对话框：说明范围，选择是否省略路径前缀；确认后再选择保存位置。
struct SavePatchDialog: View {
    /// 写进补丁的文件数。
    let count: Int

    /// 取消只关闭对话框。
    let cancel: () -> Void

    /// 确认时交出是否省略前缀。
    let submit: (Bool) -> Void

    /// 省略前缀的选择跨仓库记忆。
    @AppStorage(DiffPreferences.omitsPatchPrefixesKey)
    private var omitsPrefixes = false

    /// 头部、选项与底栏。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 4) {
                Toggle(AppLocalization.text("diff.omitPrefixes"), isOn: $omitsPrefixes)

                Text(AppLocalization.text("diff.omitPrefixes.help"))
                    .font(.system(size: 11))
                    .padding(.leading, 19)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 112)
            .padding(.trailing, 20)
            .padding(.vertical, 20)

            footer
        }
        .frame(width: 480)
    }

    /// 64 pt 的图标，右侧是标题与说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text("diff.savePatch.title"))
                    .font(.system(size: 14, weight: .bold))

                Text(AppLocalization.text("diff.savePatch.message", count))
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 取消与保存按钮。
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(AppLocalization.text("action.cancel"), action: cancel)
                .keyboardShortcut(.cancelAction)

            Button(AppLocalization.text("diff.savePatch.submit")) { submit(omitsPrefixes) }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .frame(height: 53)
    }
}
