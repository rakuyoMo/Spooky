import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - SSHHostsTests

/// SSH Hosts 页写配置文件之前的把关：文件由 SSH 与别的程序共用，写错位置或写进不合规的值都会损坏用户的配置。
@MainActor
struct SSHHostsTests {
    /// 修改按列表里的位置找别名：发起修改之后文件被别的程序改过时不能照旧位置写，改成换上新的内容、这次不写入，
    /// 选中的位置也作废；文件没变时照常写入。读不出、写不进时文件不动，原因记下来，上一次读出的列表留着。
    @Test("修改前核对文件没有被别的程序改过")
    func savesOnlyOntoListedContent() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.ssh-hosts." + UUID().uuidString)
        let url = directory.appending(path: "config")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }

        let contents = { try String(contentsOf: url, encoding: .utf8) }

        try "Host first\n    User a\n\nHost second\n    User b\n".write(to: url, atomically: true, encoding: .utf8)

        let model = SSHHostsModel(url: url)
        model.reload()
        model.selection = 1

        #expect(model.file.aliases.map(\.alias) == ["first", "second"])

        // 内容没变的重新读取不动选中的别名
        model.reload()

        #expect(model.selection == 1)

        // 点下删除之后别的程序删掉了第一个别名：列表里的第 2 个已经不是原来那一个，删除不能执行
        let listed = model.file
        let changed = "Host second\n    User b\n\nHost third\n    User c\n"
        try changed.write(to: url, atomically: true, encoding: .utf8)

        #expect(!model.save(from: listed) { $0.remove(at: 1) })
        #expect(model.failure == .changed)
        #expect(model.selection == nil)
        #expect(model.file.aliases.map(\.alias) == ["second", "third"])
        #expect(try contents() == changed)

        // 确认之前列表已经换成新的内容时也一样：按发起修改时的内容核对，不按列表当前的内容
        #expect(!model.save(from: listed) { $0.remove(at: 1) })
        #expect(try contents() == changed)

        // 文件与发起修改时相同：写入，失败的原因清掉
        #expect(model.save(from: model.file) { $0.remove(at: 1) })
        #expect(model.failure == nil)
        #expect(try contents() == "Host second\n    User b\n")

        // 目录不可写：文件不动，列表还是写入前的
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)

        #expect(!model.save(from: model.file) { $0.add(SSHHostAlias(alias: "fourth")) })

        let failedWriting = if case .write = model.failure { true } else { false }

        #expect(failedWriting)
        #expect(model.file.aliases.map(\.alias) == ["second"])
        #expect(try contents() == "Host second\n    User b\n")

        // 文件读不出：不当成空文件写回去
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try Data([0xFF, 0xFE]).write(to: url)

        #expect(!model.save(from: model.file) { $0.add(SSHHostAlias(alias: "fourth")) })

        let failedReading = if case .read = model.failure { true } else { false }

        #expect(failedReading)
        #expect(model.file.aliases.map(\.alias) == ["second"])
        #expect(try Data(contentsOf: url) == Data([0xFF, 0xFE]))
    }

    /// 没填别名时不能保存、也不报错；别名与文件里别的 `Host` 行重名时不能保存，几个名称共用的行与没有列出的行也算，
    /// 否则 SSH 会把两段的选项混在一起。编辑时不和自己比较；各项的值不合规时先报值的问题。
    @Test("对话框里别名的重名与必填")
    func editorRules() {
        let file = SSHConfigFile(text: "Host work\n    User a\n\nHost nas backup\n    User b\n\nHost home\n")
        let duplicate = AppLocalization.text("sshHosts.invalid.duplicate")

        let rule = { (alias: SSHHostAlias, index: Int?) in
            (
                SSHHostEditor.canSave(alias, at: index, in: file),
                SSHHostEditor.problem(of: alias, at: index, in: file)
            )
        }

        #expect(rule(SSHHostAlias(alias: "", hostName: "203.0.113.10"), nil) == (false, nil))
        #expect(rule(SSHHostAlias(alias: "office"), nil) == (true, nil))
        #expect(rule(SSHHostAlias(alias: "work"), nil) == (false, duplicate))
        #expect(rule(SSHHostAlias(alias: "backup"), nil) == (false, duplicate))

        // 编辑第 1 个别名：不改名可以保存，改成另一个别名的名称不行
        #expect(rule(SSHHostAlias(alias: "work", user: "c"), 0) == (true, nil))
        #expect(rule(SSHHostAlias(alias: "home"), 0) == (false, duplicate))

        // 值不合规时先报值的问题
        #expect(
            rule(SSHHostAlias(alias: "work", port: "0"), nil)
                == (false, AppLocalization.text("sshHosts.invalid.port"))
        )
    }
}
