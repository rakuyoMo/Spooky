import AppKit
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

extension SettingsWindowTests {
    /// 姓名框结束输入后写入并重读全局配置；重读回来之前已经在邮箱框里打了字，重读只换掉变了的姓名，
    /// 不冲掉正在输入的邮箱，结束输入时写入的也是打的邮箱。
    @Test("重读全局配置不冲掉正在输入的邮箱")
    func identityReloadKeepsTypedEmail() async throws {
        let directory = try FileViewsTests.temporaryDirectory()

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let gate = try ProcessGate(in: directory)

        defer {
            gate.release()
        }

        let file = directory.appending(path: "gitconfig")
        try Data("[user]\n\tname = Old Name\n\temail = old@example.invalid\n".utf8).write(to: file)

        let runner = try Self.gatedConfigRunner(file: file, gate: gate, root: directory)
        let model = GlobalGitConfigModel(config: GlobalGitConfig(runner: runner))
        await model.reload()

        let window = Self.host(
            SettingsForm(layout: .gitConfig) {
                GitIdentityRows(model: model)
            }
        )

        let root = try #require(window.contentView)
        let fields = Self.subviews(NSTextField.self, in: root).filter(\.isEditable)

        let name = try #require(fields.first { $0.accessibilityLabel() == AppLocalization.text("gitConfig.userName") })
        let email = try #require(fields.first { $0.accessibilityLabel() == AppLocalization.text("gitConfig.email") })
        await until { email.stringValue == "old@example.invalid" }

        // 姓名带首尾空格：写入的是去掉空格的值，姓名框换成读回的值时就知道重读的结果已经显示出来
        try Data().write(to: directory.appending(path: "arm"))

        window.makeFirstResponder(name)
        let nameEditor = try #require(name.currentEditor() as? NSTextView)
        nameEditor.selectAll(nil)
        nameEditor.insertText("  New Name  ", replacementRange: nameEditor.selectedRange())

        // 转到邮箱框时姓名写入，写入后的重读停在闸门上
        window.makeFirstResponder(email)
        await gate.arrival()

        let emailEditor = try #require(email.currentEditor() as? NSTextView)
        emailEditor.selectAll(nil)
        emailEditor.insertText("typed@example.invalid", replacementRange: emailEditor.selectedRange())

        // 放行重读：姓名框显示读回的姓名，同一轮更新里邮箱框仍是正在输入的文字
        gate.release()
        await until { name.stringValue == "New Name" }

        #expect(email.currentEditor() === emailEditor)
        try #require(emailEditor.string == "typed@example.invalid")

        // 结束输入写入的是打的邮箱
        window.makeFirstResponder(nil)
        await until { model.configuration.userEmail == "typed@example.invalid" }
    }
}

// MARK: - Helpers

extension SettingsWindowTests {
    /// 读写指定全局配置文件的执行器：武装后的一次读取先读出真实结果，认领武装后停在闸门上，放行后再输出；
    /// 写入与其余读取直接交给系统 Git。
    ///
    /// - Parameters:
    ///   - file: 作为 `--global` 的配置文件。
    ///   - gate: 读取停住的闸门。
    ///   - root: 放脚本与武装文件的目录。
    private static func gatedConfigRunner(file: URL, gate: ProcessGate, root: URL) throws -> GitRunner {
        let script = root.appending(path: "config-git")
        let source = """
            #!/bin/sh
            set -eu
            root=\(GitRunner.shellQuoted(root.path))
            kind=other
            for arg in "$@"; do
                if [ "$arg" = --get-regexp ]; then kind=read; break; fi
            done
            if [ "$kind" = read ] && [ -f "$root/arm" ]; then
                held="$root/held-$$"
                /usr/bin/git "$@" > "$held"

                if mv "$root/arm" "$root/claimed" 2>/dev/null; then
                    \(gate.command)
                fi

                cat "$held"
            else
                exec /usr/bin/git "$@"
            fi

            """

        try Data(source.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)

        return GitRunner(
            location: .local(path: root.path),
            executablePath: script.path,
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": file.path,
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_PARAMETERS": nil,
                "GIT_CONFIG_COUNT": nil,
            ])
        )
    }
}
