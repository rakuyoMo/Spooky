import SwiftUI

// MARK: - SidebarReveal

/// 侧边栏程序化定位的进度：滚动到选中的引用行，并核对它确实落在列表内。
///
/// 列表按固定档位的默认行高估计尚未显示的行的位置，条目行实际更高时，第一次滚动会停在目标行之前。
/// 目标行报告它在窗口里的位置；列表每次滚动后，目标行还没落进列表就按新的排版再滚，最多滚动 `maximumAttempts` 次。
@MainActor
@Observable
final class SidebarReveal {
    /// 一次定位最多滚动的次数。
    static let maximumAttempts = 5

    /// 要滚到的行；nil 时没有进行中的定位。
    private(set) var target: SidebarNodeID? = nil

    /// 列表在窗口里的位置，目标行完整落在其中才算可见。
    @ObservationIgnored
    var listFrame = CGRect.zero

    /// 侧边栏列表的滚动代理。
    @ObservationIgnored
    private var proxy: ScrollViewProxy?

    /// 本次定位已滚动的次数。
    @ObservationIgnored
    private var attempts = 0

    /// 开始定位一行，替换进行中的定位。
    ///
    /// - Parameters:
    ///   - target: 要滚到的行。
    ///   - proxy: 侧边栏列表的滚动代理。
    func start(_ target: SidebarNodeID, proxy: ScrollViewProxy) {
        self.target = target
        self.proxy = proxy
        attempts = 0

        scroll()
    }

    /// 目标行的位置变化：完整落在列表内时结束定位。
    ///
    /// - Parameter frame: 目标行在窗口里的位置。
    func targetMoved(to frame: CGRect) {
        guard
            listFrame.minY <= frame.minY,
            frame.maxY <= listFrame.maxY
        else {
            return
        }

        finish()
    }

    /// 列表滚动之后：定位还没结束就按新的排版再滚，次数用完时放弃。
    func listScrolled() {
        guard target != nil else {
            return
        }

        guard attempts < Self.maximumAttempts else {
            finish()
            return
        }

        scroll()
    }

    /// 结束定位，不再响应列表滚动。
    private func finish() {
        target = nil
        proxy = nil
    }

    /// 滚动到目标行，计入次数。
    private func scroll() {
        attempts += 1

        // 刚展开的行在这次更新之后才进入列表，下一轮再滚动；其间定位已结束时不滚
        Task { @MainActor in
            guard let target else {
                return
            }

            proxy?.scrollTo(target)
        }
    }
}

// MARK: - SidebarRevealAnchor

/// 放在引用行背景里的透明视图：这一行是定位的目标行时，把整行在窗口里的位置报告给定位进度。
///
/// 只能放在背景里：直接在行上读取位置时，列表读不到行的选择标签，选中的行不会高亮。
struct SidebarRevealAnchor: View {
    /// 这一行的滚动身份。
    let id: SidebarNodeID

    /// 侧边栏的定位进度。
    @Environment(SidebarReveal.self)
    private var reveal: SidebarReveal?

    /// 这一行的档位，决定行高。
    @Environment(\.sidebarRowSize)
    private var rowSize

    /// 只有目标行读取位置，其余行的读取结果始终是 nil。
    var body: some View {
        let isTarget = reveal?.target == id
        let height = rowSize.rowHeight

        Color.clear.onGeometryChange(for: CGRect?.self) { proxy in
            guard isTarget else {
                return nil
            }

            // 行内容在定高的行里上下居中，按行高扩成整行
            let frame = proxy.frame(in: .global)
            return frame.insetBy(dx: 0, dy: (frame.height - height) / 2)
        } action: { frame in
            guard let frame else {
                return
            }

            reveal?.targetMoved(to: frame)
        }
    }
}
