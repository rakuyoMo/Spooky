import AppKit
import SwiftUI

// MARK: - DropBadgeAction

/// 落点上的一个有效动作：写在拖动影像上的动作名，与落下时的执行。
struct DropBadgeAction {
    /// 动作名。
    let title: String

    /// 落下时执行；返回是否接受了这次拖放。
    let perform: @MainActor () -> Bool
}

// MARK: - RepositoryDropView

/// 侧边栏行上的拖放落点：拖动中把当前动作名作为徽标加到拖动影像上，落下时执行同一个动作。
///
/// 承载的 AppKit 视图只登记拖放类型，点击穿透给所在的行，单击、双击、右键与拖动起点照常。
struct RepositoryDropView: NSViewRepresentable {
    /// 接受的粘贴板类型。
    let type: NSPasteboard.PasteboardType

    /// 按这次拖动求当前的有效动作；没有时为 nil。
    let resolve: @MainActor (any NSDraggingInfo) -> DropBadgeAction?

    /// 建出登记了拖放类型的视图。
    func makeNSView(context _: Context) -> DropTargetView {
        DropTargetView(type: type)
    }

    /// 每次更新换上最新的会话、落点与回调。
    func updateNSView(_ view: DropTargetView, context _: Context) {
        view.resolve = resolve
    }
}

// MARK: - DropTargetView

/// 落点的 AppKit 视图：拖动进入与经过时按当前动作换徽标，⌥ 不动鼠标也会随周期性的拖动更新切换。
///
/// 拖动离开后，AppKit 把落点对拖动项的改动还原，徽标随之消失。
final class DropTargetView: NSView {
    /// 按这次拖动求当前的有效动作。
    var resolve: (@MainActor (any NSDraggingInfo) -> DropBadgeAction?)? = nil

    /// 拖动影像上当前的动作名；没有徽标时为 nil。
    private var badge: String? = nil

    /// 登记这个落点接受的拖放类型。
    ///
    /// - Parameter type: 接受的粘贴板类型。
    init(type: NSPasteboard.PasteboardType) {
        super.init(frame: .zero)

        registerForDraggedTypes([type])
    }

    /// 不从 nib 创建。
    required init?(coder _: NSCoder) { nil }

    /// 普通点击穿透给所在的行。
    override func hitTest(_: NSPoint) -> NSView? { nil }

    /// 进入时拖动影像是来源给出的原样，按当前动作加徽标。
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        badge = nil
        return update(sender)
    }

    /// 移动、修饰键变化与周期性更新时重新求动作。
    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        update(sender)
    }

    /// 离开后 AppKit 已还原拖动影像。
    override func draggingExited(_: (any NSDraggingInfo)?) {
        badge = nil
    }

    /// 落下时再求一次动作，没有有效动作就不接受。
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let action = resolve?(sender) else {
            return false
        }

        return action.perform()
    }
}

// MARK: - Private

extension DropTargetView {
    /// 求当前动作，动作名变了才换徽标；无效时去掉徽标并拒绝。
    private func update(_ info: any NSDraggingInfo) -> NSDragOperation {
        let action = resolve?(info)

        if action?.title != badge {
            badge = action?.title

            // 徽标只加给第一个拖动项
            info.enumerateDraggingItems(
                options: [],
                for: self,
                classes: [NSPasteboardItem.self],
                searchOptions: [:]
            ) { item, _, stop in
                DragBadge.apply(action?.title, to: item)
                stop.pointee = true
            }
        }

        return action == nil ? [] : .copy
    }
}

// MARK: - DragBadge

/// 拖动影像上的动作徽标：白底圆角 4、高 24、宽为文字宽 + 16，13 pt 粗体强调色文字，放在影像右侧 10 pt 处并竖直居中。
@MainActor
enum DragBadge {
    /// 徽标在拖动项图像组件里的键。
    static let key = NSDraggingItem.ImageComponentKey("com.rakuyo.spooky.drag-action")

    /// 换掉或去掉拖动项上的徽标，来源给出的其它组件原样保留，不改拖动项的位置。
    ///
    /// - Parameters:
    ///   - title: 动作名；为 nil 时去掉徽标。
    ///   - item: 拖动项。
    static func apply(_ title: String?, to item: NSDraggingItem) {
        // 组件按 provider 重新取：已取过的 imageComponents 会缓存，换了 provider 也读不到新值
        let base = item.imageComponentsProvider?().filter { $0.key != key } ?? []
        let bounds = base.map(\.frame).reduce(NSRect.null) { $0.union($1) }

        guard let title, !bounds.isNull else {
            item.imageComponentsProvider = { base }
            return
        }

        let image = image(title)
        let badge = NSDraggingImageComponent(key: key)
        badge.contents = image

        badge.frame = NSRect(
            x: bounds.maxX + 10,
            y: bounds.midY - image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        )

        item.imageComponentsProvider = { base + [badge] }
    }

    /// 徽标的图像，绘制时取当前外观的强调色。
    private static func image(_ title: String) -> NSImage {
        let text = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: NSColor.controlAccentColor,
            ]
        )

        let size = NSSize(width: ceil(text.size().width) + 16, height: 24)

        return NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

            text.draw(at: NSPoint(x: 8, y: (rect.height - text.size().height) / 2))
            return true
        }
    }
}
