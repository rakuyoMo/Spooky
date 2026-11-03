import Foundation
import SwiftUI

// MARK: - ActivityIcon

/// Activity 窗口与侧边栏活动区里一行的图标：SF 符号，或传输方向的自绘图标。
enum ActivityIcon: Equatable {
    /// SF 符号。
    case symbol(String)

    /// 传输方向的自绘图标，与工具栏对应的段相同。
    case transfer(ActivityTransfer)

    /// 图标的图像；自绘的模板图随前景色着色。
    @MainActor
    var image: Image {
        switch self {
        case .symbol(let name):
            Image(systemName: name)

        case .transfer(let transfer):
            Image(nsImage: TransferIcon.image(for: transfer)).renderingMode(.template)
        }
    }
}

// MARK: - Display

extension RepositoryActivity {
    /// 显示的标题，Activity 窗口与侧边栏底部的活动区共用。
    ///
    /// Remote 页按传输方向与状态写动词，后接远端名与 refspec，如 “Fetched origin” “Pulling origin refs/heads/main”；
    /// 失败与取消在进行时的写法后面接 failed、cancelled。较早保存、没有方向的 Remote 记录与其余两页写操作名称。
    var displayTitle: String {
        guard kind == .remote, let target else {
            return title
        }

        // 完成的用过去时，其余用进行时，如 “activity.fetched” “activity.fetching”；有远端名时用带名字的 “…Named”
        let tense = state == "activity.finished" ? "ed" : "ing"
        let key = "activity." + target.transfer.rawValue + tense

        // 远端名后接 refspec，如 “origin refs/heads/main”
        let name = target.remote.map { remote in
            [remote, target.refspec].compactMap(\.self).joined(separator: " ")
        }
        let action = name.map { AppLocalization.text(key + "Named", $0) } ?? AppLocalization.text(key)

        switch state {
        case "activity.failed": return AppLocalization.text("activity.titleFailed", action)
        case "activity.cancelled": return AppLocalization.text("activity.titleCancelled", action)
        default: return action
        }
    }

    /// Remote 记录按传输方向取的图标，与工具栏对应的段相同，不随失败与取消变化；
    /// 较早保存、没有方向的记录与拉取同用一个图标。
    var transferIcon: ActivityIcon {
        .transfer(target?.transfer ?? .pull)
    }
}
