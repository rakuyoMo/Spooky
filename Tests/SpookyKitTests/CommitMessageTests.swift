import Foundation
import Testing

@testable import SpookyKit

/// 提交信息的文本规则与提交选项；`-F -` 不会清理注释，所以注释行必须在提交前处理。
struct CommitMessageTests {
    /// 只认位于行首的注释前缀，前缀可以是多个字符；没有前缀时不视为注释。
    @Test("识别并去掉注释行")
    func comments() {
        let message = "标题 #1\n\n# 注释\n  # 缩进不算注释\n// 双斜线\n正文"

        #expect(CommitMessage.hasComments(message, prefix: "#"))
        #expect(CommitMessage.removingComments(message, prefix: "#") == "标题 #1\n\n  # 缩进不算注释\n// 双斜线\n正文")
        #expect(CommitMessage.removingComments(message, prefix: "//") == "标题 #1\n\n# 注释\n  # 缩进不算注释\n正文")
        #expect(!CommitMessage.hasComments(message, prefix: nil))
        #expect(CommitMessage.removingComments(message, prefix: nil) == message)

        let parts = CommitMessage.parts(of: "# 只有注释\n\n正文\n")
        #expect(parts.subject == "# 只有注释")
        #expect(parts.body == "正文")
    }

    /// 段落在空格处断开且每行不超过上限；超长单词独占一行；缩进保留；结果为 NFC。
    @Test("按字数上限折行")
    func wrapping() {
        #expect(CommitMessage.wrapped("aaa bbb ccc ddd", limit: 7) == "aaa bbb\nccc ddd")
        #expect(CommitMessage.wrapped("short", limit: 72) == "short")
        #expect(CommitMessage.wrapped("x verylongword y", limit: 4) == "x\nverylongword\ny")
        #expect(CommitMessage.wrapped("  indented words here", limit: 12) == "  indented\nwords here")
        #expect(CommitMessage.wrapped("cafe\u{301} cafe\u{301}", limit: 4) == "café\ncafé")
        #expect(CommitMessage.hardWrapped("one two three\n\nfour five", limit: 8) == "one two\nthree\n\nfour\nfive")
    }

    /// Sign Off 追加尾注；跳过钩子时失败的 pre-commit 不再拦截提交。
    @Test("Sign Off 与跳过钩子")
    func commitOptions() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let service = WorkingCopyOperations(runner: repository.runner)
        try Data("one\n".utf8).write(to: repository.directory.appending(path: "a.txt"))
        try await service.stageAll(staged: true)
        try await service.commit(subject: "署名", body: "", signOff: true)

        let message = String(decoding: try await repository.runner.run(["log", "-1", "--format=%B"]), as: UTF8.self)
        #expect(message.contains("Signed-off-by: Spooky Test <spooky@example.invalid>"))

        let hook = repository.directory.appending(path: ".git/hooks/pre-commit")
        try FileManager.default.createDirectory(
            at: hook.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\necho 'hook 拒绝提交' >&2\nexit 3\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)
        try Data("two\n".utf8).write(to: repository.directory.appending(path: "a.txt"))
        try await service.stageAll(staged: true)

        // 钩子失败保留它的原始输出与 Git 的退出码，暂存的改动不受影响
        let error = try await #require(throws: GitError.self) {
            try await service.commit(subject: "被钩子拒绝", body: "")
        }
        #expect(error.exitCode == 1)
        #expect(error.category == .commandFailed)
        #expect(String(decoding: error.result.standardError, as: UTF8.self).contains("hook 拒绝提交"))
        #expect(try await repository.runner.status().entries.contains(where: \.hasStagedChanges))

        try await service.commit(subject: "跳过钩子", body: "", skipHooks: true)
        #expect(try await repository.runner.status().entries.isEmpty)
    }
}
