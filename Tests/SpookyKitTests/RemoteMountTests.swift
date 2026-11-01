import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteMountTests

/// 服务器目录在这台 Mac 上的挂载位置：在卷里按后缀找到候选目录，经标记文件核对是同一个目录才算。
///
/// 用指向 “服务器” 目录的符号链接模拟挂载卷；“服务器” 与本机是同一台机器，执行器直接在本机执行 Git。
struct RemoteMountTests {
    /// `ssh -G` 每行是小写的选项名与值，只取 `hostname` 一行；没有这一行或值为空时取不到。
    @Test("从 ssh -G 的输出取主机")
    func hostname() {
        let output = "user wgy\nhostkeyalias other\nhostname 192.168.1.20\nport 22\n"

        #expect(RemoteMountLocator.hostname(fromConfiguration: output) == "192.168.1.20")
        #expect(RemoteMountLocator.hostname(fromConfiguration: "hostname b.example.lan\r\n") == "b.example.lan")
        #expect(RemoteMountLocator.hostname(fromConfiguration: "user wgy\nport 22\n") == nil)
        #expect(RemoteMountLocator.hostname(fromConfiguration: "hostname \n") == nil)
        #expect(RemoteMountLocator.hostname(fromConfiguration: "") == nil)
    }

    /// B 上目录里的路径按目录边界换算，目录本身对应本机目录；只是名字开头相同的兄弟目录不算在里面。
    @Test("按目录换算路径")
    func mapping() {
        let local = URL(filePath: "/Volumes/share")
        let mount = RemoteMount(remotePath: "/srv/git/", localURL: local)

        #expect(mount.remotePath == "/srv/git")
        #expect(mount.localURL(for: "/srv/git")?.path == "/Volumes/share")
        #expect(mount.localURL(for: "/srv/git/仓 库/a [1].txt")?.path == "/Volumes/share/仓 库/a [1].txt")
        #expect(mount.localURL(for: "/srv/gitlab/repo") == nil)
        #expect(mount.localURL(for: "/srv") == nil)

        let root = RemoteMount(remotePath: "/", localURL: local)
        #expect(root.localURL(for: "/srv/git")?.path == "/Volumes/share/srv/git")
    }

    /// 卷里的目录与 B 上的仓库是同一个目录时核对通过，换算出的本机目录可以打开仓库里的文件；核对后 Git 目录里不留标记。
    @Test("挂载的仓库核对通过")
    func locateMountedRepository() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let layout = try await MountLayout(temporary)
        let mountRoot = try layout.link("mount", to: "server")
        let locator = RemoteMountLocator(volumes: { [mountRoot] })

        let mount = try #require(await locator.locate(layout.repository, runner: layout.runner))
        let expected = mountRoot.appending(path: "work/仓 库")

        #expect(mount.remotePath == layout.repository)
        #expect(mount.localURL.path == expected.path)

        let file = try #require(mount.localURL(for: layout.repository + "/a.txt"))
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(try layout.markers(in: layout.repository + "/.git").isEmpty)
    }

    /// 两个后缀都对得上时用较长的那个：卷里 `work/仓 库` 与 `仓 库` 都指向同一个仓库，取前者。
    @Test("后缀从长到短")
    func longestSuffixFirst() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let layout = try await MountLayout(temporary)
        let volume = layout.base.appending(path: "volume")
        try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: true)
        _ = try layout.link("volume/work", to: "server/work")
        _ = try layout.link("volume/仓 库", to: "server/work/仓 库")

        let locator = RemoteMountLocator(volumes: { [volume] })
        let mount = try #require(await locator.locate(layout.repository, runner: layout.runner))

        #expect(mount.localURL.path == volume.appending(path: "work/仓 库").path)
    }

    /// 卷里有个同名的空仓库，只比 HEAD 与 config 会认错；标记在它的 Git 目录里看不到，核对不通过，B 上的标记同样删掉。
    @Test("同名的另一个仓库通不过")
    func rejectsOtherRepository() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let layout = try await MountLayout(temporary)
        let other = layout.base.appending(path: "other/仓 库")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        _ = try await temporary.runner(at: other.path).run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])

        let otherRoot = layout.base.appending(path: "other")
        let locator = RemoteMountLocator(volumes: { [otherRoot] })

        #expect(await locator.locate(layout.repository, runner: layout.runner) == nil)
        #expect(try layout.markers(in: layout.repository + "/.git").isEmpty)
        #expect(try layout.markers(in: other.path + "/.git").isEmpty)

        // 没有挂载卷时同样找不到
        #expect(await RemoteMountLocator(volumes: { [] }).locate(layout.repository, runner: layout.runner) == nil)
    }

    /// 工作树的 `.git` 是文件，里面是 B 上的 Git 目录；按后缀对上的前缀换成本机路径后看得到标记，核对通过。
    @Test("工作树按前缀换算 Git 目录")
    func locateWorktree() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let layout = try await MountLayout(temporary)
        let worktree = layout.base.appending(path: "server/树 外").path
        _ = try await layout.runner.run(["worktree", "add", "-q", "--detach", worktree])

        let mountRoot = try layout.link("mount", to: "server")
        let locator = RemoteMountLocator(volumes: { [mountRoot] })
        let mount = try #require(await locator.locate(worktree, runner: layout.runner))

        #expect(mount.localURL.path == mountRoot.appending(path: "树 外").path)

        // 工作树的 Git 目录名由 Git 按目录名生成，从 Git 读出来
        let gitDirectory = try await layout.runner.run(["-C", worktree, "rev-parse", "--absolute-git-dir"])
        #expect(try layout.markers(in: String(decoding: gitDirectory, as: UTF8.self).trimmingCharacters(in: .newlines)).isEmpty)

        // Git 目录在挂载范围之外时，换算不出本机位置，核对不通过
        let narrow = try layout.link("narrow", to: "server/树 外")
        let outside = RemoteMount(remotePath: worktree, localURL: narrow)
        #expect(!(await RemoteMountLocator.verify(worktree, through: outside, runner: layout.runner)))
    }
}

// MARK: - MountLayout

/// 临时目录里的 “服务器” 目录：`server/work/仓 库` 是有一个提交的仓库，挂载卷用符号链接模拟。
private struct MountLayout {
    /// 解析掉符号链接的临时目录，路径与 Git 写出的一致；`resolvingSymlinksInPath()` 会去掉 `/private`，与 Git 写出的不同。
    let base: URL

    /// 仓库在 “服务器” 上的路径。
    let repository: String

    /// 仓库的执行器。
    let runner: GitRunner

    /// 建出仓库，提交身份写进本地配置。
    init(_ temporary: TemporaryRepository) async throws {
        let resolved = try #require(realpath(temporary.directory.path, nil))
        defer { free(resolved) }

        base = URL(filePath: String(cString: resolved))
        repository = base.appending(path: "server/work/仓 库").path

        try FileManager.default.createDirectory(atPath: repository, withIntermediateDirectories: true)
        runner = temporary.runner(at: repository)

        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        try Data("一\n".utf8).write(to: URL(filePath: repository + "/a.txt"))
        _ = try await runner.run(["add", "a.txt"])
        _ = try await runner.run(["commit", "-q", "-m", "第一个提交"])
    }

    /// 在临时目录里建一个指向另一处的符号链接，返回链接的位置。
    func link(_ name: String, to target: String) throws -> URL {
        let url = base.appending(path: name)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: base.appending(path: target))
        return url
    }

    /// Git 目录里留下的标记文件。
    func markers(in directory: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory)
            .filter { $0.hasPrefix(RemoteMountLocator.markerPrefix) }
    }
}
