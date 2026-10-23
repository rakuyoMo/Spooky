import SpookyKit
import SwiftUI

// MARK: - CommitFileDiffSource

/// 提交里一个文件的只读补丁来源：语法着色的两侧全文与图片两侧的内容都按同一个提交和文件读取。
///
/// 提交详情、储藏详情与文件历史的补丁都出自某个提交里的一个文件，共用这一来源。
struct CommitFileDiffSource: Sendable {
    /// 仓库的命令执行器，服务器仓库在服务器上生成补丁与读取对象。
    let runner: GitRunner

    /// 补丁所在的提交。
    let commit: String

    /// 提交里的这个文件。
    let file: CommitFileChange

    /// 开着 Diff 着色时为显示的补丁着色；全文补丁只由提交决定，按哈希复用。
    ///
    /// 全文补丁同样受大 Diff 警告阈值约束，超过阈值或识别不了语言时返回空，按纯文本显示。
    ///
    /// - Parameter diff: 正在显示的补丁；已经包含两侧全文时直接使用。
    @MainActor
    func syntax(for diff: RepositoryDiff) async -> DiffSyntax? {
        let oldPath = file.originalPath ?? file.path
        let newPath = file.path

        guard
            TextPreferences.colorsDiffSyntax,
            DiffSyntax.mayColor(diff, oldPath: oldPath, newPath: newPath)
        else { return nil }

        var full = diff

        // 显示的补丁不含两侧全文时，另取显示整个文件的补丁
        if !DiffSyntax.isEntireFile(diff, options: DiffPreferences.options()) {
            let result = try? await RepositoryHistory(runner: runner).diff(
                in: commit,
                file: file,
                options: DiffOptions(showsEntireFile: true),
                warningKilobytes: RepositorySession.diffWarningBytes / 1000
            )

            guard let parsed = result?.diff else {
                return nil
            }

            full = parsed
        }

        // 着色按全文线性扫描，大文件放到后台完成
        return await Task.detached(priority: .userInitiated) { [full] in
            DiffSyntax.make(from: full, oldPath: oldPath, newPath: newPath)
        }.value
    }

    /// 图片两侧的内容，都取自对象库。
    @MainActor
    func imageContents(of diffFile: DiffFile) async throws -> (old: Data?, new: Data?) {
        try await DiffImageSource(runner: runner).contents(
            of: diffFile,
            path: file.path,
            newFromWorkingTree: false
        )
    }
}

// MARK: - ReadOnlyFileDiffView

/// 提交里一个文件的只读补丁：只剩空白改动的说明、文件头、图片对照、二进制提示与只读的块，超过大 Diff 阈值时等待放行。
///
/// 字体、颜色、Tab 宽度、不可见字符与语法着色与工作区的 Diff 相同；提交详情、储藏详情与文件历史共用。
struct ReadOnlyFileDiffView: View {
    /// 已读取的补丁与字节数。
    let result: CommitDiff

    /// 语法着色与图片内容的来源。
    let source: CommitFileDiffSource

    /// 放行大 Diff 后重新读取。
    let showLarge: () -> Void

    /// 当前外观决定使用哪一套所选主题。
    @Environment(\.colorScheme)
    private var colorScheme

    /// 一个制表符占的空格数。
    @AppStorage(TextPreferences.tabWidthKey)
    private var tabWidth = TextPreferences.defaultTabWidth

    /// 标出不可见字符。
    @AppStorage(TextPreferences.showsInvisiblesKey)
    private var showsInvisibles = false

    /// 语法着色总开关。
    @AppStorage(TextPreferences.syntaxColoringKey)
    private var colorsSyntax = true

    /// Diff 中的语法着色。
    @AppStorage(TextPreferences.diffSyntaxColoringKey)
    private var colorsDiffSyntax = false

    /// 两侧全文的语法片段，只由提交内容决定，显示选项改变后仍然适用。
    @State
    private var syntax: DiffSyntax?

    /// 补丁较长时只排版可见的行。
    var body: some View {
        let style = TextStyle(
            theme: TextTheme.current(dark: colorScheme == .dark),
            tabWidth: tabWidth,
            showsInvisibles: showsInvisibles
        )

        LazyVStack(alignment: .leading, spacing: 0) {
            if result.onlyWhitespaceChanges {
                DiffNotice(key: "diff.onlyWhitespace", style: style)
            }

            if let diff = result.diff {
                ForEach(diff.files) { file in
                    fileDiff(file, style: style)
                }
            } else {
                Text(AppLocalization.text("working.largeDiff", (result.byteCount + 999) / 1000))
                    .padding(12)

                Button(AppLocalization.text("working.showDiff"), action: showLarge)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.color("background"))
        .task(id: syntaxKey) {
            // 换了提交、文件或补丁时先清掉旧的片段，避免套到新的行上
            syntax = nil

            guard let diff = result.diff else {
                return
            }

            syntax = await source.syntax(for: diff)
        }
    }

    /// 着色的身份：提交、文件、补丁与两个着色开关，任一变化都重新着色。
    private var syntaxKey: String {
        [
            source.commit,
            source.file.path,
            String(result.byteCount),
            String(result.diff != nil),
            String(colorsSyntax),
            String(colorsDiffSyntax),
        ]
        .joined(separator: "\u{0}")
    }

    /// 单个文件段的补丁头、图片对照或二进制提示，以及只读的块。
    @ViewBuilder
    private func fileDiff(_ file: DiffFile, style: TextStyle) -> some View {
        DiffFileHeader(file: file, style: style)

        if ImageDiffView.isImage(file, path: source.file.path) {
            // 图片换成两侧对照，两侧都取自对象库
            ImageDiffView(placement: .top, id: source.commit + "\u{0}" + source.file.path) {
                try await source.imageContents(of: file)
            }
        } else if file.isBinary {
            Text(AppLocalization.text("working.binary"))
                .padding(20)
        }

        ForEach(file.hunks) { hunk in
            DiffHunkView(
                hunk: hunk,
                style: style,
                spans: { syntax?.spans(for: $0) },
                staged: false,
                enabled: false,
                readOnly: true
            ) { _, _ in }
        }
    }
}
