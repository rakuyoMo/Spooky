import Foundation
import Testing

// MARK: - ReleaseScriptTests

/// `scripts/release.sh`：检查通过后切出发布分支、写入版本号与构建号并开 release PR。
///
/// `gh` 换成测试目录里的替身：登录检查与仓库查询总是通过，开 PR 按环境变量成功或失败，调用参数记进日志。
struct ReleaseScriptTests {
    /// 测试用的 `gh`：记下参数；`GH_FAIL_PR` 非空时开 PR 失败。
    private static let fakeGH = """
        #!/bin/bash
        echo "$*" >> "$GH_LOG"

        case "$1 $2" in
            "auth status") exit 0 ;;
            "repo view") echo false ;;

            "pr create")
                if [[ -n "${GH_FAIL_PR:-}" ]]; then
                    echo "pull request create failed" >&2
                    exit 1
                fi

                echo "https://github.com/rakuyoMo/Spooky/pull/1"
                ;;
        esac
        """

    /// 发布分支只从 main 切出。
    @Test("不在 main 分支时拒绝")
    func rejectsOtherBranch() async throws {
        let fixture = try await ReleaseFixture()
        defer { fixture.remove() }

        try fixture.copyReleaseNotes(version: "1.2.0")
        try await fixture.git("switch", "-q", "-c", "feature")

        let result = try await release(fixture, "1.2.0")

        #expect(result.status == 1)
        #expect(result.error.contains("须在 main 分支上运行，当前分支：feature"))
    }

    /// 更新说明以外的改动会混进发布提交。
    @Test("工作区有其它改动时拒绝")
    func rejectsDirtyWorkTree() async throws {
        let fixture = try await ReleaseFixture()
        defer { fixture.remove() }

        try fixture.copyReleaseNotes(version: "1.2.0")
        try Data("改动\n".utf8).write(to: fixture.workTree.appending(path: "README.md"))

        let result = try await release(fixture, "1.2.0")

        #expect(result.status == 1)
        #expect(result.error.contains("工作区有未提交的改动或未跟踪的文件"))
    }

    /// 开 PR 失败时撤回发布分支：本机与远端都不留下，版本号不变，更新说明留在工作区，修好后可以直接重试。
    @Test("开 PR 失败时撤回本机与远端的发布分支")
    func discardsBranchWhenPullRequestFails() async throws {
        let fixture = try await ReleaseFixture()
        defer { fixture.remove() }

        try fixture.copyReleaseNotes(version: "1.2.0")
        let result = try await release(fixture, "1.2.0", environment: ["GH_FAIL_PR": "1"])

        #expect(result.status == 1)
        #expect(result.error.contains("创建 PR 失败"))

        let localBranches = try await fixture.git("branch", "--list", "release/*")
        let remoteBranches = try await fixture.git("ls-remote", "--heads", "origin")
        let currentBranch = try await fixture.git("branch", "--show-current")

        #expect(localBranches.isEmpty)
        #expect(!remoteBranches.contains("release/1.2.0"))
        #expect(currentBranch == "main\n")
        #expect(try fixture.infoPlistValue("CFBundleShortVersionString") == "1.1.0")
        #expect(try fixture.infoPlistValue("CFBundleVersion") == "7")
        #expect(FileManager.default.fileExists(atPath: fixture.notesDirectory(version: "1.2.0").appending(path: "en.md").path))
    }

    /// 成功时发布分支在远端，提交写入版本号与加 1 的构建号，PR 标题带上通道；本机回到 main。
    @Test("开出 release PR")
    func opensPullRequest() async throws {
        let fixture = try await ReleaseFixture()
        defer { fixture.remove() }

        try fixture.copyReleaseNotes(version: "1.2.0")
        let result = try await release(fixture, "1.2.0", "beta")

        #expect(result.status == 0, "\(result.error)")
        #expect(result.output.contains("已创建 PR：https://github.com/rakuyoMo/Spooky/pull/1"))

        let message = try await fixture.git("log", "-1", "--format=%s", "origin/release/1.2.0")
        let plist = try await fixture.git("show", "origin/release/1.2.0:Sources/Spooky/Info.plist")
        let notes = try await fixture.git("ls-tree", "--name-only", "origin/release/1.2.0", "docs/release-notes/1.2.0/")
        let currentBranch = try await fixture.git("branch", "--show-current")
        let log = try String(contentsOf: fixture.root.appending(path: "gh.log"), encoding: .utf8)

        #expect(message == "release: 1.2.0 (beta)\n")
        #expect(plist.contains("<string>1.2.0</string>"))
        #expect(plist.contains("<string>8</string>"))
        #expect(notes.split(separator: "\n").count == 8)
        #expect(currentBranch == "main\n")
        #expect(log.contains("--title release: 1.2.0 (beta)"))
    }

    /// 以测试用的 `gh` 运行发布脚本。
    private func release(
        _ fixture: ReleaseFixture,
        _ arguments: String...,
        environment: [String: String] = [:]
    ) async throws -> CommandResult {
        let bin = fixture.root.appending(path: "bin")
        let gh = bin.appending(path: "gh")

        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try Data(Self.fakeGH.utf8).write(to: gh)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: gh.path)

        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"

        var overrides = environment
        overrides["PATH"] = bin.path + ":" + path
        overrides["GH_LOG"] = fixture.root.appending(path: "gh.log").path

        return try await ReleaseFixture.run(
            fixture.workTree.appending(path: "scripts/release.sh").path,
            arguments,
            in: fixture.workTree,
            environment: overrides
        )
    }
}
