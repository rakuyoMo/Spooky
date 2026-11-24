import Foundation
import Testing

@testable import SpookyKit

/// 提交信息的文本规则与提交选项；`-F -` 不会清理注释，所以注释行必须在提交前处理。
struct CommitMessageTests {
    /// 只认位于行首的注释前缀，前缀可以是多个字符，没有前缀时不视为注释；
    /// 折行在空格处断开且每行不超过上限，超长单词独占一行，缩进保留，结果为 NFC。
    @Test("注释行与按字数上限折行")
    func textRules() {
        let message = "标题 #1\n\n# 注释\n  # 缩进不算注释\n// 双斜线\n正文"

        #expect(CommitMessage.hasComments(message, prefix: "#"))
        #expect(
            CommitMessage.removingComments(message, prefix: "#")
                == "标题 #1\n\n  # 缩进不算注释\n// 双斜线\n正文"
        )
        #expect(
            CommitMessage.removingComments(message, prefix: "//")
                == "标题 #1\n\n# 注释\n  # 缩进不算注释\n正文"
        )
        #expect(!CommitMessage.hasComments(message, prefix: nil))
        #expect(CommitMessage.removingComments(message, prefix: nil) == message)

        // 拆分标题与正文时不按注释处理
        let parts = CommitMessage.parts(of: "# 只有注释\n\n正文\n")
        #expect(parts.subject == "# 只有注释")
        #expect(parts.body == "正文")

        // 折行
        #expect(CommitMessage.wrapped("aaa bbb ccc ddd", limit: 7) == "aaa bbb\nccc ddd")
        #expect(CommitMessage.wrapped("short", limit: 72) == "short")
        #expect(CommitMessage.wrapped("x verylongword y", limit: 4) == "x\nverylongword\ny")
        #expect(CommitMessage.wrapped("  indented words here", limit: 12) == "  indented\nwords here")
        #expect(CommitMessage.wrapped("cafe\u{301} cafe\u{301}", limit: 4) == "café\ncafé")
        #expect(
            CommitMessage.hardWrapped("one two three\n\nfour five", limit: 8)
                == "one two\nthree\n\nfour\nfive"
        )
    }

    /// 标题框只留一行：整段提交信息贴进去时其余的行不能丢，也不能挤进标题，要落到正文里；
    /// 已有的正文留着，只带一个结尾换行的单行文字不动正文。
    @Test("写进标题框的多行文字分到标题与正文")
    func multilineSubject() {
        // 标题与正文之间有没有空行都按第一行拆开，正文首尾的空行去掉、中间的留着
        var parts = CommitMessage.parts(ofMultiline: "标题\n\n第一段\n\n第二段\n", appendingTo: "")
        #expect(parts.subject == "标题")
        #expect(parts.body == "第一段\n\n第二段")

        parts = CommitMessage.parts(ofMultiline: "标题\n正文", appendingTo: "")
        #expect(parts.subject == "标题")
        #expect(parts.body == "正文")

        // 已有正文时另起一行接在后面
        parts = CommitMessage.parts(ofMultiline: "标题\n\n新的一段", appendingTo: "已有的正文")
        #expect(parts.subject == "标题")
        #expect(parts.body == "已有的正文\n新的一段")

        // 只有一行、带着结尾的换行：正文不变
        parts = CommitMessage.parts(ofMultiline: "只有一行\n", appendingTo: "已有的正文")
        #expect(parts.subject == "只有一行")
        #expect(parts.body == "已有的正文")

        // 开头的空行不算标题，CRLF 与单独的 CR 都按换行拆
        parts = CommitMessage.parts(ofMultiline: "\r\n\n标题\r\n\r\n第一行\r第二行", appendingTo: "")
        #expect(parts.subject == "标题")
        #expect(parts.body == "第一行\n第二行")
    }

    /// Unicode 信息经 stdin 规范化后提交，修补改写当前提交并可追加 Sign Off 尾注；
    /// 钩子失败保持 HEAD 与暂存区，跳过钩子时失败的 pre-commit 不拦截提交。
    @Test("提交正文、身份、Amend、Sign Off 与钩子")
    func commitOptions() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        let file = repository.directory.appending(path: "a.txt")

        try Data("one\n".utf8).write(to: file)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "cafe\u{301} ' $HOME", body: "正文\n第二行")

        // 上一条提交信息与提交身份
        let context = try await service.context(head: try await repository.runner.status().branch.oid)
        let configuration = try await service.commitConfiguration()
        #expect(configuration.userName == "Spooky Test")
        #expect(configuration.userEmail == "spooky@example.invalid")
        #expect(context.lastMessage == "café ' $HOME\n\n正文\n第二行")

        // 修补并署名，提交数不变
        try await service.commit(subject: "署名", body: "正文", amend: true, signOff: true)
        #expect(try await repository.runner.run(["rev-list", "--count", "HEAD"]) == Data("1\n".utf8))

        let message = String(decoding: try await repository.runner.run(["log", "-1", "--format=%B"]), as: UTF8.self)
        #expect(message.contains("Signed-off-by: Spooky Test <spooky@example.invalid>"))

        // 以非 1 退出的 pre-commit 拒绝修补
        let head = try await repository.runner.run(["rev-parse", "HEAD"])
        let hook = repository.directory.appending(path: ".git/hooks/pre-commit")
        try FileManager.default.createDirectory(
            at: hook.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\necho 'hook 拒绝提交' >&2\nexit 3\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)

        try Data("two\n".utf8).write(to: file)
        try await service.stageAll(staged: true)

        // 钩子失败保留它的原始输出与 Git 的退出码，暂存的改动与 HEAD 不受影响
        let error = try await #require(throws: GitError.self) {
            try await service.commit(subject: "被钩子拒绝", body: "retain", amend: true)
        }

        #expect(error.exitCode == 1)
        #expect(error.category == .commandFailed)
        #expect(String(decoding: error.result.standardError, as: UTF8.self).contains("hook 拒绝提交"))
        #expect(try await repository.runner.status().entries.contains(where: \.hasStagedChanges))
        #expect(try await repository.runner.run(["rev-parse", "HEAD"]) == head)

        // 跳过钩子后同样的改动可以提交
        try await service.commit(subject: "跳过钩子", body: "", skipHooks: true)
        #expect(try await repository.runner.status().entries.isEmpty)
    }
}
