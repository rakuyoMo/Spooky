import Foundation
import Testing

// MARK: - ReleaseCheckTests

/// `scripts/check-release.sh`：本机开 release PR、release PR 的检查与发布工作流共用的发布前检查。
///
/// 任何一项不满足都要以非零状态退出，并说明是哪一项，发布才不会带着错误的版本号、构建号或缺失的更新说明进行。
struct ReleaseCheckTests {
    /// 版本号必须是三段不带前导零的整数，带 v、少一段或多一段都不能发布。
    @Test("版本号格式不对时拒绝", arguments: ["1.2", "01.2.0", "v1.2.0", "1.2.0.1", "1.2.x"])
    func rejectsVersionFormat(version: String) async throws {
        let fixture = try await ReleaseFixture()
        defer { fixture.remove() }

        let result = try await fixture.script("check-release.sh", version)

        #expect(result.status == 1)
        #expect(result.error.contains("版本号须为 X.Y.Z"))
    }

    /// 通道只有稳定、测试与开发三种，App 的 Updates 页按它们接收更新。
    @Test("通道不认识时拒绝")
    func rejectsChannel() async throws {
        let fixture = try await ReleaseFixture()
        defer { fixture.remove() }

        try fixture.copyReleaseNotes(version: "1.2.0")
        let result = try await fixture.script("check-release.sh", "1.2.0", "nightly")

        #expect(result.status == 1)
        #expect(result.error.contains("通道须为 stable、beta 或 development"))
    }

    /// 每种语言的更新说明都要嵌进更新清单：缺一份、或只有空白，都要一次列全。
    @Test("更新说明缺失或为空时列出全部问题")
    func rejectsMissingNotes() async throws {
        let fixture = try await ReleaseFixture()
        defer { fixture.remove() }

        try fixture.copyReleaseNotes(version: "1.2.0")

        let notes = fixture.notesDirectory(version: "1.2.0")
        try FileManager.default.removeItem(at: notes.appending(path: "zh-Hant.md"))
        try Data(" \n\t\n".utf8).write(to: notes.appending(path: "ko.md"))

        let result = try await fixture.script("check-release.sh", "1.2.0")

        #expect(result.status == 1)
        #expect(result.error.contains("缺少 docs/release-notes/1.2.0/zh-Hant.md"))
        #expect(result.error.contains("docs/release-notes/1.2.0/ko.md 没有内容"))
    }

    /// 远端已有同名标签说明这个版本发布过，再发布会让两个安装包共用一个版本号。
    @Test("远端已有同名标签时拒绝")
    func rejectsExistingTag() async throws {
        let fixture = try await ReleaseFixture()
        defer { fixture.remove() }

        try fixture.copyReleaseNotes(version: "1.2.0")
        try await fixture.git("tag", "v1.2.0")
        try await fixture.git("push", "-q", "origin", "v1.2.0")

        let result = try await fixture.script("check-release.sh", "1.2.0")

        #expect(result.status == 1)
        #expect(result.error.contains("标签 v1.2.0 在远端已存在"))
    }

    /// 构建号是更新比较新旧的依据，不是正整数就无法递增。
    @Test("当前构建号不是正整数时拒绝", arguments: ["0", "1.5", "abc"])
    func rejectsCurrentBuild(build: String) async throws {
        let fixture = try await ReleaseFixture(build: build)
        defer { fixture.remove() }

        try fixture.copyReleaseNotes(version: "1.2.0")
        let result = try await fixture.script("check-release.sh", "1.2.0")

        #expect(result.status == 1)
        #expect(result.error.contains("构建号须为正整数"))
    }

    /// 本机检查全部通过时不输出任何内容。
    @Test("本机检查通过")
    func acceptsLocalRelease() async throws {
        let fixture = try await ReleaseFixture()
        defer { fixture.remove() }

        try fixture.copyReleaseNotes(version: "1.2.0")
        let result = try await fixture.script("check-release.sh", "1.2.0", "beta")

        #expect(result.status == 0, "\(result.error)")
        #expect(result.output.isEmpty)
    }

    /// PR 标题决定发布的版本号与通道，格式不对时不能猜。
    @Test(
        "PR 标题格式不对时拒绝",
        arguments: ["release 1.2.0", "release: 1.2.0 (stable)", "release: 1.2.0 (nightly)", "release: 1.2.0 beta"]
    )
    func rejectsTitle(title: String) async throws {
        let fixture = try await releaseCommit(version: "1.2.0", build: "8")
        defer { fixture.remove() }

        let result = try await fixture.script("check-release.sh", "--title", title, "--base", "HEAD^")

        #expect(result.status == 1)
        #expect(result.error.contains("PR 标题须为"))
    }

    /// 标题里的版本号同样要满足格式。
    @Test("PR 标题里的版本号格式不对时拒绝")
    func rejectsTitleVersion() async throws {
        let fixture = try await releaseCommit(version: "1.2.0", build: "8")
        defer { fixture.remove() }

        let result = try await fixture.script("check-release.sh", "--title", "release: 1.02.0", "--base", "HEAD^")

        #expect(result.status == 1)
        #expect(result.error.contains("版本号须为 X.Y.Z"))
    }

    /// 发布的安装包里的版本号必须是标题里的版本号。
    @Test("Info.plist 的版本号与标题不一致时拒绝")
    func rejectsMismatchedVersion() async throws {
        let fixture = try await releaseCommit(version: "1.2.1", build: "8")
        defer { fixture.remove() }

        try fixture.copyReleaseNotes(version: "1.2.0")
        let result = try await fixture.script("check-release.sh", "--title", "release: 1.2.0", "--base", "HEAD^")

        #expect(result.status == 1)
        #expect(result.error.contains("Info.plist 的版本号须为 1.2.0，实际为 1.2.1"))
    }

    /// 构建号每次发布恰好加 1：不变或跳号都说明发布提交不是由发布脚本生成的。
    @Test("构建号没有比基准提交增加 1 时拒绝", arguments: ["7", "9"])
    func rejectsBuildIncrement(build: String) async throws {
        let fixture = try await releaseCommit(version: "1.2.0", build: build)
        defer { fixture.remove() }

        let result = try await fixture.script("check-release.sh", "--title", "release: 1.2.0", "--base", "HEAD^")

        #expect(result.status == 1)
        #expect(result.error.contains("构建号须从 7 增加到 8，实际为 \(build)"))
    }

    /// 检查通过后把版本号与通道交给发布工作流。
    @Test("PR 检查通过时写出版本号与通道")
    func acceptsPullRequest() async throws {
        let fixture = try await releaseCommit(version: "1.2.0", build: "8")
        defer { fixture.remove() }

        let stable = try await fixture.script("check-release.sh", "--title", "release: 1.2.0", "--base", "HEAD^")
        let beta = try await fixture.script("check-release.sh", "--title", "release: 1.2.0 (beta)", "--base", "HEAD^")

        #expect(stable.status == 0, "\(stable.error)")
        #expect(stable.output == "VERSION=1.2.0\nCHANNEL=stable\n")
        #expect(beta.output == "VERSION=1.2.0\nCHANNEL=beta\n")
    }

    /// 发布工作流与 PR 检查看到的仓库：基准提交的构建号为 7，发布提交写入给定的版本号与构建号以及更新说明。
    private func releaseCommit(version: String, build: String) async throws -> ReleaseFixture {
        let fixture = try await ReleaseFixture()

        try fixture.writeInfoPlist(version: version, build: build)
        try fixture.copyReleaseNotes(version: version)
        try await fixture.git("add", "--all")
        try await fixture.git("commit", "-q", "-m", "release: \(version)")

        return fixture
    }
}
