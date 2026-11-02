import AppKit
import SwiftUI

// MARK: - NSTableView + Hosting

extension NSTableView {
    /// 取出可复用的 SwiftUI 单元格并换上新内容；没有可复用的时新建。
    ///
    /// - Parameters:
    ///   - content: 单元格的内容。
    ///   - identifier: 复用的标识，同一种内容用同一个。
    func hostingView<Content: View>(_ content: Content, identifier: String) -> NSHostingView<Content> {
        let identifier = NSUserInterfaceItemIdentifier(identifier)

        let cell =
            makeView(withIdentifier: identifier, owner: nil) as? NSHostingView<Content>
                ?? NSHostingView(rootView: content)

        cell.rootView = content
        cell.identifier = identifier
        return cell
    }
}
