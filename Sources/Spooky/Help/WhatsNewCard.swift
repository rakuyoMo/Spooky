import SwiftUI

// MARK: - WhatsNewCard

/// 新版本第一次启动时仓库窗口侧边栏底部的新功能卡片：Learn More… 打开当前版本的说明，× 只关掉卡片。
///
/// 所有仓库窗口共用 `WhatsNewState` 的显示状态，在任一窗口里关掉后都消失。
struct WhatsNewCard: View {
    /// 卡片的显示状态与当前版本。
    let state: WhatsNewState

    /// 左右各缩进 12 pt 的圆角卡片：左边 sparkles 图标，右边标题、一句介绍与链接，右上角 ×。
    var body: some View {
        if state.showsCard {
            HStack(alignment: .top, spacing: 0) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 38, alignment: .leading)
                    .accessibilityHidden(true)

                content
            }
            .padding(.leading, 12)
            .padding(.trailing, 24)
            .padding(.vertical, 12)
            .overlay(alignment: .topTrailing) {
                closeButton
            }
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor.opacity(0.16), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
    }

    /// 标题、带版本号的介绍与 Learn More… 链接。
    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(AppLocalization.text("whatsNew.card.title"))
                .font(.system(size: 13, weight: .bold))

            Text(AppLocalization.text("whatsNew.card.message", state.currentVersion))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(AppLocalization.text("whatsNew.card.learnMore")) {
                state.learnMore()
                WhatsNewWindowController.show(selecting: state.currentVersion)
            }
            .buttonStyle(.link)
            .foregroundStyle(Color.accentColor)
            .font(.system(size: 11))
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 右上角的 ×：卡片消失，不记已读。
    private var closeButton: some View {
        Button {
            state.dismissCard()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 17, height: 17)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(9)
        .accessibilityLabel(AppLocalization.text("action.close"))
    }
}
