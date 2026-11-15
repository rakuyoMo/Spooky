import Foundation
import Testing

@testable import Spooky

// MARK: - WorkingCopyFileDialogTests

/// 文件操作的输入规则：自定义规则的默认值与 Move… 保存面板选定的位置。
@MainActor
struct WorkingCopyFileDialogTests {
    /// 默认规则只匹配这一项、不带开头的 “/”，通配符照样转义；去掉 “/” 后以 # 或 ! 开头时补反斜杠，免得被当作注释与取反。
    @Test("自定义规则的默认值")
    func defaultPattern() {
        #expect(WorkingCopyFileDialog.defaultPattern(for: "Alpha.txt") == "Alpha.txt")
        #expect(WorkingCopyFileDialog.defaultPattern(for: "dir/sub/") == "dir/sub/")
        #expect(WorkingCopyFileDialog.defaultPattern(for: "docs/a*[b].md") == "docs/a\\*\\[b].md")

        // 开头的 # 与 ! 补反斜杠，路径中间的不用
        #expect(WorkingCopyFileDialog.defaultPattern(for: "#notes") == "\\#notes")
        #expect(WorkingCopyFileDialog.defaultPattern(for: "!keep") == "\\!keep")
        #expect(WorkingCopyFileDialog.defaultPattern(for: "docs/#notes") == "docs/#notes")
    }

    /// 经符号链接指向仓库里的位置照样算仓库里，结果是相对仓库根目录的路径；
    /// 仓库外、名字以仓库名开头的同级目录与仓库根目录本身都不算。
    @Test("Move… 选定的位置")
    func movePath() throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let root = directory.appending(path: "仓库 [root]")
        let sibling = directory.appending(path: "仓库 [root]2")
        let link = directory.appending(path: "link")

        try FileManager.default.createDirectory(at: root.appending(path: "sub"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)

        let path = { (url: URL) in
            RepositoryWindowController.movePath(of: url, in: root)
        }

        // 仓库里：根目录下、子目录里，以及经符号链接
        #expect(path(root.appending(path: "新 文件.txt")) == "新 文件.txt")
        #expect(path(root.appending(path: "sub/b.txt")) == "sub/b.txt")
        #expect(path(link.appending(path: "sub/c.txt")) == "sub/c.txt")

        // 仓库外
        #expect(path(directory.appending(path: "outside.txt")) == nil)
        #expect(path(sibling.appending(path: "x.txt")) == nil)
        #expect(path(root) == nil)
    }
}
