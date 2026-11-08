import Foundation
import Testing

@testable import SpookyKit

/// 精确文件读写测试共用的隔离仓库，探针和日志全部留在自己的 Git 目录中。
struct WorkingCopyScopeFixture {
    /// 固定原文使两处改动仍能被 Git 识别为同一重命名。
    static let original = (1 ... 12).map { "line \($0)\n" }.joined()

    /// 每项测试独占的仓库。
    let repository: TemporaryRepository

    /// 重命名之前的路径。
    let oldPath: String

    /// 重命名后的路径。
    let newPath: String

    /// 默认执行器不经过测试包装程序。
    var runner: GitRunner { repository.runner }

    /// 当前工作区的生产服务。
    var service: WorkingCopyOperations { WorkingCopyOperations(runner: runner) }

    /// 包装程序的命令记录。
    var log: URL { repository.directory.appending(path: ".git/scope-log") }

    /// 创建隔离目录，不改变任何用户配置。
    init(oldPath: String = "old", newPath: String = "new") throws {
        repository = try TemporaryRepository()
        self.oldPath = oldPath
        self.newPath = newPath
    }

    /// 建立真实 R100 重命名，并保留一个不属于目标的文件。
    func prepare(objectFormat: String = "sha1", siblings: [String] = []) async throws {
        try await repository.initialize(objectFormat: objectFormat)
        try write(Data(Self.original.utf8), path: oldPath)
        try write(Data("unrelated\n".utf8), path: "outside")
        for path in siblings { try write(Data("sibling base\n".utf8), path: path) }
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-qm", "base"])
        let temporary = repository.directory.appending(path: ".git/moving")
        try FileManager.default.moveItem(at: repository.directory.appending(path: oldPath), to: temporary)

        if RepositoryFileViews.contains(oldPath, in: newPath) {
            try FileManager.default.removeItem(at: repository.directory.appending(path: newPath))
        }

        let target = repository.directory.appending(path: newPath)
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.moveItem(at: temporary, to: target)
        _ = try await runner.run(["add", "--all"])
        let renamed = try await entry()
        #expect(renamed.originalPath == oldPath && renamed.staged == .renamed)
    }

    /// 写入两处语义变化，可另带一处被显示选项忽略的空白变化。
    func change(whitespace: Bool = false) throws {
        try write(Data(changed(whitespace: whitespace).utf8), path: newPath)
    }

    /// 两处改动的明确原文，供成功写入的结果断言使用。
    func changed(whitespace: Bool = false) -> String {
        var text = Self.original.replacingOccurrences(of: "line 2\n", with: "changed 2\n")
            .replacingOccurrences(of: "line 10\n", with: "changed 10\n")
        if whitespace { text = text.replacingOccurrences(of: "line 6\n", with: "  line 6\n") }
        return text
    }

    /// 取真实重命名条目，不手写新的状态绑定。
    func entry() async throws -> StatusEntry {
        try #require(try await runner.status().entries.first { $0.path.utf8.elementsEqual(newPath.utf8) })
    }

    /// 写入本测试仓库里的文件，路径可以包含多个目录。
    func write(_ data: Data, path: String) throws {
        let url = repository.directory.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    /// 读取测试文件的原始字节。
    func read(_ path: String) throws -> Data {
        try Data(contentsOf: repository.directory.appending(path: path))
    }

    /// 读取命令日志，夹具初始化不使用包装程序，因此不计入测量。
    func commands() throws -> [String] {
        try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    /// 原始 Git 前后插入确定性测试动作，仍由真实 Git 提供输出与退出码。
    func wrappedRunner(before: String = "", after: String = "") throws -> GitRunner {
        let script = repository.directory.appending(path: ".git/scope-git")
        let root = GitRunner.shellQuoted(repository.directory.path)
        let source = """
            #!/bin/sh
            set -eu
            repo=\(root)
            root="$repo/.git"
            kind=other
            for arg in "$@"; do
                case "$arg" in status|diff|apply) kind="$arg"; break ;; esac
            done
            if [ "$kind" = apply ]; then
                for arg in "$@"; do
                    if [ "$arg" = --check ]; then kind=check; fi
                done
            fi
            printf '%s\\n' "$kind" >> "$root/scope-log"
            count=$(grep -c '^status$' "$root/scope-log" || true)
            \(before)
            output="$root/scope-output-$$"
            trap 'rm -f "$output"' EXIT
            code=0
            /usr/bin/git "$@" > "$output" || code=$?
            if [ "$code" -eq 0 ]; then
                \(after.isEmpty ? ":" : after)
            fi
            cat "$output"
            exit "$code"

            """
        try Data(source.utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        return repository.runner(at: repository.directory.path, executable: script.path)
    }

    /// 独立旧路径的存在、内容与未跟踪身份必须保持。
    func verifyIndependent(_ expected: Data) async throws {
        #expect(try read(oldPath) == expected)
        let entries = try await runner.status().entries
        #expect(entries.contains { $0.path == oldPath && $0.kind == .untracked })
    }
}
