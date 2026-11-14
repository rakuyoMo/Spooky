import AppKit
import SwiftUI

// MARK: - SidebarSpringLoading

/// 拖动中停在收起的远端或文件夹上约 1 秒，把它展开，可以继续拖到里面的行；
/// 松开鼠标（放下或取消）后，把这次拖动中这样展开的收起。
@MainActor
final class SidebarSpringLoading {
    /// 停留多久后展开。
    private static let delay = Duration.seconds(1)

    /// 等待拖动结束时，两次查看鼠标按键的间隔。
    private static let pollInterval = Duration.milliseconds(200)

    /// 正在等待展开的节点。
    private var pendingNode: SidebarNodeID? = nil

    /// 等待展开的计时；离开这个节点或换到别的节点时取消。
    private var pending: Task<Void, Never>? = nil

    /// 这次拖动中悬停展开的节点与它们的展开状态，收起时逐个写回。
    private var opened: [SidebarNodeID: Binding<Bool>] = [:]

    /// 等待拖动结束后收起的任务；同一次拖动只有一个。
    private var watcher: Task<Void, Never>? = nil

    /// 落点报告拖动进入或离开一个远端或文件夹。
    ///
    /// - Parameters:
    ///   - node: 远端或文件夹的节点。
    ///   - hovering: 拖动是否停在它上面。
    ///   - expanded: 它的展开状态。
    func hover(_ node: SidebarNodeID, hovering: Bool, expanded: Binding<Bool>) {
        // 离开的不是正在等待的节点时不影响计时：进入新节点与离开旧节点的先后不固定
        guard hovering else {
            if pendingNode == node {
                cancelPending()
            }

            return
        }

        cancelPending()

        guard !expanded.wrappedValue else {
            return
        }

        pendingNode = node

        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)

            guard !Task.isCancelled, let self else {
                return
            }

            expanded.wrappedValue = true
            opened[node] = expanded
            pendingNode = nil
            watchDragEnd()
        }
    }
}

// MARK: - Private

extension SidebarSpringLoading {
    /// 取消等待中的展开。
    private func cancelPending() {
        pending?.cancel()
        pending = nil
        pendingNode = nil
    }

    /// 拖动期间鼠标左键一直按着；松开即拖动结束，这时收起悬停展开的节点。
    private func watchDragEnd() {
        guard watcher == nil else {
            return
        }

        watcher = Task { [weak self] in
            while NSEvent.pressedMouseButtons & 1 != 0 {
                try? await Task.sleep(for: Self.pollInterval)
            }

            self?.collapse()
        }
    }

    /// 收起这次拖动中悬停展开的节点，回到拖动前的展开状态。
    private func collapse() {
        cancelPending()
        watcher = nil

        for expanded in opened.values {
            expanded.wrappedValue = false
        }

        opened = [:]
    }
}
