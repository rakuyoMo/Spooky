import AppKit
import SpookyKit

// MARK: - Conflict Wizard

extension RepositoryWindowController {
    /// 冲突向导显示时右栏的最小宽度：两张卡片与间距再加两侧的边距。
    static let conflictWizardMinimumWidth: CGFloat = 452

    /// 工作区右栏是否显示冲突向导：只选中了一个冲突文件。
    var showsConflictWizard: Bool {
        session.activeView == .workingCopy && session.selectedEntry?.kind == .conflicted
    }

    /// 冲突向导出现时右栏放宽到最小宽度，窗口不够宽时先压窄侧边栏与文件列表；离开后两者回到原来的宽度。
    ///
    /// 变化通知早于新值写入：这时的布局还是变化前的，先记下宽度，下一轮主线程再按新值调整并重新订阅。
    func observeConflictWizard() {
        withObservationTracking {
            _ = showsConflictWizard
        } onChange: { [weak self] in
            MainActor.assumeIsolated {
                self?.conflictWizardWillChange()
            }
        }
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 向导是否显示即将变化：向导还没有显示时记下侧边栏与文件列表的宽度，下一轮主线程再按新值调整。
    private func conflictWizardWillChange() {
        let wasShown = showsConflictWizard

        if !wasShown {
            widthsBeforeConflictWizard = (
                outerSplit?.splitViewItems.first?.viewController.view.frame.width ?? 0,
                workingCopySplit?.splitViewItems.first?.viewController.view.frame.width
            )
        }

        Task { @MainActor [weak self] in
            self?.updateConflictWizardWidth(wasShown: wasShown)
            self?.observeConflictWizard()
        }
    }

    /// 按向导现在是否显示设置右栏的最小宽度；向导刚离开时放回出现前的宽度。
    ///
    /// - Parameter wasShown: 变化前向导是否显示。
    private func updateConflictWizardWidth(wasShown: Bool) {
        guard let detailItem = workingCopySplit?.splitViewItems.last else {
            return
        }

        let shows = showsConflictWizard

        detailItem.minimumThickness = shows
            ? Self.conflictWizardMinimumWidth
            : NSSplitViewItem.unspecifiedDimension

        guard wasShown, !shows, let widths = widthsBeforeConflictWizard else {
            return
        }

        // 先让放开的最小宽度生效，再移动分隔线
        window?.contentView?.layoutSubtreeIfNeeded()
        outerSplit?.splitView.setPosition(widths.sidebar, ofDividerAt: 0)

        if let list = widths.list {
            workingCopySplit?.splitView.setPosition(list, ofDividerAt: 0)
        }
    }
}
